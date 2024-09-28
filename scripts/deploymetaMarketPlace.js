const { ethers } = require("hardhat");

async function main() {
  const [deployer] = await ethers.getSigners();
  const deployerAddress = deployer.address;
  const contractFactory = await ethers.getContractFactory("dappunkCreations");
  const contract = await contractFactory.deploy(
    deployerAddress,
    deployerAddress,
    deployerAddress,
    deployerAddress,
    deployerAddress,
    deployerAddress,
    deployerAddress,
    deployerAddress,
    [deployerAddress]
  );
  await contract.waitForDeployment();
  console.log("Deployed at: ", await contract.getAddress());
}

main();
