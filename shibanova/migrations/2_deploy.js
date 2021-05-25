const MasterShiba = artifacts.require("MasterShiba");

module.exports = function (deployer) {
   
    const _Nova = '0xa809F75876fdE949b029D99552547DD2c4e320CF';
    const _sNova = '0x64F6852088B9B70fDe86225Ebb660F0d1709D5E7';
    const _bonusAggregator = '0x0bD0445d91F37076c43254a162e611198A5De02d';
    const _devaddr = '0xB8419aBa04B8b36E26E80b2b8284f1e0DA077bB2';
    const _feeAddress = '0x9A50e1dCE6B5E4E6CDEab09A7aCb5068f8e61D91'; //fee manager
    const _NovaPerBlock = 0xde0b6b3a7640000n;
    const _startBlock = 9155945;
deployer.deploy(MasterShiba, 
     _Nova,
     _sNova,
     _bonusAggregator,
     _devaddr,
     _feeAddress,
     _NovaPerBlock,
     _startBlock);
 

};