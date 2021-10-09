// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./libs/Ownable.sol";
import "./libs/SafeMath.sol";
import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";
import "./interfaces/IMoneyPot.sol";
import "./interfaces/IShibaRouter02.sol";
import "./interfaces/IShibaPair.sol";

/*
The FeeManager is a kind of contract-wallet that allows the owner or SNOVA holders to unbind (LP) and swap tokens
to BNB/BUSD before sending them to the Money Pot. 

SNOVA Tier 1 (lower tier) Funcitons: DistributeFee, RemoveLiquidityToTokwn, removeAllLiquidityToToken, swapBalanceMultipleToWBNB
SNOVA Tier 2 (higher tier) Functions: add or remove LP tokens to registered token list - This function has more room for error
Only Owner Funcitons: Change tier requirements, change moneypot, change owner, specific token swaps
*/

contract DecentralizedFeeManager is Ownable{
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    uint256 public moneyPotShare;
    uint256 public teamShare;
    uint256 public tier1 = 50000000000000000000; // 50 SNOVA
    uint256 public tier2 = 200000000000000000000; // 200 SNOVA

    address[] public registeredLPToken;
    mapping (address => bool )  public tokenRegistered;

    event NewTier1 (uint256 indexed previoustier1, uint256 newTier1);
    event NewTier2 (uint256 indexed previoustier2, uint256 newTier2);
    event feeDistributed (address indexed _from);
    event LPTokenRegistered (address indexed _registeredToken);
    event LPTokenUnRegistered (address indexed _unRegisteredToken);
    event UpdatedMoneyPotShares(uint256 indexed previousMoneyPotShare, uint256 newMoneyPotShare);

    IMoneyPot public moneyPot;
    IShibaRouter02 public router;
    IBEP20 public SNova;

    address public teamAddr; // Used for dev/marketing and others funds for project
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    constructor (address _teamAddr,
                uint256 _moneyPotShare,
                IBEP20 _snova) public{
        
        teamAddr = _teamAddr; /*swap fees team wallet*/
        moneyPotShare = _moneyPotShare;
        teamShare = 10000 - moneyPotShare;
        SNova = _snova;
    }

     function getRegisteredLPTokenLength() public virtual view returns (uint256){
        return registeredLPToken.length;
    }

    // add LP tokens to list to allow easy liquidity removal. We should only add the common tokens, 
    // to reduce chances of gas error on removeallLiquidity. DO NOT ADD NON SHIBA-LP TOKENS.
    function addTokenToRegisteredLP(address _token) external {
        require(address(_token) != address(0), 'Cannot set zero address');
        require(IBEP20(SNova).balanceOf(msg.sender) > tier2 || address(msg.sender) == owner(), 'User must hold more than the Tier 2 amount of SNOVA');
        if (!tokenRegistered[_token]){
            registeredLPToken.push(_token);            
            tokenRegistered[_token] = true;
        }
        emit LPTokenRegistered (_token);
    }

    // remove unwanted LP tokens from registered token list
    function removeRegisteredLPToken(address _token) external {
        require(address(_token) != address(0), 'Cannot set zero address');
        require(IBEP20(SNova).balanceOf(msg.sender) > tier2 || address(msg.sender) == owner(), 'User must hold more than the Tier 2 amount of SNOVA');
        if (tokenRegistered[_token]){
            uint256 length = registeredLPToken.length;
            uint256 indexToRemove = length; // If token not found web do not try to remove bad index
            for (uint256 index = 0; index < length; ++index) {
                if(registeredLPToken[index] == _token){
                    indexToRemove = index;
                    break;
                }
            }
            if(indexToRemove < length){ // Should never be false.. Or something wrong happened
                registeredLPToken[indexToRemove] = registeredLPToken[registeredLPToken.length-1];
                registeredLPToken.pop();
            }
            tokenRegistered[_token] = false;
            return;
        }
        emit LPTokenUnRegistered(_token);
    }

    // Breaks apart all LP from registered token list. May cause gas issues if list is too long.
    function removeAllLiquidityToToken() external {
        require(IBEP20(SNova).balanceOf(msg.sender) > tier1 || address(msg.sender) == owner(), 'User must hold more than the Tier 1 amount of SNOVA');

        uint256 length = registeredLPToken.length;
        for (uint256 index = 0; index < length; ++index) {
            _removeLiquidityToToken(registeredLPToken[index]);
        }
    }
    // Breaks LP for specific LP token
    function removeLiquidityToToken(address _token) external {
        require(address(_token) != address(0), 'Cannot set zero address');
        require(IBEP20(SNova).balanceOf(msg.sender) > tier1 || address(msg.sender) == owner(), 'User must hold more than the Tier 1 amount of SNOVA');
        IShibaPair _pair = IShibaPair(_token);
        uint256 _amount = _pair.balanceOf(address(this));
        address token0 = _pair.token0();
        address token1 = _pair.token1();

        _pair.approve(address(router), _amount);
        router.removeLiquidity(token0, token1, _amount, 0, 0, address(this), block.timestamp.add(100));
    }
    // internal function used by removeAllLiquidityToToken
    function _removeLiquidityToToken(address _token) internal {
        IShibaPair _pair = IShibaPair(_token);
        uint256 _amount = _pair.balanceOf(address(this));
        address token0 = _pair.token0();
        address token1 = _pair.token1();

        _pair.approve(address(router), _amount);
        router.removeLiquidity(token0, token1, _amount, 0, 0, address(this), block.timestamp.add(100));
    }

    // Swaps balance of token0 to token1. Currently only allowed by owner as a backup for setting up fees for the money pot.
    function swapBalanceToToken(address _token0, address _token1) external onlyOwner {   
        require(address(_token0) != address(0), 'Cannot set zero address');      
        require(address(_token1) != address(0), 'Cannot set zero address'); 
        uint256 _amount = IBEP20(_token0).balanceOf(address(this));
        IBEP20(_token0).approve(address(router), _amount);
        address[] memory path = new address[](2);
        path[0] = _token0;
        path[1] = _token1;
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, 0, path, address(this), block.timestamp.add(100));
    }
    // internal function to swap token to wbnb
    function _swapBalanceToWBNB(address _token0) internal {
        uint256 _amount = IBEP20(_token0).balanceOf(address(this));
        IBEP20(_token0).approve(address(router), _amount);
        address[] memory path = new address[](2);
        path[0] = _token0;
        path[1] = address(WBNB);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, 0, path, address(this), block.timestamp.add(100));
    }

    // Main function to swap multiple tokens to wbnb
    function swapBalanceMultipleToWBNB(address[] memory _token0) external {
        require(IBEP20(SNova).balanceOf(msg.sender) > tier1 || address(msg.sender) == owner(), 'User must hold more than the Tier 1 amount of SNOVA');
        for (uint i = 0; i < _token0.length; i++) {
            _swapBalanceToWBNB(_token0[i]);
        }
    }

    // Used by owner to swap specific amounts of tokens if needed
    function swapToTokenSupportingFees(address _token0, address _token1, uint256 _token0Amount) external onlyOwner {        
        IBEP20(_token0).approve(address(router), _token0Amount);
        address[] memory path = new address[](2);
        path[0] = _token0;
        path[1] = _token1;
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(_token0Amount, 0, path, address(this), block.timestamp.add(100));
    }
    // sets amount of fees go to the team and moneypot. Requires moneyPot have at least 75%
    function updateShares(uint256 _moneyPotShare) external onlyOwner{
        require(_moneyPotShare <= 10000, "Invalid percent");
        require(_moneyPotShare >= 7500, "Moneypot share must be at least 75%");
        emit UpdatedMoneyPotShares(moneyPotShare, _moneyPotShare);
        moneyPotShare = _moneyPotShare;        
        teamShare = 10000 - moneyPotShare;
    }

    function setTeamAddr(address _newTeamAddr) external onlyOwner{
        require(address(_newTeamAddr) != address(0), 'Cannot set as 0 address');
        teamAddr = _newTeamAddr;
    }

    function setupRouter(address _router) external onlyOwner{
        require(address(_router) != address(0), 'Cannot set as 0 address');
        router = IShibaRouter02(_router);
    }

    function setupMoneyPot(IMoneyPot _moneyPot) external onlyOwner{
        require(address(_moneyPot) != address(0), 'Cannot set as 0 address');
        moneyPot = _moneyPot;
    }

    // function used to modify the lower tier minimum SNOVA
    function setTier1 (uint256 newTier1) external onlyOwner{
        require(newTier1 >= 50000000000000000000, 'Can not set lower than 50 SNOVA' );
        require(newTier1 <= IBEP20(SNova).totalSupply().div(100), 'Must be lower than 1% of total SNOVA supply' );
        emit NewTier1 (tier1, newTier1);
        tier1 = newTier1;
    }

     // function used to modify the upper tier minimum SNOVA
    function setTier2 (uint256 newTier2) external onlyOwner{
        require(newTier2 >= 200000000000000000000, 'Can not set lower than 200 SNOVA' );
        require(newTier2 <= IBEP20(SNova).totalSupply().div(100), 'Must be lower than 1% of total SNOVA supply' );
        emit NewTier2 (tier2, newTier2);
        tier2 = newTier2;
    }


    /* distribute fee to the moneypot and dev wallet. If feeManager has 0 balance for a registered token, it does not send that token  */
     function distributeFee() external {
        require(IBEP20(SNova).balanceOf(msg.sender) > tier1 || address(msg.sender) == owner(), 'User must hold more than the Tier 1 amount of SNOVA');
        uint256 length = moneyPot.getRegisteredTokenLength();
        for (uint256 index = 0; index < length; ++index) {
            IBEP20 _curToken = IBEP20(moneyPot.getRegisteredToken(index));
            uint256 _amount = _curToken.balanceOf(address(this));
            if (_amount > 0) {
                uint256 _moneyPotAmount = _amount.mul(moneyPotShare).div(10000);
                _curToken.approve(address(moneyPot), _moneyPotAmount);
                moneyPot.depositRewards(address(_curToken), _moneyPotAmount);
                _curToken.safeTransfer(teamAddr, _amount.sub(_moneyPotAmount));
            }
            else
            return;
        }
        emit feeDistributed(msg.sender);
    }
}