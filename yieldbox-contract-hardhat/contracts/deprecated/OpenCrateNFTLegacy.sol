// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract OpenCrateNFTLegacy is ERC721, ERC2981, Ownable {
    using Strings for uint256;

    uint256 public constant USD_DECIMALS = 2;
    uint256 public constant MIN_PRICE_USD = 5 * 10 ** USD_DECIMALS; // $5.00
    uint256 public constant MAX_PRICE_USD = 1000 * 10 ** USD_DECIMALS; // $1,000.00
    uint16 public constant MIN_BOOST_BPS = 10_000; // 1.0x
    uint16 public constant MAX_BOOST_BPS = 20_000; // 2.0x
    uint16 public constant MAX_BPS = 10_000;
    uint64 public constant MAX_LOCK_DURATION = 365 days;

    struct CrateInfo {
        uint8 riskLevel;
        uint256 strategyId;
        address account;
        uint64 mintedAt;
        uint64 lockedUntil;
        uint16 boostMultiplierBps;
        uint256 priceUsd;
        address creator;
        uint16 revenueShareBps;
        uint16 platformFeeBps;
        uint16 performanceFeeBps;
        string riskDisclosure;
        string feeDisclosure;
        uint64 lastRebalanceAt;
        uint64 nextHarvestAt;
        uint256 accruedYieldUsd;
        bool boostActive;
        uint64 lastBoostAt;
        uint64 lastLockAt;
    }

    struct PositionDetails {
        string protocol;
        string asset;
        string strategyType;
        string chain;
        string infoURL;
        uint16 allocationBps;
        uint256 allocationUsd;
        int256 netApyBps;
        int256 baseAprBps;
        int256 incentivesAprBps;
        int256 feeBps;
        uint8 riskScore;
        uint64 openedAt;
        uint64 lastRebalancedAt;
        uint64 nextHarvestAt;
        uint256 accruedYieldUsd;
    }

    struct PositionPayload {
        string protocol;
        string asset;
        string strategyType;
        string chain;
        string infoURL;
        uint16 allocationBps;
        uint256 allocationUsd;
        int256 netApyBps;
        int256 baseAprBps;
        int256 incentivesAprBps;
        int256 feeBps;
        uint8 riskScore;
        uint64 openedAt;
        uint64 lastRebalancedAt;
        uint64 nextHarvestAt;
        uint256 accruedYieldUsd;
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
    error InvalidBps();
    error InvalidPositionTotalAllocation();

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
    event PositionsUpdated(uint256 indexed tokenId, uint256 positionCount, address indexed updater);
    event PositionMetricsUpdated(uint256 indexed tokenId, uint256 indexed positionIndex, PositionDetails details);
    event LifecycleUpdated(uint256 indexed tokenId, uint64 lastRebalanceAt, uint64 nextHarvestAt, uint256 accruedYieldUsd);
    event RevenueShareUpdated(uint256 indexed tokenId, uint16 revenueShareBps, uint16 platformFeeBps, uint16 performanceFeeBps);
    event RiskDisclosureUpdated(uint256 indexed tokenId, string riskDisclosure);
    event FeeDisclosureUpdated(uint256 indexed tokenId, string feeDisclosure);
    event BoostStatusUpdated(uint256 indexed tokenId, bool active, uint16 boostMultiplierBps);

    address public factory;
    string private _baseTokenURI;
    uint256 private _nextTokenId;
    uint256 private _totalMinted;

    mapping(uint256 => CrateInfo) private _crateInfo;
    mapping(uint256 => PositionDetails[]) private _positions;

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
        uint64 lockDuration,
        address creator,
        uint16 revenueShareBps,
        uint16 platformFeeBps,
        uint16 performanceFeeBps,
        string calldata riskDisclosure,
        string calldata feeDisclosure,
        uint64 lastRebalanceAt,
        uint64 nextHarvestAt,
        uint256 accruedYieldUsd,
        bool boostActive,
        PositionPayload[] calldata positions
    ) external returns (uint256 tokenId) {
        if (msg.sender != factory) revert Unauthorized();
        if (account == address(0)) revert InvalidAccount();
        if (to == address(0)) revert InvalidRecipient();
        _validatePrice(priceUsd);
        _validateBoost(boostMultiplierBps);
        if (lockDuration > MAX_LOCK_DURATION) revert InvalidLockDuration();
        _validateFeeSet(revenueShareBps, platformFeeBps, performanceFeeBps);

        tokenId = _nextTokenId;
        unchecked {
            ++_nextTokenId;
            ++_totalMinted;
        }

        uint64 lockedUntil = lockDuration == 0 ? 0 : uint64(block.timestamp + lockDuration);
        address crateCreator = creator == address(0) ? to : creator;
        uint64 lastLockAt = lockedUntil == 0 ? 0 : uint64(block.timestamp);
        uint64 lastBoostAt = boostActive ? uint64(block.timestamp) : 0;

        _safeMint(to, tokenId);
        _crateInfo[tokenId] = CrateInfo({
            riskLevel: riskLevel,
            strategyId: strategyId,
            account: account,
            mintedAt: uint64(block.timestamp),
            lockedUntil: lockedUntil,
            boostMultiplierBps: boostMultiplierBps,
            priceUsd: priceUsd,
            creator: crateCreator,
            revenueShareBps: revenueShareBps,
            platformFeeBps: platformFeeBps,
            performanceFeeBps: performanceFeeBps,
            riskDisclosure: riskDisclosure,
            feeDisclosure: feeDisclosure,
            lastRebalanceAt: lastRebalanceAt,
            nextHarvestAt: nextHarvestAt,
            accruedYieldUsd: accruedYieldUsd,
            boostActive: boostActive,
            lastBoostAt: lastBoostAt,
            lastLockAt: lastLockAt
        });

        _setPositions(tokenId, positions);

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
        _requireFactoryOrAuthorized(tokenId);
        _validatePrice(newPriceUsd);
        _crateInfo[tokenId].priceUsd = newPriceUsd;
        emit PriceUpdated(tokenId, newPriceUsd);
    }

    function setBoostMultiplier(uint256 tokenId, uint16 newBoostMultiplierBps) external {
        _requireFactoryOrAuthorized(tokenId);
        _validateBoost(newBoostMultiplierBps);
        CrateInfo storage info = _crateInfo[tokenId];
        info.boostMultiplierBps = newBoostMultiplierBps;
        info.boostActive = true;
        info.lastBoostAt = uint64(block.timestamp);
        emit BoostUpdated(tokenId, newBoostMultiplierBps);
        emit BoostStatusUpdated(tokenId, true, newBoostMultiplierBps);
    }

    function setBoostStatus(uint256 tokenId, bool active, uint16 newBoostMultiplierBps) external {
        _requireFactoryOrAuthorized(tokenId);
        _validateBoost(newBoostMultiplierBps);
        CrateInfo storage info = _crateInfo[tokenId];
        info.boostMultiplierBps = newBoostMultiplierBps;
        info.boostActive = active;
        info.lastBoostAt = uint64(block.timestamp);
        emit BoostStatusUpdated(tokenId, active, newBoostMultiplierBps);
        emit BoostUpdated(tokenId, newBoostMultiplierBps);
    }

    function extendLock(uint256 tokenId, uint64 additionalDuration) external {
        _requireFactoryOrAuthorized(tokenId);
        if (additionalDuration == 0 || additionalDuration > MAX_LOCK_DURATION) revert InvalidLockDuration();

        CrateInfo storage info = _crateInfo[tokenId];
        uint64 base = info.lockedUntil > block.timestamp ? info.lockedUntil : uint64(block.timestamp);
        uint64 newLockedUntil = base + additionalDuration;
        if (newLockedUntil - uint64(block.timestamp) > MAX_LOCK_DURATION) revert InvalidLockDuration();

        info.lockedUntil = newLockedUntil;
        info.lastLockAt = uint64(block.timestamp);
        emit LockExtended(tokenId, newLockedUntil);
    }

    function updatePositions(uint256 tokenId, PositionPayload[] calldata positions) external {
        _requireFactoryOrAuthorized(tokenId);
        _setPositions(tokenId, positions);
    }

    function getPositions(uint256 tokenId) external view returns (PositionDetails[] memory) {
        PositionDetails[] storage stored = _positions[tokenId];
        PositionDetails[] memory copy = new PositionDetails[](stored.length);
        for (uint256 i = 0; i < stored.length; ++i) {
            copy[i] = stored[i];
        }
        return copy;
    }

    function positionsCount(uint256 tokenId) external view returns (uint256) {
        return _positions[tokenId].length;
    }

    function updateLifecycle(uint256 tokenId, uint64 lastRebalanceAt, uint64 nextHarvestAt, uint256 accruedYieldUsd) external {
        _requireFactoryOrAuthorized(tokenId);
        CrateInfo storage info = _crateInfo[tokenId];
        info.lastRebalanceAt = lastRebalanceAt;
        info.nextHarvestAt = nextHarvestAt;
        info.accruedYieldUsd = accruedYieldUsd;
        emit LifecycleUpdated(tokenId, lastRebalanceAt, nextHarvestAt, accruedYieldUsd);
    }

    function updateRevenueShare(uint256 tokenId, uint16 revenueShareBps, uint16 platformFeeBps, uint16 performanceFeeBps) external {
        _requireFactoryOrAuthorized(tokenId);
        _validateFeeSet(revenueShareBps, platformFeeBps, performanceFeeBps);
        CrateInfo storage info = _crateInfo[tokenId];
        info.revenueShareBps = revenueShareBps;
        info.platformFeeBps = platformFeeBps;
        info.performanceFeeBps = performanceFeeBps;
        emit RevenueShareUpdated(tokenId, revenueShareBps, platformFeeBps, performanceFeeBps);
    }

    function updateDisclosures(uint256 tokenId, string calldata riskDisclosure, string calldata feeDisclosure) external {
        _requireFactoryOrAuthorized(tokenId);
        CrateInfo storage info = _crateInfo[tokenId];
        info.riskDisclosure = riskDisclosure;
        info.feeDisclosure = feeDisclosure;
        emit RiskDisclosureUpdated(tokenId, riskDisclosure);
        emit FeeDisclosureUpdated(tokenId, feeDisclosure);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address) {
        address from = super._update(to, tokenId, auth);

        if (from != address(0) && to != from) {
            CrateInfo memory info = _crateInfo[tokenId];
            if (info.lockedUntil != 0 && block.timestamp < info.lockedUntil) {
                revert TokenLocked(info.lockedUntil);
            }
        }

        return from;
    }

    function _requireFactoryOrAuthorized(uint256 tokenId) internal view {
        if (msg.sender == factory) {
            if (_ownerOf(tokenId) == address(0)) revert NonexistentToken();
            return;
        }
        _checkAuthorized(tokenId);
    }

    function _checkAuthorized(uint256 tokenId) internal view {
        address owner = _ownerOf(tokenId);
        if (owner == address(0)) revert NonexistentToken();
        if (!_isAuthorized(owner, msg.sender, tokenId)) revert NotApprovedOrOwner();
    }

    function _validatePrice(uint256 priceUsd) internal pure {
        if (priceUsd < MIN_PRICE_USD || priceUsd > MAX_PRICE_USD) revert InvalidPrice();
    }

    function _validateBoost(uint16 boostMultiplierBps) internal pure {
        if (boostMultiplierBps < MIN_BOOST_BPS || boostMultiplierBps > MAX_BOOST_BPS) revert InvalidBoost();
    }

    function _validateFeeSet(uint16 revenueShareBps, uint16 platformFeeBps, uint16 performanceFeeBps) internal pure {
        if (revenueShareBps > MAX_BPS || platformFeeBps > MAX_BPS || performanceFeeBps > MAX_BPS) revert InvalidBps();
        if (uint256(revenueShareBps) + platformFeeBps + performanceFeeBps > MAX_BPS) revert InvalidBps();
    }

    function _setPositions(uint256 tokenId, PositionPayload[] calldata positions) internal {
        delete _positions[tokenId];
        uint256 totalBps;
        for (uint256 i = 0; i < positions.length; ++i) {
            PositionPayload calldata payload = positions[i];
            if (payload.allocationBps > MAX_BPS) revert InvalidBps();
            totalBps += payload.allocationBps;
            PositionDetails memory details = PositionDetails({
                protocol: payload.protocol,
                asset: payload.asset,
                strategyType: payload.strategyType,
                chain: payload.chain,
                infoURL: payload.infoURL,
                allocationBps: payload.allocationBps,
                allocationUsd: payload.allocationUsd,
                netApyBps: payload.netApyBps,
                baseAprBps: payload.baseAprBps,
                incentivesAprBps: payload.incentivesAprBps,
                feeBps: payload.feeBps,
                riskScore: payload.riskScore,
                openedAt: payload.openedAt,
                lastRebalancedAt: payload.lastRebalancedAt,
                nextHarvestAt: payload.nextHarvestAt,
                accruedYieldUsd: payload.accruedYieldUsd
            });
            _positions[tokenId].push(details);
            emit PositionMetricsUpdated(tokenId, i, details);
        }
        if (totalBps > MAX_BPS) revert InvalidPositionTotalAllocation();
        emit PositionsUpdated(tokenId, positions.length, msg.sender);
    }
}


