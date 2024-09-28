const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  const deployerAddress = deployer.address;
  const contractFactory = await ethers.getContractFactory("metaMarketPlace");
  const contract = await contractFactory.deploy(
    "0x8b73329a1D91957B64f0Fa55c14d380f8263B80C",
    1000
  );
  await contract.waitForDeployment();
  console.log("Deployed at: ", await contract.getAddress());
}

main();

//0x8Bf3D38c21B2354E7f69AaA839B0169dacC389F3
