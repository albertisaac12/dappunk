# Dappunk NFT Minting Contract

This is the **Dappunk NFT Minting Contract**, a smart contract built on Ethereum that allows creators to mint unique, 1-of-1 NFTs through the Dappunk platform. The contract uses various Solidity libraries and is designed with advanced features like stealth minting, soul-bound tokens (SBT), and support for relayers.

## Table of Contents

1. [Contract Overview](#contract-overview)
2. [Roles and Permissions](#roles-and-permissions)
3. [Features](#features)
   - [Voucher System](#voucher-system)
   - [Stealth and Soul-bound Tokens](#stealth-and-soul-bound-tokens)
   - [Token Payments](#token-payments)
   - [Gasless Minting](#gasless-minting)
4. [Minting Methods](#minting-methods)
   - [Mint Using Native Currency](#mint-using-native-currency)
   - [Mint Using ERC20 Tokens](#mint-using-erc20-tokens)
5. [Event Logging](#event-logging)
6. [Custom Errors](#custom-errors)
7. [URI Management](#uri-management)
8. [Pioneer Management](#pioneer-management)
9. [Agency Management](#agency-management)
10. [Soul-bound Tokens](#soul-bound-tokens)
11. [Refund System](#refund-system)
12. [Gasless Minting](#gasless-minting)
13. [License](#license)

## Contract Overview

The contract is designed for minting **1-of-1 NFTs** with customizable options like stealth mode, royalties, and soul-bound tokens. The platform fee and pioneer fee structures are set by default, but can be customized through different roles in the contract. The contract uses **ERC1155** as the core standard with extensions for royalty management (ERC2981), signature verification (EIP712), and more.

## Roles and Permissions

This contract follows the **Access Control** pattern to manage various roles:

- **DEFAULT_ADMIN_ROLE**: The default admin who has the ultimate authority.
- **MANAGER_ROLE**: For managing overall contract operations.
- **MINTER_ROLE**: For users who can mint NFTs.
- **FUND_MANAGER_ROLE**: For managing funds related to minting and payments.
- **AGENCY_MANAGER_ROLE**: For managing agencies and their creators.
- **ROYALTY_MANAGER_ROLE**: For managing royalties of NFTs.
- **CONTRACT_APPROVER_ROLE**: For approving specific contracts.
- **MINT_VALIDATOR_ROLE**: For validating mint requests.
- **REFUND_MANAGER_ROLE**: For handling refunds and related operations.
- **RELAYER_ROLE**: For gasless transactions and relayer-based operations.
- **MARKET_PLACE**: For marketplace interactions.

## Features

### Voucher System

The NFT minting relies on a **voucher system**. Creators sign off on vouchers that represent an NFT, which users can redeem for the actual NFT on-chain. The voucher structure includes details like:

- `tokenId`: The unique ID of the NFT.
- `price`: The price for minting.
- `quantity`: Total quantity available.
- `buyerQty`: Quantity to be minted by the buyer.
- `start` and `end`: Time range for minting.
- `royalty`: Royalty percentage for the creator.
- `isStealth`: Whether the NFT should be minted in stealth mode.
- `isSbt`: Whether the NFT is soul-bound (non-transferable).

### Stealth and Soul-bound Tokens

- **Stealth Mode**: NFTs can be minted in stealth, meaning their metadata is hidden until the creator chooses to reveal it.
- **Soul-bound Tokens (SBT)**: Some tokens can be marked as non-transferable. These are ideal for membership or identity-bound NFTs.

### Token Payments

The contract supports multiple ERC20 tokens for minting payments. Only whitelisted tokens can be used.

### Gasless Minting

A key feature is gasless minting, allowing relayers to mint NFTs on behalf of users without the need for users to pay gas fees.

## Minting Methods

### Mint Using Native Currency

The function `mintNft` allows minting of NFTs using the native currency (e.g., ETH on Ethereum). The voucher structure ensures that minting follows the voucher's rules, and fees are deducted appropriately.

### Mint Using ERC20 Tokens

The `mintNftWithToken` function allows users to mint NFTs using supported ERC20 tokens. This is ideal for platforms that want to use stablecoins or other tokens for payments.

## Event Logging

The contract emits the following events for logging various actions:

- `Minted`: Emitted when a new NFT is minted.
- `Burnt`: Emitted when an NFT is burnt.
- `Refunded`: Emitted when an NFT is refunded.
- `Locked`: Emitted when an NFT is locked as soul-bound.
- `Unlocked`: Emitted when an NFT is unlocked.

## Custom Errors

The contract includes several custom errors to save gas and make error handling more descriptive:

- `AccessDenied`: Thrown when a user without a required role tries to perform a restricted action.
- `AlreadyAdded`: Thrown when trying to add an existing entry (e.g., pioneer, agency).
- `Deprecated`: Thrown when interacting with deprecated features.
- `InsufficientBalance`: Thrown when the user has insufficient balance for an operation.
- `InvalidPrice`: Thrown when the price of an NFT is invalid.
- `NonTransferableToken`: Thrown when a user tries to transfer a soul-bound token.
- `InvalidTokenQty`: Thrown when the quantity for minting is invalid.

## URI Management

- **Base URI**: The default URI for all tokens, set during the contract deployment.
- **Stealth URI**: A special URI for stealth tokens, where the token’s metadata is hidden.
- **URI Suffix**: The contract allows enabling/disabling a URI suffix for better metadata organization.

The functions `updateBaseUri`, `updateStealthUri`, and `updateUriSuffix` allow for updating the URI structure.

## Pioneer Management

Pioneers are creators who get reduced fees when minting NFTs. The contract maintains a mapping of pioneers and includes functions to add pioneers.

```solidity
function addPioneer(address pioneer) external accessCheck(4);
```

## Agency Management

Agencies can be added to the contract and assigned fees. Agencies can also have multiple creators associated with them.

- **addAgency**: Adds an agency and specifies its fee.
- **addCreator**: Associates a creator with an agency.

## Soul-bound Tokens

The contract supports Soul-bound Tokens (SBT), which are non-transferable NFTs. When a token is locked as an SBT, it cannot be transferred unless the sender has the `REFUND_MANAGER_ROLE`.

## Refund System

Refunds can be processed by the refund manager, who has the authority to transfer the NFT back to the creator under certain conditions.

```solidity
function refundNFT(uint256 tokenId, address creator, address owner, uint256 qty) external accessCheck(8);
```

## Gasless Minting

The contract supports gasless minting via relayers. This enables users to mint NFTs without paying gas fees directly, and the relayers handle the gas on their behalf. Only users with the RELAYER_ROLE can perform gasless minting.
