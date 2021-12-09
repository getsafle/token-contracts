const SafleToken = artifacts.require("SafleToken");
const Vesting = artifacts.require("Vesting");

module.exports = async (deployer, network, accounts) => {

  // 1. Deploy Safle contract (token contract)
  await deployer.deploy(SafleToken)
  safleToken = await SafleToken.deployed()
  
  // 2. Deploy the vesting contract by passing the token address as the constructor parameter.
  await deployer.deploy(Vesting, safleToken.address)
  safleVesting = await Vesting.deployed()
};