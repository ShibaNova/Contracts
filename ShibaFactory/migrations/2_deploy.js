const ShibaFactory = artifacts.require("ShibaFactory");

module.exports = function (deployer) {
   
    const _feeTo = '0x9A50e1dCE6B5E4E6CDEab09A7aCb5068f8e61D91'; //fee manager
    const owner = '0x078BB52f3FD53Cde7Ab15FE831Da9B55E3c702Fa';
    const _feePercent = 20;
deployer.deploy(ShibaFactory, _feeTo, owner, _feePercent); //0.5.16
   
};