// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;


/// @title dappunk NFT Minting Contract.
/// @notice 1-of-1 NFTs created in the dappunk app by creators.

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract dappunkCreations is ERC1155, ERC2981, AccessControl, EIP712, ReentrancyGuard {
    using Address for address;
    using Strings for uint256;

    uint256 public platformFee;
    uint256 public pioneerFee;
    bool public uriSuffixEnabled = false;
    bool public isDeprecated = false;
    string public uriSuffix;
    string public baseUri;
    string public stealthUri;
    string public name;
    string public symbol;

    mapping(uint256 => bool) public sbt;
    mapping(uint256 => bool) public stealth;
    mapping(address => bool) public approvedContracts;
    mapping(address => bool) public pioneers;
    mapping(address => bool) public supportedTokens; // Supported ERC20 Tokens for payment
    mapping(address => uint256) public agencyFee; // Agency fee
    mapping(uint256 => uint256) public tokenMaxQty; // Total quantity of a token
    mapping(uint256 => uint256) public tokenMintedQty; // Amount of token minted
    mapping(address => address) public agencyCreator; // creator => agency
    mapping(uint256 => address) public creatorRegistry; // Creator of token


    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant FUND_MANAGER_ROLE = keccak256("FUND_MANAGER_ROLE");
    bytes32 public constant AGENCY_MANAGER_ROLE = keccak256("AGENCY_MANAGER_ROLE");
    bytes32 public constant ROYALTY_MANAGER_ROLE = keccak256("ROYALTY_MANAGER_ROLE");
    bytes32 public constant CONTRACT_APPROVER_ROLE = keccak256("CONTRACT_APPROVER_ROLE");
    bytes32 public constant MINT_VALIDATOR_ROLE = keccak256("MINT_VALIDATOR_ROLE");
    bytes32 public constant REFUND_MANAGER_ROLE = keccak256("REFUND_MANAGER_ROLE");
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");
    bytes32 public constant MARKET_PLACE = keccak256("MARKET_PLACE");

    struct NFTVoucher {
        uint256 tokenId;
        uint256 price;
        uint256 quantity;
        uint256 buyerQty;
        uint256 start;
        uint256 end;
        uint96 royalty;
        bool isStealth;
        bool isSbt;
        bytes creator;
        bytes validator;
    }

    event Minted(address indexed creator, uint256 indexed tokenId, uint256 quantity, address indexed buyer);
    event Burnt(uint256 indexed tokenId, uint256 quantity);
    event Refunded(uint256 indexed tokenId, address indexed from, uint256 qty);
    // SBT
    event Locked(uint256 tokenId);
    event Unlocked(uint256 tokenId);


    error AccessDenied(bytes32 role, address sender);
    error AlreadyAdded(address account);
    error Deprecated();
    error InsufficientBalance();
    error InvalidPrice(uint256 tokenId, uint256 price);
    error InvalidSender(address sender);
    error NonTransferableToken();
    error NotSupported(address account);
    error NotTokenCreator(address creator, uint256 tokenId);
    error NotTokenOwner(address wallet, uint256 tokenId, uint256 qty);
    error TransferError();
    error TokenSaleNotStarted(uint256 tokenId, uint256 start, uint256 now);
    error TokenSaleEnded(uint256 tokenId, uint256 end, uint256 now);
    error InvalidTokenQty721(uint256 tokenId);
    error InvalidTokenQty(uint256 tokenId,uint256 expected,uint256 actual);

    constructor(address manager, address minter, address fundManager, address agencyManager, address royaltyManager, address contractApprover, address mintValidator, address refundManager, address [] memory relayers) ERC1155("")  EIP712("moshpit", "1") {
        baseUri = "NoUrl";
        stealthUri = "StealthUrl";
        platformFee = 1000; // 1000 means 10%
        pioneerFee = 500;
        name = "dpNftV1";
        symbol = "DPN1";
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MANAGER_ROLE, manager);
        _grantRole(MINTER_ROLE, minter);
        _grantRole(FUND_MANAGER_ROLE, fundManager);
        _grantRole(AGENCY_MANAGER_ROLE, agencyManager);
        _grantRole(ROYALTY_MANAGER_ROLE, royaltyManager);
        _grantRole(CONTRACT_APPROVER_ROLE, contractApprover);
        _grantRole(MINT_VALIDATOR_ROLE, mintValidator);
        _grantRole(REFUND_MANAGER_ROLE, refundManager);
        for (uint256 i=0; i < relayers.length;i++){
            _grantRole(RELAYER_ROLE, relayers[i]);
        }
        _setDefaultRoyalty(msg.sender, 1000);
    }


    modifier accessCheck(uint256 role) {
        bytes32[10] memory roles = [
            DEFAULT_ADMIN_ROLE,
            MANAGER_ROLE,
            MINTER_ROLE,
            FUND_MANAGER_ROLE,
            AGENCY_MANAGER_ROLE,
            ROYALTY_MANAGER_ROLE,
            CONTRACT_APPROVER_ROLE,
            MINT_VALIDATOR_ROLE,
            REFUND_MANAGER_ROLE,
            RELAYER_ROLE
        ];
        
        if(!hasRole(roles[0], msg.sender)) {
            if(!hasRole(roles[1], msg.sender)) {
                if(!hasRole(roles[role], msg.sender)) {
                    revert AccessDenied(roles[role], msg.sender);
                }
            }
        }
        _;
    }


    modifier tokenCheck(address tokenAddress) {
        if(!supportedTokens[tokenAddress]) revert NotSupported(tokenAddress);
        _;
    }


    modifier deprecated() {
        if(isDeprecated) revert Deprecated();
        _;
    }


    /// @notice Mint the nft native currency.
    /// @param voucher NFTVoucher that describes the NFT to be redeemed.
    function mintNft(NFTVoucher calldata voucher) external payable deprecated nonReentrant {
        address creator = verifyVoucher(voucher);
        uint256 price = voucher.price * voucher.buyerQty;
        if(msg.value < price) revert InsufficientBalance();


       uint256 fee = fees(price, pioneers[creator]);


        mint(creator, msg.sender, voucher.tokenId, voucher.royalty, voucher.isSbt, voucher.isStealth, voucher.quantity, voucher.buyerQty);


        Address.sendValue(payable(creator), price - fee);


        address agencyWallet = agencyCreator[creator];
        if (agencyWallet != address(0)){
            uint256 agencyAmount = agencyFees(price, agencyWallet);
            Address.sendValue(payable(agencyWallet), agencyAmount);
        }
    }


    /// @notice Mint the nft with token.
    /// @param voucher NFTVoucher that describes the NFT to be redeemed.
    /// @param tokenAddress The Address of token used to pay for the NFT.
    function mintNftWithToken(NFTVoucher calldata voucher, address tokenAddress) external deprecated tokenCheck(tokenAddress) nonReentrant {
        address creator = verifyVoucher(voucher);
        uint256 price = voucher.price * voucher.buyerQty;
        IERC20 token = IERC20(tokenAddress);


        uint256 fee = fees(price, pioneers[creator]);


        // Receive the funds
        token.transferFrom(msg.sender, address(this), price);
        mint(creator, msg.sender, voucher.tokenId, voucher.royalty, voucher.isSbt, voucher.isStealth, voucher.quantity, voucher.buyerQty);


        token.transfer(creator, price - fee);


        address agencyWallet = agencyCreator[creator];
        if (agencyWallet != address(0)){

            uint256 agencyAmount = agencyFees(price, agencyWallet);
            token.transfer(agencyWallet, agencyAmount);
        }
    }


    /// @notice Mint the NFT from the dappunk api.
    /// @param voucher NFTVoucher that describes the NFT to be redeemed.
    /// @param buyer The user who is buying the NFT.
    function mintNft(NFTVoucher calldata voucher, address buyer) external deprecated accessCheck(2) {
        address creator = verifyVoucher(voucher);
        mint(creator, buyer, voucher.tokenId, voucher.royalty, voucher.isSbt, voucher.isStealth, voucher.quantity, voucher.buyerQty);
    }




    /// @notice Mint the NFT using relayers
    /// @param voucher NFTVoucher that describes the NFT to be redeemed.
    /// @param buyer The user who is buying the NFT
    function mintNftGasless(NFTVoucher calldata voucher, address buyer) external payable deprecated accessCheck(9) {
        address creator = verifyVoucher(voucher);
        uint256 price = voucher.price * voucher.buyerQty;
        if(msg.value < price) revert InsufficientBalance();

        uint256 fee = fees(price, pioneers[creator]);

        mint(creator, buyer, voucher.tokenId, voucher.royalty, voucher.isSbt, voucher.isStealth, voucher.quantity, voucher.buyerQty);

        Address.sendValue(payable(creator), price - fee);

        address agencyWallet = agencyCreator[creator];
        if (agencyWallet != address(0)){
            // uint256 agencyAmount = (price * agencyFee[agencyWallet])/_feeDenominator();
            uint256 agencyAmount = agencyFees(price, agencyWallet);
            Address.sendValue(payable(agencyWallet), agencyAmount);
        }
    }


    /// @notice Internal minting function that mints the NFT.
    /// @param creator Wallet of the NFT creater.
    /// @param buyer Wallet of the buyer.
    /// @param tokenId Token that is being minted.
    /// @param tokenRoyalty The price of the nft.
    /// @param quantity Total qty of the mint.
    /// @param buyerQty Qty to be minted by this buyer.
    /// @param isSBT Sets the token as non-transferable.
    /// @param isStealth Sets the token as stealth.
    function mint(address creator, address buyer, uint256 tokenId, uint96 tokenRoyalty, bool isSBT, bool isStealth, uint256 quantity, uint256 buyerQty) internal {
        // require(tokenMintedQty[tokenId] + buyerQty <= tokenMaxQty[tokenId], "INSUFFICIENT: All token are minted");
        _mint(buyer, tokenId, buyerQty, "");
        // For the first mint
        if (tokenMaxQty[tokenId] == 0 ){
            tokenMintedQty[tokenId] = 0;
            tokenMaxQty[tokenId] = quantity;
            _setTokenRoyalty(tokenId, creator, tokenRoyalty);
            creatorRegistry[tokenId] = creator;
            if (isSBT) {
                sbt[tokenId] = true;
                emit Locked(tokenId);
            }
            if (isStealth) {
                stealth[tokenId] = true;
            }
        }
        tokenMintedQty[tokenId] += buyerQty;
        emit Minted(creator, tokenId, buyerQty, buyer);
    }


    /// @notice Calculats the fees.
    /// @param value The price of the NFT.
    /// @param isPioneer Is the creator a pioneer.
    /// @return Calculated platform fees.
    function fees(uint256 value, bool isPioneer) internal view returns (uint256) {
        if(isPioneer) {
            return ((value * pioneerFee)/_feeDenominator());
        } else{
            return ((value * platformFee)/_feeDenominator());
        }
    }


    /// @notice Calculats the agency fees.
    /// @param value The price of the NFT.
    /// @param agency Agency wallet address.
    /// @return Calculated agency fees.
    function agencyFees(uint256 value, address agency) internal view returns (uint256) {
        return ((value * agencyFee[agency])/_feeDenominator());
    }


    /// @notice Verifies the signature for a given NFTVoucher, returning the address of the creator.
    /// @param voucher NFTVoucher describing an NFT.
    /// @return creator Address of the creator of the NFT.
    function verifyVoucher(NFTVoucher calldata voucher) public view returns(address) {
        // Perform general validations
        _validateVoucher(voucher);

        // Verify signatures
        address creator = _verifySignatures(voucher);

        // Timestamp verification
        uint256 _now = block.timestamp;
        if(voucher.start != 0 && _now < voucher.start) revert TokenSaleNotStarted(voucher.tokenId, voucher.start, _now);
        if(voucher.end != 0 && _now > voucher.end) revert TokenSaleEnded(voucher.tokenId, voucher.end, _now);

        return creator;
    }

    function _validateVoucher(NFTVoucher calldata voucher) internal view {
        uint16 retrivedQuantity = uint16(voucher.tokenId & 0xFFFF);
        if(voucher.price <= 0) revert InvalidPrice(voucher.tokenId, voucher.price);
        if(voucher.quantity<1) revert InvalidTokenQty(voucher.tokenId, retrivedQuantity, voucher.quantity);
        if(voucher.quantity != retrivedQuantity) revert InvalidTokenQty(voucher.tokenId, retrivedQuantity, voucher.quantity);
        if(voucher.buyerQty > retrivedQuantity) revert InvalidTokenQty(voucher.tokenId, retrivedQuantity, voucher.buyerQty);
    
        uint256 tokenQty = tokenMaxQty[voucher.tokenId];
        if (tokenQty > 0) {
            uint256 tokensMinted = tokenMintedQty[voucher.tokenId];
            if (tokensMinted + voucher.buyerQty > tokenQty) revert InvalidTokenQty(voucher.tokenId, tokensMinted, tokensMinted + voucher.buyerQty);
        }
    }

    function _verifySignatures(NFTVoucher calldata voucher) internal view  returns(address){
        bytes32 digest = _hashTypedDataV4(keccak256(abi.encode(
            keccak256("NFTVoucher(uint256 tokenId,uint256 price,uint256 quantity,uint256 buyerQty,uint256 start,uint256 end,uint96 royalty,bool isStealth,bool isSbt)"),
            voucher.tokenId,
            voucher.price,
            voucher.quantity,
            voucher.buyerQty,
            voucher.start,
            voucher.end,
            voucher.royalty,
            voucher.isStealth,
            voucher.isSbt
        )));
        
        address creator = ECDSA.recover(digest, voucher.creator);
        if(voucher.tokenId >> 96 != uint(uint160(creator))) revert InvalidSender(creator);
        
        address validator = ECDSA.recover(digest, voucher.validator);
        if(!hasRole(MINT_VALIDATOR_ROLE, validator)) revert AccessDenied(MINT_VALIDATOR_ROLE, validator);
        
        return creator;
    }



    /* URI MANEGEMENT */
    /// @notice Returns the URI to the token's metadata.
    /// @param tokenId Nft token id.
    function uri(uint256 tokenId) public override view returns (string memory) {
        if (stealth[tokenId]){
            return bytes(stealthUri).length > 0 ? string(abi.encodePacked(stealthUri)): "";
        }
        if(!uriSuffixEnabled) {
            return bytes(baseUri).length > 0 ? string(abi.encodePacked(baseUri, tokenId.toString())): "";
        }
        return bytes(baseUri).length > 0 ? string(abi.encodePacked(baseUri, tokenId.toString(), uriSuffix)): "";
    }


    /// @notice Update the baseURI.
    /// @param newBaseUri New collection uri.
    function updateBaseUri(string memory newBaseUri) external accessCheck(1) {
        baseUri = newBaseUri;
    }


    /// @notice Update stealth NFT URI.
    /// @param newStealthUri New stealth URI.
    function updateStealthUri(string memory newStealthUri) external accessCheck(1) {
        stealthUri = newStealthUri;
    }


    /// @notice Update URI's base extention.
    /// @param newSuffix New base uri extention.
    function updateUriSuffix(string memory newSuffix) external accessCheck(1) {
        uriSuffix = newSuffix;
    }


    /// @notice Flips the flag to use UriSuffix.
    function toggleUriSuffix() external accessCheck(1) {
        uriSuffixEnabled = !uriSuffixEnabled;
    }


    /* SBT - SOUL BOUND TOKENS - NON TRANSFERABLE */


    function locked(uint256 tokenId) external view returns (bool) {
        if(sbt[tokenId]) return true;
        return false;
    }
 
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values) internal virtual override {
        for (uint256 i = 0; i < ids.length; ++i) {
            if (to != address(0)) {
                if(sbt[ids[i]] && !hasRole(REFUND_MANAGER_ROLE, msg.sender)) {
                    revert NonTransferableToken();
                }
            }
        }
        return super._update(from, to, ids, values);
    }


    function burn(uint256 tokenId, uint256 quantity) external {
        if(balanceOf(msg.sender, tokenId) < quantity) revert InsufficientBalance();
        _burn(msg.sender, tokenId, quantity);
        tokenMaxQty[tokenId] -= quantity;
        tokenMintedQty[tokenId] -= quantity;
        if(tokenMaxQty[tokenId] == 0) {
            creatorRegistry[tokenId] = address(0);
        }
        emit Burnt(tokenId, quantity);
    }


    /* REFUND */


    /// @notice Refund an NFT back to creator.
    /// @dev Can only be performed by REFUND_MANAGER
    /// @param tokenId The tokenID of the NFT which needs to be refunded.
    /// @param creator The creator of the NFT.
    /// @param owner Current owner of the NFT.
    /// @param qty How many of this NFT to refund.
    function refundNFT(uint256 tokenId, address creator, address owner, uint256 qty) external accessCheck(8) {
        if(creatorRegistry[tokenId] != creator) revert NotTokenCreator(creator, tokenId);
        if(balanceOf(owner, tokenId) < qty) revert NotTokenOwner(owner, tokenId, qty);
        safeTransferFrom(owner, creator, tokenId, qty, "");
        emit Refunded(tokenId, owner, qty);
    }


    /// @dev Override to allow refund.
    function isApprovedForAll(address account, address operator) public view override returns (bool) {
        if (approvedContracts[operator]) {
          return true;
        }
        if (hasRole(REFUND_MANAGER_ROLE, operator)) {
            return true;
        }


        return super.isApprovedForAll(account, operator);
    }


    /* PIONEER MANAGEMENT */


    /// @notice Grant wallet pioneer status.
    /// @param pioneer The pioneer wallet.
    function addPioneer(address pioneer) external accessCheck(4) {
        // require(!pioneers[pioneer], "ALREADYEXIST: Wallet is already exist");
        if (pioneers[pioneer]) revert AlreadyAdded(pioneer);
        pioneers[pioneer] = true;
    }


    /* AGENCY MANAGEMENT */


    /// @notice Add an agency and specify their fee.
    /// @param agency The agency wallet.
    /// @param fee The fee for the agency.
    function addAgency(address agency, uint256 fee) external  accessCheck(4) {
        // require(agencyFee[agency] <= 0, "Agency already added");
        if (agencyFee[agency] > 0) revert AlreadyAdded(agency);
        agencyFee[agency] = fee;
    }


    /// @notice To add the creator wallet corresponding to their agency.
    /// @param agency The agency wallet.
    /// @param creators Creator wallets to be added as creators of this agency.
    function addCreator(address agency, address[] memory creators) external accessCheck(4) {
        for (uint256 i = 0; i < creators.length; i++){
            // TODO: Maybe convert this to a skip, rather than a revert?
            if (agencyCreator[creators[i]] != address(0)) revert AlreadyAdded(creators[i]);
            agencyCreator[creators[i]] = agency;
        }
    }


    /* PRE-APPROVED CONTRACTS */


    /// @notice dappunk pre-approved contracts.
    /// @dev reduce dappunk creators gas by not requiring approval for this contract.
    /// @param contractAddress The contract to set as approved.
    function setApprovedContract(address contractAddress) public accessCheck(6) {
        if(approvedContracts[contractAddress]) revert AlreadyAdded(contractAddress);
        approvedContracts[contractAddress] = true;
    }


    /// @notice Removes a pre-approved contracts.
    /// @param contractAddress The contract no longer be approved.
    function removeApprovedContract(address contractAddress) public accessCheck(6) {
        // require(approvedContracts[contractAddress], "DoesntExist: Contract not approved");
        if(!approvedContracts[contractAddress]) revert NotSupported(contractAddress);
        approvedContracts[contractAddress] = false;
    }


    /* CONTRACT STATE */


    function deprecate() external deprecated accessCheck(0) {
        isDeprecated = true;
    }


    function reviveContract() external accessCheck(0) {
        isDeprecated = false;
    }


    /* FUND MANAGEMENT */


    /// @notice Add an erc20 token support for payment.
    /// @param tokenAddress Address of ERC20 token contract.
    function addSupportedToken(address tokenAddress) external accessCheck(1) {
        if(supportedTokens[tokenAddress])revert AlreadyAdded(tokenAddress);
        supportedTokens[tokenAddress] = true;
    }


    /// @notice Remove an ERC20 token support for payment.
    /// @param tokenAddress Address of ERC20 token contract.
    function removeSupportedToken(address tokenAddress) external tokenCheck(tokenAddress) accessCheck(1) {
        supportedTokens[tokenAddress] = false;
    }


    /// @notice Withdraw all of the platform native currency from contract.
    function withdraw() external accessCheck(3) {
        Address.sendValue(payable(msg.sender), address(this).balance);
    }


    /// @notice Withdraw all of a token from contract.
    /// @param tokenAddress Address of ERC20 token contract.
    function withdraw(address tokenAddress) external tokenCheck(tokenAddress) accessCheck(3) {
        IERC20 token = IERC20(tokenAddress);
        bool success = token.transfer(msg.sender, token.balanceOf(address(this)));
        if(!success) revert TransferError();
    }


    /// @dev See {IERC165-supportsInterface}.
    function supportsInterface(bytes4 interfaceId) public view override(ERC1155, ERC2981, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }


    function setApprovalForAll(address operator, bool approved) public override {
        if(hasRole(MARKET_PLACE,msg.sender)){
            _setApprovalForAll(operator, msg.sender, approved);
        }else{
            _setApprovalForAll(_msgSender(), operator, approved);
        }
    }




    receive() external payable{}
}
