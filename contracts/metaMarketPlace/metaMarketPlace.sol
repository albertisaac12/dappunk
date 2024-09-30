// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/AccessControl.sol"; // Access control
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol"; // Used to verify the signature
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol"; // Signature generation
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "hardhat/console.sol";

interface Itoken {
    function transfer(address to, uint256 value) external returns (bool);
    function balanceOf(address account) external returns (uint256);
    function transferFrom(address from, address to, uint256 value) external returns (bool);
    function approve(address spender, uint256 value) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256); 

}

interface I1155 {
    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data) external;
    function setApprovalForAll(address operator, bool approved) external;
    function royaltyInfo(uint256 tokenId, uint256 salePrice) external view returns (address, uint256);
    function refundNFT(uint256 tokenId, address creator, address owner, uint256 qty) external;
}

contract metaMarketPlace is AccessControl, EIP712 {

    /// @dev Struct to hold marketplace voucher details
    struct marketPlaceVoucher {
        address listingAddress; // Currently we do not need the collection ID
        uint256 tokenId; // Unique to each NFT or Batch
        uint256 quantity; // 1 if it's NFT, else 1155
        uint256 price; // Cost of the sale, excludes platform fees
        uint256 listedIn;
        uint256 start; // Time of sale start
        uint256 end; // Time of sale end
        bool isListed; // True if listed for purchase, false if sold or not listed
        bytes ownerSignature; // Purchase ID
    }

    /// @dev Struct to hold purchase voucher details
    struct purchaseVoucher {
        address buyerAddress;
        uint256 purchaseId;
        uint256 quantity;
        uint256 validUntil;
        uint256 USDprice; // ETH to USD price
        uint256 txnfees;
        uint256 purchaseingIn;
        bytes buyerSignature;
    }

    /// @dev Struct to hold refund voucher details
    struct refundVoucher {
        address buyer;
        address seller;
        uint256 tokenId;
        uint256 price;
        uint256 quantity;
    }

    struct transferVoucher{
        address owner; // token owner
        address to; // address transfering to
        uint256 tokenId; // unique tokenId
        uint256 quantity; // token quantity 
        bytes ownerSignature;
    }

    I1155 public mNft;
    uint256 public platformFees; // Common fees

    /// @dev Constructor to initialize the contract with necessary addresses and platform fees
    /// @param _m1155 Address of the 1155 contract
    /// @param _platfromFess Platform fees to be charged
    constructor(address _m1155, uint256 _platfromFess) EIP712("dappunkMarketPlace", "1") {
        mNft = I1155(_m1155);
        platformFees = _platfromFess;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(RELAYER_ROLE, msg.sender);
    }

    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    /// @dev Emitted when USD transfer occurs
    event purchase(address indexed owner, uint256 indexed amount, uint256 indexed royalityAmount, address receiver);

    /// @dev Emitted when a purchase is successful
    event purchaseSucessfull(address indexed buyer, uint256 indexed value, address indexed seller);

    /// @dev Emitted when a refund occurs
    event refunded(address buyer, address indexed seller, uint256 indexed tokenId, uint256 indexed price);

    /// @dev Emitted when a token is transfered using Relayer
    event transfered(address indexed owner,address indexed to,uint256 indexed tokenId);

    /// @dev Error for item not listed
    error itemNotListed();

    /// @dev Error for invalid buyer
    error invalidBuyer();

    /// @dev Error for invalid price
    error invalidPrice();

    /// @dev Error for invalid quantity
    error invalidQuantity();

    /// @dev Error for invalid time period
    error invalidTimePeriod();

    /// @dev Error for invalid amount
    error invalidAmount();

    /// @dev Error for malicious signature
    error maliciousSignature();

    /// @dev Verifies the signatures of the vouchers
    /// @param Voucher The marketplace voucher
    /// @param Pvoucher The purchase voucher
    function verifySignature(marketPlaceVoucher calldata Voucher, purchaseVoucher calldata Pvoucher) public view {
        if (!Voucher.isListed) revert itemNotListed();
        if (block.timestamp > Pvoucher.validUntil) revert invalidTimePeriod();
        if (Voucher.end < Voucher.start || Voucher.end < block.timestamp || block.timestamp < Voucher.start) revert invalidTimePeriod();
        if (Voucher.price == 0) revert invalidPrice();
        if (Voucher.quantity == 0) revert invalidQuantity();
        if (Pvoucher.quantity == 0) revert invalidQuantity();
        if(Pvoucher.quantity> Voucher.quantity) revert invalidQuantity();

        uint16 retrivedQuantity = uint16(Voucher.tokenId & 0xFFFF);
        if(Voucher.quantity>retrivedQuantity) revert invalidQuantity();

        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            keccak256("marketPlaceVoucher(address listingAddress,uint256 tokenId,uint256 quantity,uint256 price,uint256 listedIn,uint256 start,uint256 end,bool isListed)"),
            Voucher.listingAddress,
            Voucher.tokenId,
            Voucher.quantity,
            Voucher.price,
            Voucher.listedIn,
            Voucher.start,
            Voucher.end,
            Voucher.isListed
        )));

        address owner = ECDSA.recover(digest, Voucher.ownerSignature);
        if (owner != Voucher.listingAddress) revert maliciousSignature();

        bytes32 digest2 = _hashTypedDataV4(keccak256(abi.encode(
            keccak256("purchaseVoucher(address buyerAddress,uint256 purchaseId,uint256 quantity,uint256 validUntil,uint256 USDprice,uint256 txnfees,uint256 purchaseingIn)"),
            Pvoucher.buyerAddress,
            Pvoucher.purchaseId,
            Pvoucher.quantity,
            Pvoucher.validUntil,
            Pvoucher.USDprice,
            Pvoucher.txnfees,
            Pvoucher.purchaseingIn
        )));

        address buyer = ECDSA.recover(digest2, Pvoucher.buyerSignature);

        if (buyer != Pvoucher.buyerAddress) revert invalidBuyer();

        // return Voucher.tokenId;
    }

    /// @dev Handles purchase transactions with native currency (ETH)
    /// @param Voucher The marketplace voucher
    /// @param Pvoucher The purchase voucher
    function purchaseNative(marketPlaceVoucher calldata Voucher, purchaseVoucher calldata Pvoucher) public payable {
        verifySignature(Voucher, Pvoucher);
        uint256 price;
        if (Voucher.listedIn == 2 && Pvoucher.purchaseingIn == 1) {
            if (msg.value != ((Pvoucher.USDprice) + (platformFees) + (Pvoucher.txnfees))) revert invalidAmount();
            price = Pvoucher.USDprice;
        } else {
            if (msg.value != ((Voucher.price) + (platformFees) + (Pvoucher.txnfees))) revert invalidAmount();
            price = Voucher.price;
        }
        payable(Voucher.listingAddress).transfer(price);

        mNft.setApprovalForAll(Voucher.listingAddress, true);
        mNft.safeTransferFrom(Voucher.listingAddress, msg.sender, Pvoucher.purchaseId, Pvoucher.quantity, "0x00");
        mNft.setApprovalForAll(Voucher.listingAddress, false);
        (address owner, uint256 royality) = mNft.royaltyInfo(Voucher.tokenId, price);
        payable(owner).transfer(royality);

        emit purchaseSucessfull(Pvoucher.buyerAddress, msg.value, Voucher.listingAddress);
    }

    /// @dev Handles purchase transactions with Punk tokens
    /// @param Voucher The marketplace voucher
    /// @param Pvoucher The purchase voucher
    function purchaseERC20(marketPlaceVoucher calldata Voucher, purchaseVoucher calldata Pvoucher,address erc20) public onlyRole(RELAYER_ROLE) {
        verifySignature(Voucher, Pvoucher);
        Itoken token = Itoken(erc20);
        if(token.allowance(Pvoucher.buyerAddress,address(this))<(Voucher.price) + (platformFees)) revert();
        token.transferFrom(Pvoucher.buyerAddress, address(this), ((Voucher.price) + (platformFees)));
        mNft.setApprovalForAll(Voucher.listingAddress, true);
        mNft.safeTransferFrom(Voucher.listingAddress, Pvoucher.buyerAddress, Pvoucher.purchaseId, Pvoucher.quantity, "0x00");
        mNft.setApprovalForAll(Voucher.listingAddress, false);
        (address owner, uint256 royality) = mNft.royaltyInfo(Voucher.tokenId, Voucher.price);
        token.transfer(owner, royality);
        token.transferFrom(address(this), Voucher.listingAddress, Voucher.price);
        emit purchaseSucessfull(Pvoucher.buyerAddress, (Voucher.price) + (platformFees) + (Pvoucher.txnfees), Voucher.listingAddress);
    }

    /// @dev Handles purchase transactions with USD
    /// @param Voucher The marketplace voucher
    /// @param Pvoucher The purchase voucher
    function purchaseUSD(marketPlaceVoucher calldata Voucher, purchaseVoucher calldata Pvoucher) public onlyRole(RELAYER_ROLE) {
        verifySignature(Voucher, Pvoucher);
        address owner;
        uint256 royality;
        mNft.setApprovalForAll(Voucher.listingAddress, true);
        mNft.safeTransferFrom(Voucher.listingAddress, Pvoucher.buyerAddress, Pvoucher.purchaseId, Pvoucher.quantity, "0x00");
        mNft.setApprovalForAll(Voucher.listingAddress, false);
        (owner, royality) = mNft.royaltyInfo(Voucher.tokenId, Voucher.price);
        emit purchase(Voucher.listingAddress, Voucher.price, Pvoucher.USDprice, owner);
        emit purchaseSucessfull(Pvoucher.buyerAddress, (Voucher.price) + (platformFees) + (Pvoucher.txnfees), Voucher.listingAddress);
    }

    /// @dev Fallback function to receive Ether
    receive() external payable {}

    /// @dev Allows the admin to withdraw the contract balance
    /// @param to Address to send the withdrawn funds
    function withdraw(address payable to) external onlyRole(DEFAULT_ADMIN_ROLE) {
        to.transfer(address(this).balance);
    }

    function withdrawERC20(address to,address erc20) external onlyRole(DEFAULT_ADMIN_ROLE){
        Itoken token = Itoken(erc20);
        uint256 balance =  token.balanceOf(address(this));
        token.transfer(to,balance);
    }

    /// @dev Allows relayers to transfer out the tokens
    /// @param Tvoucher The transfer Voucher 
    function transfer(transferVoucher calldata Tvoucher) external onlyRole(RELAYER_ROLE){
        // assume that that the payement is done in the frontEnd
        uint16 retrivedQuantity = uint16(Tvoucher.tokenId & 0xFFFF);
        if(Tvoucher.quantity>retrivedQuantity) revert invalidQuantity();
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            keccak256("transferVoucher(address owner,address to,uint256 tokenId,uint256 quantity)"),
            Tvoucher.owner,
            Tvoucher.to,
            Tvoucher.tokenId,
            Tvoucher.quantity
        )));

        address owner = ECDSA.recover(digest, Tvoucher.ownerSignature);
        if (owner != Tvoucher.owner) revert maliciousSignature();

        mNft.setApprovalForAll(Tvoucher.owner,true);
        mNft.safeTransferFrom(Tvoucher.owner,Tvoucher.to,Tvoucher.tokenId,Tvoucher.quantity,"0x00");
        mNft.setApprovalForAll(Tvoucher.owner,true);
        

        emit transfered(Tvoucher.owner,Tvoucher.to,Tvoucher.tokenId);
    }

    /// @dev Handles refunding of NFTs
    /// @param Rvoucher The refund voucher
    function refund(refundVoucher calldata Rvoucher) external onlyRole(RELAYER_ROLE) {
        mNft.setApprovalForAll(Rvoucher.buyer, true);
        mNft.safeTransferFrom(Rvoucher.buyer, Rvoucher.seller, Rvoucher.tokenId, Rvoucher.quantity, "0x00");
        mNft.setApprovalForAll(Rvoucher.buyer, false);
        emit refunded(Rvoucher.buyer, Rvoucher.seller, Rvoucher.tokenId, Rvoucher.price);
    }
}