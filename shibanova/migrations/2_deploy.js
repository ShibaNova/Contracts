const NovaToken = artifacts.require('NovaToken')
const SNovaToken = artifacts.require('SNovaToken')
const FeeManager = artifacts.require('FeeManager')
const ShibaBonusAggregator = artifacts.require('ShibaBonusAggregator')
const ShibaMoneyPot = artifacts.require('ShibaMoneyPot')
const MasterShiba = artifacts.require('MasterShiba')
const ShibaCrowdsale = artifacts.require("ShibaCrowdsale");

const swapPenaltyMaxPeriod = 84600;
const swapPenaltyMaxPerSNova = 30;
const owner = '0x729F3cA74A55F2aB7B584340DDefC29813fb21dF';
const _teamAddr = '0x729F3cA74A55F2aB7B584340DDefC29813fb21dF';
const _moneyPotShare = 7500;
const _devaddr =  '0x729F3cA74A55F2aB7B584340DDefC29813fb21dF';
const _NovaPerBlock = '1000000000000000000';
const _startBlock = 10387726;
const _initialUpdateMoneyPotPeriodNbBlocks = 28880;

const ether = (n) => new web3.BigNumber(web3.toWei(n, 'ether'));

const duration = {
  seconds: function (val) { return val; },
  minutes: function (val) { return val * this.seconds(60); },
  hours: function (val) { return val * this.minutes(60); },
  days: function (val) { return val * this.hours(24); },
  weeks: function (val) { return val * this.days(7); },
  years: function (val) { return val * this.days(365); },
};

module.exports = async function(deployer, network, accounts) {
   
    await deployer.deploy(NovaToken)
    const _Nova = await NovaToken.deployed()

    await deployer.deploy(SNovaToken, swapPenaltyMaxPeriod, swapPenaltyMaxPerSNova)
    const _sNova = await SNovaToken.deployed()

    await deployer.deploy(ShibaBonusAggregator)
    const _bonusAggregator = await ShibaBonusAggregator.deployed()

    await deployer.deploy(FeeManager, _Nova.address, _teamAddr, _moneyPotShare)
    const _feeAddress = await FeeManager.deployed()
    const _feeManager = await FeeManager.deployed()

    await deployer.deploy(MasterShiba, 
        _Nova.address,
        _sNova.address,
        _bonusAggregator.address,
        _devaddr,
        _feeAddress.address,
        _NovaPerBlock,
        _startBlock
        )
    const _masterShiba = await MasterShiba.deployed()

    await deployer.deploy(ShibaMoneyPot, 
        _sNova.address, 
        _feeManager.address, 
        _masterShiba.address, 
        _startBlock, 
        _initialUpdateMoneyPotPeriodNbBlocks
        )

    await _Nova.mint(accounts[0], '1000000000000000000000')

    const latestTime = (new Date).getTime();

    const _rate           = 500;
    const _wallet         = accounts[0]; // TODO: Replace me
    const _token          = _Nova.address; // can replace with _sNova
    const _openingTime    = latestTime + duration.minutes(1);
    const _closingTime    = _openingTime + duration.weeks(1);
    const _cap            = ether(100);
    const _goal           = ether(50);
    const _foundersFund   = accounts[0]; // TODO: Replace me
    const _foundationFund = accounts[0]; // TODO: Replace me
    const _partnersFund   = accounts[0]; // TODO: Replace me
    const _releaseTime    = _closingTime + duration.days(1);

    await deployer.deploy(
        ShibaCrowdsale,
        _rate,
        _wallet,
        _token,
        _cap,
        _openingTime,
        _closingTime,
        _goal,
        _foundersFund,
        _foundationFund,
        _partnersFund,
        _releaseTime
    );
}