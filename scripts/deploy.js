const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();

  console.log("Deploying contracts with account:", deployer.address);

  const FlashLoanExecutor = await ethers.getContractFactory("FlashLoanExecutor");
  const contract = await FlashLoanExecutor.deploy(
    process.env.AAVE_POOL_ADDRESSES_PROVIDER,
    process.env.UNISWAP_ROUTER,
    process.env.DAI_ADDRESS,
    process.env.WETH_ADDRESS
  );

  await contract.deployed();

  console.log("FlashLoanExecutor deployed to:", contract.address);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});