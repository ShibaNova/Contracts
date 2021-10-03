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
The FeeManager is a kind of contract-wallet that allow the owner to unbind (LP) and swap tokens
to BNB/BUSD before sending them to the Money Pot
*/

//TO-DO add and remove LP tokens to list, add remove all liquidity function, 
// make sure owner can still operate, add distributefee for snova
// function to change tier requirements

contract DecentralizedFeeManager is Ownable{
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    uint256 public moneyPotShare;
    uint256 public teamShare;
    uint256 public tier1 = 50000000000000000000; // 50 SNOVA
    uint256 public tier2 = 200000000000000000000; // 200 SNOVA

    address[] public registeredLPToken;
    mapping (address => bool )  public tokenRegistered;

    IMoneyPot public moneyPot;
    IShibaRouter02 public router;
    IBEP20 public Nova;

    address public teamAddr; // Used for dev/marketing and others funds for project
    address public constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address public constant SNova = 0x0c0bf2bD544566A11f59dC70a8F43659ac2FE7c2;
    address public constant BURN_ADDRESS = 0x000000000000000000000000000000000000dEaD;

    constructor (IBEP20 _Nova, address _teamAddr,
                uint256 _moneyPotShare) public{
        Nova = _Nova;
        teamAddr = _teamAddr; /*swap fees team wallet*/
        moneyPotShare = _moneyPotShare;
        teamShare = 10000 - moneyPotShare;
    }

     function getRegisteredLPTokenLength() public virtual view returns (uint256){
        return registeredLPToken.length;
    }

    // add LP tokens to list to allow easy liquidity removal
    function addTokenToRegisteredLP(address _token) external {
        require(IBEP20(SNova).balanceOf(msg.sender) > tier2, 'User must hold more than the Tier 2 amount of SNOVA');
        if (!tokenRegistered[_token]){
            registeredLPToken.push(_token);            
            tokenRegistered[_token] = true;
        }
    }

    // remove unwanted LP tokens from registered token list
    function removeTokenToRewards(address _token) external {
        require(IBEP20(SNova).balanceOf(msg.sender) > tier2, 'User must hold more than the Tier 2 amount of SNOVA');
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
    }

    // Breaks apart all LP from registered token list
    function removeAllLiquidityToToken() external {
        require(IBEP20(SNova).balanceOf(msg.sender) > tier1, 'User must hold more than the Tier 1 amount of SNOVA');

        uint256 length = registeredLPToken.length;
        for (uint256 index = 0; index < length; ++index) {
            IBEP20 _token = IBEP20(registeredLPToken[index]);
            IShibaPair _pair = IShibaPair(address(_token));
            uint256 _amount = _pair.balanceOf(address(this));
            address token0 = _pair.token0();
            address token1 = _pair.token1();

            _pair.approve(address(router), _amount);
            router.removeLiquidity(token0, token1, _amount, 0, 0, address(this), block.timestamp.add(100));
        }
    }

    function removeLiquidityToToken(address _token) external {
        require(IBEP20(SNova).balanceOf(msg.sender) > tier1, 'User must hold more than the Tier 1 amount of SNOVA');
        IShibaPair _pair = IShibaPair(_token);
        uint256 _amount = _pair.balanceOf(address(this));
        address token0 = _pair.token0();
        address token1 = _pair.token1();

        _pair.approve(address(router), _amount);
        router.removeLiquidity(token0, token1, _amount, 0, 0, address(this), block.timestamp.add(100));
    }

    function ownerRemoveLiquidityToToken(address _token) external onlyOwner{
        IShibaPair _pair = IShibaPair(_token);
        uint256 _amount = _pair.balanceOf(address(this));
        address token0 = _pair.token0();
        address token1 = _pair.token1();

        _pair.approve(address(router), _amount);
        router.removeLiquidity(token0, token1, _amount, 0, 0, address(this), block.timestamp.add(100));
    }

    function swapBalanceToToken(address _token0, address _token1) external onlyOwner {        
        uint256 _amount = IBEP20(_token0).balanceOf(address(this));
        IBEP20(_token0).approve(address(router), _amount);
        address[] memory path = new address[](2);
        path[0] = _token0;
        path[1] = _token1;
        router.swapExactTokensForTokens(_amount, 0, path, address(this), block.timestamp.add(100));
    }

    function swapBalanceToWBNB(address _token0) external {
        require(IBEP20(SNova).balanceOf(msg.sender) > tier1, 'User must hold more than the Tier 1 amount of SNOVA');
        uint256 _amount = IBEP20(_token0).balanceOf(address(this));
        IBEP20(_token0).approve(address(router), _amount);
        address[] memory path = new address[](2);
        path[0] = _token0;
        path[1] = address(WBNB);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, 0, path, address(this), block.timestamp.add(100));
    }

    function ownerSwapBalanceToWBNB(address _token0) external onlyOwner {
        uint256 _amount = IBEP20(_token0).balanceOf(address(this));
        IBEP20(_token0).approve(address(router), _amount);
        address[] memory path = new address[](2);
        path[0] = _token0;
        path[1] = address(WBNB);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(_amount, 0, path, address(this), block.timestamp.add(100));
    }

    function swapToToken(address _token0, address _token1, uint256 _token0Amount) external onlyOwner {        
        IBEP20(_token0).approve(address(router), _token0Amount);
        address[] memory path = new address[](2);
        path[0] = _token0;
        path[1] = _token1;
        router.swapExactTokensForTokens(_token0Amount, 0, path, address(this), block.timestamp.add(100));
    }

    function swapToTokenSupportingFees(address _token0, address _token1, uint256 _token0Amount) external onlyOwner {        
        IBEP20(_token0).approve(address(router), _token0Amount);
        address[] memory path = new address[](2);
        path[0] = _token0;
        path[1] = _token1;
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(_token0Amount, 0, path, address(this), block.timestamp.add(100));
    }

    function updateShares(uint256 _moneyPotShare) external onlyOwner{
        require(_moneyPotShare <= 10000, "Invalid percent");
        require(_moneyPotShare >= 7500, "Moneypot share must be at least 75%");
        moneyPotShare = _moneyPotShare;
        teamShare = 10000 - moneyPotShare;
    }

    function setTeamAddr(address _newTeamAddr) external onlyOwner{
        teamAddr = _newTeamAddr;
    }

    function setupRouter(address _router) external onlyOwner{
        router = IShibaRouter02(_router);
    }

    function setupMoneyPot(IMoneyPot _moneyPot) external onlyOwner{
        moneyPot = _moneyPot;
    }

    /* distribute fee to the moneypot and dev wallet  */
    function ownerDistributeFee() external onlyOwner {
        uint256 length = moneyPot.getRegisteredTokenLength();
        for (uint256 index = 0; index < length; ++index) {
            IBEP20 _curToken = IBEP20(moneyPot.getRegisteredToken(index));
            uint256 _amount = _curToken.balanceOf(address(this));
            uint256 _moneyPotAmount = _amount.mul(moneyPotShare).div(10000);
            _curToken.approve(address(moneyPot), _moneyPotAmount);
            moneyPot.depositRewards(address(_curToken), _moneyPotAmount);
            _curToken.safeTransfer(teamAddr, _amount.sub(_moneyPotAmount));
        }
    }

    function distributeFee() external {
        uint256 length = moneyPot.getRegisteredTokenLength();
        for (uint256 index = 0; index < length; ++index) {
            IBEP20 _curToken = IBEP20(moneyPot.getRegisteredToken(index));
            uint256 _amount = _curToken.balanceOf(address(this));
            uint256 _moneyPotAmount = _amount.mul(moneyPotShare).div(10000);
            _curToken.approve(address(moneyPot), _moneyPotAmount);
            moneyPot.depositRewards(address(_curToken), _moneyPotAmount);
            _curToken.safeTransfer(teamAddr, _amount.sub(_moneyPotAmount));
        }
    }
}