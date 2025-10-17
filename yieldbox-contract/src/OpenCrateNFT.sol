// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract OpenCrateNFT is ERC721, ERC2981, Ownable {
    using Strings for uint256;

    uint256 public constant USD_DECIMALS = 2;
    uint256 public constant MIN_PRICE_USD = 5 * 10 ** USD_DECIMALS; // $5.00
    uint256 public constant MAX_PRICE_USD = 1000 * 10 ** USD_DECIMALS; // $1,000.00
    uint16 public constant MIN_BOOST_BPS = 10_000; // 1.0x
    uint16 public constant MAX_BOOST_BPS = 20_000; // 2.0x
    uint64 public constant MAX_LOCK_DURATION = 365 days;

    struct CrateInfo {
        uint8 riskLevel;
        uint256 strategyId;
        address account;
        uint64 mintedAt;
        uint64 lockedUntil;
        uint16 boostMultiplierBps;
        uint256 priceUsd;
    }

    error Unauthorized();
    error InvalidAccount();
    error InvalidRecipient();
    error InvalidFactory();
    error NotApprovedOrOwner();
    error InvalidPrice();
    error InvalidBoost();
    error InvalidLockDuration();
    error NonexistentToken();
    error TokenLocked(uint64 lockedUntil);

    event FactoryUpdated(address indexed newFactory);
    event BaseURIUpdated(string baseURI);
    event CrateMinted(
        uint256 indexed tokenId,
        address indexed to,
        uint8 riskLevel,
        uint256 strategyId,
        address account,
        uint256 priceUsd,
        uint16 boostMultiplierBps,
        uint64 lockedUntil
    );
    event PriceUpdated(uint256 indexed tokenId, uint256 priceUsd);
    event BoostUpdated(uint256 indexed tokenId, uint16 boostMultiplierBps);
    event LockExtended(uint256 indexed tokenId, uint64 lockedUntil);

    address public factory;
    string private _baseTokenURI;
    uint256 private _nextTokenId;
    uint256 private _totalMinted;

    mapping(uint256 => CrateInfo) private _crateInfo;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        address owner_,
        address factory_
    ) ERC721(name_, symbol_) Ownable(owner_ == address(0) ? msg.sender : owner_) {
        factory = factory_;
        _baseTokenURI = baseURI_;
        _nextTokenId = 1;

        _setDefaultRoyalty(owner(), 500);
    }

    function setFactory(address newFactory) external onlyOwner {
        if (newFactory == address(0)) revert InvalidFactory();
        factory = newFactory;
        emit FactoryUpdated(newFactory);
    }

    function setBaseURI(string calldata baseURI_) external onlyOwner {
        _baseTokenURI = baseURI_;
        emit BaseURIUpdated(baseURI_);
    }

    function setDefaultRoyalty(address receiver, uint96 feeNumerator) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function deleteDefaultRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }

    function mintCrate(
        address to,
        uint8 riskLevel,
        uint256 strategyId,
        address account,
        uint256 priceUsd,
        uint16 boostMultiplierBps,
        uint64 lockDuration
    ) external returns (uint256 tokenId) {
        if (msg.sender != factory) revert Unauthorized();
        if (account == address(0)) revert InvalidAccount();
        if (to == address(0)) revert InvalidRecipient();
        _validatePrice(priceUsd);
        _validateBoost(boostMultiplierBps);
        if (lockDuration > MAX_LOCK_DURATION) revert InvalidLockDuration();

        tokenId = _nextTokenId;
        unchecked {
            ++_nextTokenId;
            ++_totalMinted;
        }

        uint64 lockedUntil = lockDuration == 0 ? 0 : uint64(block.timestamp + lockDuration);

        _safeMint(to, tokenId);
        _crateInfo[tokenId] = CrateInfo({
            riskLevel: riskLevel,
            strategyId: strategyId,
            account: account,
            mintedAt: uint64(block.timestamp),
            lockedUntil: lockedUntil,
            boostMultiplierBps: boostMultiplierBps,
            priceUsd: priceUsd
        });

        emit CrateMinted(tokenId, to, riskLevel, strategyId, account, priceUsd, boostMultiplierBps, lockedUntil);
    }

    function crateInfo(uint256 tokenId) external view returns (CrateInfo memory) {
        if (_ownerOf(tokenId) == address(0)) revert NonexistentToken();
        return _crateInfo[tokenId];
    }

    function nextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }

    function totalMinted() external view returns (uint256) {
        return _totalMinted;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        if (_ownerOf(tokenId) == address(0)) revert NonexistentToken();
        if (bytes(_baseTokenURI).length == 0) {
            return "";
        }
        return string.concat(_baseTokenURI, tokenId.toString());
    }

    function updatePrice(uint256 tokenId, uint256 newPriceUsd) external {
        _checkAuthorized(tokenId);
        _validatePrice(newPriceUsd);
        _crateInfo[tokenId].priceUsd = newPriceUsd;
        emit PriceUpdated(tokenId, newPriceUsd);
    }

    function setBoostMultiplier(uint256 tokenId, uint16 newBoostMultiplierBps) external {
        _checkAuthorized(tokenId);
        _validateBoost(newBoostMultiplierBps);
        _crateInfo[tokenId].boostMultiplierBps = newBoostMultiplierBps;
        emit BoostUpdated(tokenId, newBoostMultiplierBps);
    }

    function extendLock(uint256 tokenId, uint64 additionalDuration) external {
        _checkAuthorized(tokenId);
        if (additionalDuration == 0 || additionalDuration > MAX_LOCK_DURATION) revert InvalidLockDuration();

        CrateInfo storage info = _crateInfo[tokenId];
        uint64 base = info.lockedUntil > block.timestamp ? info.lockedUntil : uint64(block.timestamp);
        uint64 newLockedUntil = base + additionalDuration;
        if (newLockedUntil - uint64(block.timestamp) > MAX_LOCK_DURATION) revert InvalidLockDuration();

        info.lockedUntil = newLockedUntil;
        emit LockExtended(tokenId, newLockedUntil);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    ) internal override {
        if (from != address(0) && to != from) {
            CrateInfo memory info = _crateInfo[tokenId];
            if (info.lockedUntil != 0 && block.timestamp < info.lockedUntil) {
                revert TokenLocked(info.lockedUntil);
            }
        }
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    function _checkAuthorized(uint256 tokenId) internal view {
        if (!_isApprovedOrOwner(msg.sender, tokenId)) revert NotApprovedOrOwner();
    }

    function _validatePrice(uint256 priceUsd) internal pure {
        if (priceUsd < MIN_PRICE_USD || priceUsd > MAX_PRICE_USD) revert InvalidPrice();
    }

    function _validateBoost(uint16 boostMultiplierBps) internal pure {
        if (boostMultiplierBps < MIN_BOOST_BPS || boostMultiplierBps > MAX_BOOST_BPS) revert InvalidBoost();
    }
}
