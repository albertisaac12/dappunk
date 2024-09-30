# MetaMarketPlace Smart Contract

The **MetaMarketPlace** smart contract facilitates the buying, selling, transferring, and refunding of NFTs through a voucher-based system. It supports ERC1155 NFTs, native tokens (ETH), ERC20 tokens, and USD payments. The contract integrates features like signature verification, platform fees, royalty payments, and gasless transactions through relayers.

## Table of Contents

1. [Contract Overview](#contract-overview)
2. [Contract Features](#contract-features)
   - [Voucher System](#voucher-system)
   - [Supported Payment Methods](#supported-payment-methods)
   - [Signature Verification](#signature-verification)
   - [Relayer Role](#relayer-role)
   - [Royalty Support](#royalty-support)
   - [Refund System](#refund-system)
3. [Roles and Permissions](#roles-and-permissions)
4. [Key Functions](#key-functions)
   - [Purchase with Native Currency](#purchase-with-native-currency)
   - [Purchase with ERC20 Tokens](#purchase-with-erc20-tokens)
   - [Purchase with USD](#purchase-with-usd)
   - [Token Transfer](#token-transfer)
   - [Refund](#refund)
   - [Withdraw](#withdraw)
5. [Events](#events)
6. [Errors](#errors)
7. [License](#license)

## Contract Overview

This contract is built for NFT marketplaces to manage sales, transfers, and refunds of NFTs. It works on a voucher system, where each transaction requires a signed voucher from the owner or buyer. The contract supports:

- ERC1155 NFTs
- Native token payments (ETH)
- ERC20 token payments
- USD-denominated payments
- Platform fees and royalty payments

The contract uses **ECDSA** and **EIP712** to verify signatures for secure transactions. It also supports gasless transactions via relayers.

## Contract Features

### Voucher System

The marketplace operates using three main voucher types:

- **Marketplace Voucher**: Contains details about the listed NFT, including its ID, quantity, price, and time period.
- **Purchase Voucher**: Contains details about the buyer, the number of NFTs being purchased, and the payment information.
- **Refund Voucher**: Used to process refunds of NFTs from buyers back to sellers.

### Supported Payment Methods

- **Native Currency (ETH)**: Users can purchase NFTs using ETH.
- **ERC20 Tokens**: The contract supports purchases using any ERC20 token. The contract ensures that the buyer has sufficient allowance and balance before proceeding with the sale.
- **USD Payments**: Facilitates payments in USD with relayers handling the process.

### Signature Verification

Each transaction requires valid signatures from either the NFT owner or buyer. The contract uses **EIP712** for generating these signatures and **ECDSA** for signature recovery.

### Relayer Role

The contract supports gasless transactions, where relayers can process transactions on behalf of users. Only users with the `RELAYER_ROLE` can act as relayers.

### Royalty Support

The contract integrates with ERC1155's `royaltyInfo` function to pay royalties to the creator whenever an NFT is sold.

### Refund System

A refund system allows buyers to return NFTs to sellers, facilitated by relayers. The relayer will transfer the NFT back to the seller and log the refund event.

## Roles and Permissions

This contract uses **AccessControl** from OpenZeppelin to manage roles:

- **DEFAULT_ADMIN_ROLE**: Has complete control over the contract.
- **RELAYER_ROLE**: Can handle gasless transactions for purchases, refunds, and transfers.

## Key Functions

### Purchase with Native Currency

The `purchaseNative` function enables users to buy NFTs using native currency (ETH). The function verifies the marketplace and purchase vouchers and ensures that the correct amount is paid, including platform fees and royalties.

```solidity
function purchaseNative(marketPlaceVoucher calldata Voucher, purchaseVoucher calldata Pvoucher) public payable;
```

### Purchase with ERC20 Tokens

The `purchaseERC20` function allows users to buy NFTs using ERC20 tokens. The contract checks if the buyer has approved sufficient tokens for the transaction.

```solidity
function purchaseERC20(marketPlaceVoucher calldata Voucher, purchaseVoucher calldata Pvoucher, address erc20) public;
```

### Purchase with USD

The `purchaseUSD` function processes purchases in USD through relayers.

```solidity
function purchaseUSD(marketPlaceVoucher calldata Voucher, purchaseVoucher calldata Pvoucher) public;
```

### Token Transfer

The `transfer` function allows relayers to transfer NFTs on behalf of users.

```solidity
function transfer(transferVoucher calldata Tvoucher) external;
```

### Refund

The `refund` function allows relayers to handle NFT refunds from buyers back to sellers.

```solidity
function refund(refundVoucher calldata Rvoucher) external;
```

### Withdraw

The `withdraw` function allows the admin to withdraw the contract's balance.

```solidity
function withdraw(address payable to) external;
function withdrawERC20(address to, address erc20) external;
```

## Events

The contract emits the following events to log key operations:

- `purchase`: Emitted when a USD transfer occurs.
- `purchaseSucessfull`: Emitted after a successful purchase.
- `refunded`: Emitted after a successful refund.
- `transfered`: Emitted when a token is transferred using the relayer.

## Errors

The contract uses custom errors to reduce gas costs and improve clarity:

- `itemNotListed`: When an item is not available for sale.
- `invalidBuyer`: When the buyer's signature does not match.
- `invalidPrice`: When the price of the NFT is invalid.
- `invalidQuantity`: When the quantity requested is invalid.
- `invalidTimePeriod`: When the sale time has expired or is not valid.
- `invalidAmount`: When the amount sent does not match the price.
- `maliciousSignature`: When the signature is not valid or malicious.
