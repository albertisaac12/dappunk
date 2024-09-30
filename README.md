# dappunk

## Overview

This repository contains the smart contracts for **dappunkCreations** and **metaMarketPlace**, which are part of the dappunk platform. These contracts manage NFT creation, and marketplace functionalities for buying and selling NFTs.

- Verified Contract Addresses:
  - dappunkCreations: `0x8b73329a1D91957B64f0Fa55c14d380f8263B80C`
  - metaMarketPlace: `0x8Bf3D38c21B2354E7f69AaA839B0169dacC389F3`

## Setup

### Prerequisites

- **Node.js**: Ensure you have Node.js installed (v14+ recommended).
- **npm**: Comes bundled with Node.js.
- **Hardhat**: Used for compiling and deploying the contracts.
- **Alchemy API Key**: We use Alchemy for deploying and interacting with the Ethereum network.

### Installation

1. Clone the repository:

   ```bash
   git clone https://github.com/albertisaac12/dappunk
   ```

2. Navigate to the project directory:

   ```bash
   cd dappunk
   ```

3. Install dependencies:
   ```bash
   npm install
   ```

### Configuration

1. Create a `.env` file in the root directory and add your Alchemy API key

2. Inside the `.env` file, add the following:
   ```bash
   ALCHEMY_API_KEY=your_alchemy_api_key_here
   ```

### Compiling Contracts

To compile the smart contracts, run:

```bash
npx hardhat compile
```

### You can visit the other two readme's under the contracts section to know more about the smart contracts.
