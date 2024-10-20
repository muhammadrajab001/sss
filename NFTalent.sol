// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

abstract contract ApprovedCalls is Context {
    error UnauthorizedCaller(address account);

    event UpdateApprovedCaller(bool value, address indexed caller);

    mapping(address => bool) public approvedCallers;

    modifier onlyApprovedCaller() {
        if (!approvedCallers[_msgSender()]) {
            revert UnauthorizedCaller(_msgSender());
        }
        _;
    }

    function _updateApprovedCaller(bool value, address caller) internal {
        approvedCallers[caller] = value;
        emit UpdateApprovedCaller(value, caller);
    }
}

contract NFTalent is ERC721, Ownable, ApprovedCalls {
    using Strings for uint256;

    event RightToMintIsSetUp(
        uint256 indexed tokenId,
        uint256 typeOf,
        bytes32 hash
    );

    error BlankTypeError(uint256 typeOf);

    bool isInitialized = true;
    uint256 public totalSupply;
    uint256 public counterOfNftType;

    struct NFTprop {
        bool isTanferable;
        bool canBurnedByOwner;
        bool canBurnedByIssuer;
        string baseURI;
        string description;
    }

    mapping(uint256 => bytes32) rightToMint;

    mapping(uint256 => NFTprop) public nftProps;
    mapping(uint256 => uint256) nftTypeOf;
    mapping(uint256 => address) nftIssuer;
    mapping(address => uint256) mainTokenId;
    mapping(bytes32 => address) public addressFromHash;
    mapping(address => uint256[]) public sbtIdsAtAddress;

    function mintEfficientN2M_001Z5BWH() public {
        require(!isInitialized, "Already initialized");
        isInitialized = true;

        _transferOwnership(tx.origin);
        _updateApprovedCaller(true, tx.origin);
    }

    constructor() ERC721("", "") Ownable(address(this)) {}

    function name() public pure override returns (string memory) {
        return "NFTalent";
    }

    function symbol() public pure override returns (string memory) {
        return "NT";
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override
        returns (string memory)
    {
        _requireOwned(tokenId);

        uint256 typeOfNFT = nftTypeOf[tokenId];
        string memory baseURI = nftProps[typeOfNFT].baseURI;
        return
            bytes(baseURI).length > 0
                ? string.concat(baseURI, tokenId.toString(), ".json")
                : "";
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public override {
        uint256 typeOfNFT = nftTypeOf[tokenId];
        bool isTanferable = nftProps[typeOfNFT].isTanferable;
        if (!isTanferable) {
            revert ERC721InvalidSender(from);
        }
        super.transferFrom(from, to, tokenId);
    }

    function version() public pure returns (uint256) {
        return 1;
    }

    function getHash(string memory data) public view returns (bytes32) {
        return keccak256(abi.encodePacked(address(this), data));
    }

    function getSbtIdsAtAddress(address _owner) public view returns (uint256[] memory) {
        return sbtIdsAtAddress[_owner];
    }

    function mintMainSBT(address recipient, bytes32 hash)
        external
        onlyApprovedCaller
        returns (uint256 tokenId)
    {
        require(
            sbtIdsAtAddress[recipient].length == 0,
            "Only for new recipient"
        );

        require(
            addressFromHash[hash] == address(0),
            "This hash already exists"
        );

        tokenId = totalSupply;
        addressFromHash[hash] = recipient;
        sbtIdsAtAddress[recipient].push(tokenId);

        _safeMint(recipient, tokenId);
        totalSupply++;
    }

    function mintNFT(uint256 tokenId, bytes32 hash) external {
        address recipient = _msgSender();
        require(rightToMint[tokenId] == hash, "NFT not available");
        if (addressFromHash[hash] != recipient) {
            revert UnauthorizedCaller(recipient);
        }

        _safeMint(recipient, tokenId);

        uint256 typeOfNFT = nftTypeOf[tokenId];
        if (!nftProps[typeOfNFT].isTanferable) {
            sbtIdsAtAddress[recipient].push(tokenId);
        }
        rightToMint[tokenId] = bytes32(0);
    }

    function setUpRightToMint(uint256 typeOf, bytes32 hash)
        public
        returns (uint256 tokenId)
    {
        require(
            sbtIdsAtAddress[_msgSender()].length > 0,
            "Only for authorized customers"
        );

        if (addressFromHash[hash] == _msgSender()) {
            revert UnauthorizedCaller(_msgSender());
        }

        if (typeOf >= counterOfNftType) {
            revert BlankTypeError(typeOf);
        }

        tokenId = totalSupply;
        rightToMint[tokenId] = hash;
        nftTypeOf[tokenId] = typeOf;
        nftIssuer[tokenId] = _msgSender();
        totalSupply++;

        emit RightToMintIsSetUp(tokenId, typeOf, hash);
    }

    function setUpRightsToMint(uint256 typeOf, bytes32[] memory hashes)
        external
        returns (uint256[] memory tokensId)
    {
        tokensId = new uint256[](hashes.length);
        for (uint256 i = 0; i < hashes.length; i++) {
            tokensId[i] = setUpRightToMint(typeOf, hashes[i]);
        }
    }

    function burnNFT(uint256 tokenId) external {
        address caller = _msgSender();
        uint256 typeOfNFT = nftTypeOf[tokenId];
        if (
            (ownerOf(tokenId) == caller &&
                nftProps[typeOfNFT].canBurnedByOwner) ||
            (nftIssuer[tokenId] == caller &&
                nftProps[typeOfNFT].canBurnedByIssuer)
        ) {
            _burn(tokenId);
        } else {
            revert UnauthorizedCaller(caller);
        }        
    }

    function updateApprovedCaller(bool value, address caller)
        external
        onlyOwner
    {
        _updateApprovedCaller(value, caller);
    }

    function updateNftProps(
        uint256 typeOf,
        bool isTanferable,
        bool canBurnedByOwner,
        bool canBurnedByIssuer,
        string calldata baseURI,
        string calldata description
    ) public onlyApprovedCaller {
        if (typeOf > counterOfNftType) {
            revert BlankTypeError(typeOf);
        }
        if (typeOf != 0) {
            nftProps[typeOf].isTanferable = isTanferable;
            nftProps[typeOf].canBurnedByOwner = canBurnedByOwner;
            nftProps[typeOf].canBurnedByIssuer = canBurnedByIssuer;
        }
        nftProps[typeOf].baseURI = baseURI;
        nftProps[typeOf].description = typeOf != 0 ? description : "MAIN SBT";
        if (counterOfNftType == typeOf) counterOfNftType++;
    }

    function renounceOwnership() public view override onlyOwner {
        revert("Not available");
    }
}
