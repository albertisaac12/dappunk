require("@nomicfoundation/hardhat-toolbox");
require("@nomicfoundation/hardhat-ethers");
require("@nomicfoundation/hardhat-verify");
require("dotenv").config();
/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  networks: {
    sepolia: {
      url: process.env.S_RPC,
      accounts: [process.env.S1],
      gas: "auto",
    },
    polygonAmoy: {
      url: process.env.A_RPC,
      accounts: [process.env.S1],
      chainId: 80002,
      gas: "auto",
    },
    scrollSepolia: {
      url: process.env.SCROLL_ALCHEMY_API,
      accounts: [process.env.S1],
      chainId: 534351,
      gas: "auto",
    },
  },
  etherscan: {
    apiKey: {
      polygonAmoy: process.env.AE_API,
      scrollSepolia: process.env.SCROLLSCAN_API_KEY,
    },
    customChains: [
      {
        network: "scrollSepolia",
        chainId: 534351,
        urls: {
          browserURL: "https://sepolia.scrollscan.com/",
          apiURL: "https://api-sepolia.scrollscan.com/api",
        },
      },
    ],
  },
  sourcify: {
    enabled: false,
  },
  solidity: {
    version: "0.8.24",
    settings: {
      // viaIR: true,
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
};
