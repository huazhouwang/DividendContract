var aContract = artifacts.require("DividendContract");

module.exports = function(deployer) {
  deployer.deploy(aContract, "YZCP", "YT", 18, 10000, 2);
}
