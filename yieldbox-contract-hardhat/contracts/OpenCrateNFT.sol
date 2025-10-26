// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/common/ERC2981.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract OpenCrateNFT is ERC721, ERC2981, Ownable, ReentrancyGuard, Pausable {
    using Strings for uint256;
    using SafeERC20 for IERC20;

    uint256 public constant USD_DECIMALS = 2;
    uint256 public constant MIN_PRICE_USD = 5 * 10 ** USD_DECIMALS; // $5.00
    uint256 public constant MAX_PRICE_USD = 1000 * 10 ** USD_DECIMALS; // $1,000.00
    uint16 public constant MIN_BOOST_BPS = 10_000; // 1.0x
    uint16 public constant MAX_BOOST_BPS = 20_000; // 2.0x
    uint16 public constant MAX_BPS = 10_000;
    uint64 public constant MAX_LOCK_DURATION = 365 days;

    struct TokenInfo {
        bool enabled;
        uint256 priceUsd; // Price in USD (2 decimals)
        uint8 decimals; // Token decimals
    }

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
        address paymentToken; // Token used for payment
        uint256 paymentAmount; // Amount paid in token
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

    struct MintParams {
        address to;
        uint8 riskLevel;
        uint256 strategyId;
        address account;
        uint256 priceUsd;
        uint16 boostMultiplierBps;
        uint64 lockDuration;
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
        PositionPayload[] positions;
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
    error TokenNotSupported(address token);
    error InsufficientTokenPayment();
    error InvalidTokenAmount();
    error InvalidTokenAddress();
    error InvalidTokenPrice();
    error EmergencyModeActive();
    error NotInEmergencyMode();

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
        uint64 lockedUntil,
        address indexed paymentToken,
        uint256 paymentAmount
    );
    event PriceUpdated(uint256 indexed tokenId, uint256 priceUsd);
    event BoostUpdated(uint256 indexed tokenId, uint16 boostMultiplierBps);
    event LockExtended(uint256 indexed tokenId, uint64 lockedUntil);
    event PositionsUpdated(
        uint256 indexed tokenId,
        uint256 positionCount,
        address indexed updater
    );
    event PositionMetricsUpdated(
        uint256 indexed tokenId,
        uint256 indexed positionIndex,
        PositionDetails details
    );
    event LifecycleUpdated(
        uint256 indexed tokenId,
        uint64 lastRebalanceAt,
        uint64 nextHarvestAt,
        uint256 accruedYieldUsd
    );
    event RevenueShareUpdated(
        uint256 indexed tokenId,
        uint16 revenueShareBps,
        uint16 platformFeeBps,
        uint16 performanceFeeBps
    );
    event RiskDisclosureUpdated(uint256 indexed tokenId, string riskDisclosure);
    event FeeDisclosureUpdated(uint256 indexed tokenId, string feeDisclosure);
    event BoostStatusUpdated(
        uint256 indexed tokenId,
        bool active,
        uint16 boostMultiplierBps
    );
    event TokenAdded(address indexed token, uint256 priceUsd, uint8 decimals);
    event TokenRemoved(address indexed token);
    event TokenPriceUpdated(address indexed token, uint256 priceUsd);
    event EmergencyModeToggled(bool active);
    event EmergencyUnlock(uint256 indexed tokenId, address indexed owner);

    bool public emergencyMode;

    address public factory;
    string private _baseTokenURI;
    uint256 private _nextTokenId;
    uint256 private _totalMinted;

    mapping(uint256 => CrateInfo) private _crateInfo;
    mapping(uint256 => PositionDetails[]) private _positions;
    mapping(address => TokenInfo) public supportedTokens;
    address[] public whitelistedTokens;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory baseURI_,
        address owner_,
        address factory_
    )
        ERC721(name_, symbol_)
        Ownable(owner_ == address(0) ? msg.sender : owner_)
    {
        factory = factory_;
        _baseTokenURI = baseURI_;
        _nextTokenId = 1;
        emergencyMode = false;

        _setDefaultRoyalty(owner(), 500);
    }

    /**
     * @notice Toggles emergency mode - allows bypassing locks in critical situations
     * @dev Only callable by owner
     */
    function toggleEmergencyMode() external onlyOwner {
        emergencyMode = !emergencyMode;
        emit EmergencyModeToggled(emergencyMode);
    }

    /**
     * @notice Pauses all NFT operations
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses NFT operations
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Emergency unlock for a specific token in emergency mode
     * @param tokenId The token to unlock
     */
    function emergencyUnlock(uint256 tokenId) external {
        if (!emergencyMode) revert NotInEmergencyMode();

        address tokenOwner = _ownerOf(tokenId);
        if (tokenOwner == address(0)) revert NonexistentToken();
        if (msg.sender != tokenOwner && msg.sender != owner())
            revert NotApprovedOrOwner();

        _crateInfo[tokenId].lockedUntil = 0;
        emit EmergencyUnlock(tokenId, tokenOwner);
    }

    /**
     * @notice Improved buyCrate function with better validation and no duplicate token transfer
     * @dev This is called by the Factory which has already transferred tokens to treasury
     */
    function buyCrate(
        address paymentToken,
        uint256 paymentAmount,
        MintParams calldata params
    ) external nonReentrant whenNotPaused returns (uint256 tokenId) {
        if (msg.sender != factory) revert Unauthorized();
        if (params.account == address(0)) revert InvalidAccount();
        if (params.to == address(0)) revert InvalidRecipient();

        TokenInfo memory tokenInfo = supportedTokens[paymentToken];
        if (!tokenInfo.enabled) revert TokenNotSupported(paymentToken);
        if (paymentAmount == 0) revert InvalidTokenAmount();

        // Calculate USD value of payment (factory already validated this)
        uint256 paymentUsdValue = (paymentAmount * tokenInfo.priceUsd) /
            (10 ** tokenInfo.decimals);

        // Validate that payment covers the price
        if (paymentUsdValue < params.priceUsd)
            revert InsufficientTokenPayment();

        _validatePrice(params.priceUsd);
        _validateBoost(params.boostMultiplierBps);
        if (params.lockDuration > MAX_LOCK_DURATION)
            revert InvalidLockDuration();
        _validateFeeSet(
            params.revenueShareBps,
            params.platformFeeBps,
            params.performanceFeeBps
        );

        // NOTE: Token transfer is handled by Factory before this call
        // Factory transfers directly to treasury, so we don't transfer here

        tokenId = _nextTokenId;
        unchecked {
            ++_nextTokenId;
            ++_totalMinted;
        }

        uint64 lockedUntil = params.lockDuration == 0
            ? 0
            : uint64(block.timestamp + params.lockDuration);
        address crateCreator = params.creator == address(0)
            ? params.to
            : params.creator;
        uint64 lastLockAt = lockedUntil == 0 ? 0 : uint64(block.timestamp);
        uint64 lastBoostAt = params.boostActive ? uint64(block.timestamp) : 0;

        _safeMint(params.to, tokenId);
        _crateInfo[tokenId] = CrateInfo({
            riskLevel: params.riskLevel,
            strategyId: params.strategyId,
            account: params.account,
            mintedAt: uint64(block.timestamp),
            lockedUntil: lockedUntil,
            boostMultiplierBps: params.boostMultiplierBps,
            priceUsd: params.priceUsd,
            creator: crateCreator,
            revenueShareBps: params.revenueShareBps,
            platformFeeBps: params.platformFeeBps,
            performanceFeeBps: params.performanceFeeBps,
            riskDisclosure: params.riskDisclosure,
            feeDisclosure: params.feeDisclosure,
            lastRebalanceAt: params.lastRebalanceAt,
            nextHarvestAt: params.nextHarvestAt,
            accruedYieldUsd: params.accruedYieldUsd,
            boostActive: params.boostActive,
            lastBoostAt: lastBoostAt,
            lastLockAt: lastLockAt,
            paymentToken: paymentToken,
            paymentAmount: paymentAmount
        });

        _setPositions(tokenId, params.positions);

        emit CrateMinted(
            tokenId,
            params.to,
            params.riskLevel,
            params.strategyId,
            params.account,
            params.priceUsd,
            params.boostMultiplierBps,
            lockedUntil,
            paymentToken,
            paymentAmount
        );
    }

    /**
     * @notice Improved _update function with emergency mode support
     */
    function _update(
        address to,
        uint256 tokenId,
        address auth
    ) internal override returns (address) {
        address from = super._update(to, tokenId, auth);

        // Skip lock check if in emergency mode or if not a transfer
        if (from != address(0) && to != from && !emergencyMode) {
            CrateInfo memory info = _crateInfo[tokenId];
            if (info.lockedUntil != 0 && block.timestamp < info.lockedUntil) {
                revert TokenLocked(info.lockedUntil);
            }
        }

        return from;
    }

    /**
     * @notice Improved extendLock with better validation
     */
    function extendLock(uint256 tokenId, uint64 additionalDuration) external {
        _requireFactoryOrAuthorized(tokenId);

        // Prevent very short extensions that could be used to game the system
        if (additionalDuration < 1 days) revert InvalidLockDuration();
        if (additionalDuration > MAX_LOCK_DURATION)
            revert InvalidLockDuration();

        CrateInfo storage info = _crateInfo[tokenId];

        // Base time is either current lock expiry or current time
        uint64 base = info.lockedUntil > block.timestamp
            ? info.lockedUntil
            : uint64(block.timestamp);
        uint64 newLockedUntil = base + additionalDuration;

        // Total lock from now cannot exceed MAX_LOCK_DURATION
        if (newLockedUntil - uint64(block.timestamp) > MAX_LOCK_DURATION)
            revert InvalidLockDuration();

        info.lockedUntil = newLockedUntil;
        info.lastLockAt = uint64(block.timestamp);
        emit LockExtended(tokenId, newLockedUntil);
    }

    /**
     * @notice Set creator royalty for a specific token
     * @dev Allows creator to set their own royalty receiver
     */
    function setTokenRoyalty(
        uint256 tokenId,
        address receiver,
        uint96 feeNumerator
    ) external {
        address tokenOwner = _ownerOf(tokenId);
        if (tokenOwner == address(0)) revert NonexistentToken();

        address creator = _crateInfo[tokenId].creator;
        if (msg.sender != creator && msg.sender != owner())
            revert NotApprovedOrOwner();

        _setTokenRoyalty(tokenId, receiver, feeNumerator);
    }

    /**
     * @notice Improved _setPositions with better gas optimization
     */
    function _setPositions(
        uint256 tokenId,
        PositionPayload[] calldata positions
    ) internal {
        delete _positions[tokenId];

        uint256 totalBps;
        uint256 positionsLength = positions.length;

        for (uint256 i = 0; i < positionsLength; ) {
            PositionPayload calldata payload = positions[i];

            if (payload.allocationBps > MAX_BPS) revert InvalidBps();

            unchecked {
                totalBps += payload.allocationBps;
            }

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

            unchecked {
                ++i;
            }
        }

        // Allow partial allocation (totalBps <= MAX_BPS) or exact allocation
        if (totalBps > MAX_BPS) revert InvalidPositionTotalAllocation();

        emit PositionsUpdated(tokenId, positionsLength, msg.sender);
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

    function setDefaultRoyalty(
        address receiver,
        uint96 feeNumerator
    ) external onlyOwner {
        _setDefaultRoyalty(receiver, feeNumerator);
    }

    function deleteDefaultRoyalty() external onlyOwner {
        _deleteDefaultRoyalty();
    }

    function addSupportedToken(
        address token,
        uint256 priceUsd,
        uint8 decimals
    ) external onlyOwner {
        if (token == address(0)) revert InvalidTokenAddress();
        if (priceUsd == 0) revert InvalidTokenPrice();
        supportedTokens[token] = TokenInfo({
            enabled: true,
            priceUsd: priceUsd,
            decimals: decimals
        });
        whitelistedTokens.push(token);
        emit TokenAdded(token, priceUsd, decimals);
    }

    function removeSupportedToken(address token) external onlyOwner {
        supportedTokens[token].enabled = false;
        emit TokenRemoved(token);
    }

    function updateTokenPrice(
        address token,
        uint256 newPriceUsd
    ) external onlyOwner {
        if (!supportedTokens[token].enabled) revert TokenNotSupported(token);
        supportedTokens[token].priceUsd = newPriceUsd;
        emit TokenPriceUpdated(token, newPriceUsd);
    }

    function getSupportedToken(
        address token
    ) external view returns (TokenInfo memory) {
        return supportedTokens[token];
    }

    function getWhitelistedTokens() external view returns (address[] memory) {
        return whitelistedTokens;
    }

    function mintCrate(
        MintParams calldata params
    ) external returns (uint256 tokenId) {
        if (msg.sender != factory) revert Unauthorized();
        if (params.account == address(0)) revert InvalidAccount();
        if (params.to == address(0)) revert InvalidRecipient();
        _validatePrice(params.priceUsd);
        _validateBoost(params.boostMultiplierBps);
        if (params.lockDuration > MAX_LOCK_DURATION)
            revert InvalidLockDuration();
        _validateFeeSet(
            params.revenueShareBps,
            params.platformFeeBps,
            params.performanceFeeBps
        );

        tokenId = _nextTokenId;
        unchecked {
            ++_nextTokenId;
            ++_totalMinted;
        }

        uint64 lockedUntil = params.lockDuration == 0
            ? 0
            : uint64(block.timestamp + params.lockDuration);
        address crateCreator = params.creator == address(0)
            ? params.to
            : params.creator;
        uint64 lastLockAt = lockedUntil == 0 ? 0 : uint64(block.timestamp);
        uint64 lastBoostAt = params.boostActive ? uint64(block.timestamp) : 0;

        _safeMint(params.to, tokenId);
        _crateInfo[tokenId] = CrateInfo({
            riskLevel: params.riskLevel,
            strategyId: params.strategyId,
            account: params.account,
            mintedAt: uint64(block.timestamp),
            lockedUntil: lockedUntil,
            boostMultiplierBps: params.boostMultiplierBps,
            priceUsd: params.priceUsd,
            creator: crateCreator,
            revenueShareBps: params.revenueShareBps,
            platformFeeBps: params.platformFeeBps,
            performanceFeeBps: params.performanceFeeBps,
            riskDisclosure: params.riskDisclosure,
            feeDisclosure: params.feeDisclosure,
            lastRebalanceAt: params.lastRebalanceAt,
            nextHarvestAt: params.nextHarvestAt,
            accruedYieldUsd: params.accruedYieldUsd,
            boostActive: params.boostActive,
            lastBoostAt: lastBoostAt,
            lastLockAt: lastLockAt,
            paymentToken: address(0), // Will be set in buyCrate
            paymentAmount: 0 // Will be set in buyCrate
        });

        _setPositions(tokenId, params.positions);

        emit CrateMinted(
            tokenId,
            params.to,
            params.riskLevel,
            params.strategyId,
            params.account,
            params.priceUsd,
            params.boostMultiplierBps,
            lockedUntil,
            address(0), // No payment token for direct mint
            0 // No payment amount for direct mint
        );
    }


    function crateInfo(
        uint256 tokenId
    ) external view returns (CrateInfo memory) {
        if (_ownerOf(tokenId) == address(0)) revert NonexistentToken();
        return _crateInfo[tokenId];
    }

    function nextTokenId() external view returns (uint256) {
        return _nextTokenId;
    }

    function totalMinted() external view returns (uint256) {
        return _totalMinted;
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
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

    function setBoostMultiplier(
        uint256 tokenId,
        uint16 newBoostMultiplierBps
    ) external {
        _requireFactoryOrAuthorized(tokenId);
        _validateBoost(newBoostMultiplierBps);
        CrateInfo storage info = _crateInfo[tokenId];
        info.boostMultiplierBps = newBoostMultiplierBps;
        info.boostActive = true;
        info.lastBoostAt = uint64(block.timestamp);
        emit BoostUpdated(tokenId, newBoostMultiplierBps);
        emit BoostStatusUpdated(tokenId, true, newBoostMultiplierBps);
    }

    function setBoostStatus(
        uint256 tokenId,
        bool active,
        uint16 newBoostMultiplierBps
    ) external {
        _requireFactoryOrAuthorized(tokenId);
        _validateBoost(newBoostMultiplierBps);
        CrateInfo storage info = _crateInfo[tokenId];
        info.boostMultiplierBps = newBoostMultiplierBps;
        info.boostActive = active;
        info.lastBoostAt = uint64(block.timestamp);
        emit BoostStatusUpdated(tokenId, active, newBoostMultiplierBps);
        emit BoostUpdated(tokenId, newBoostMultiplierBps);
    }


    function updatePositions(
        uint256 tokenId,
        PositionPayload[] calldata positions
    ) external {
        _requireFactoryOrAuthorized(tokenId);
        _setPositions(tokenId, positions);
    }

    function getPositions(
        uint256 tokenId
    ) external view returns (PositionDetails[] memory) {
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

    function updateLifecycle(
        uint256 tokenId,
        uint64 lastRebalanceAt,
        uint64 nextHarvestAt,
        uint256 accruedYieldUsd
    ) external {
        _requireFactoryOrAuthorized(tokenId);
        CrateInfo storage info = _crateInfo[tokenId];
        info.lastRebalanceAt = lastRebalanceAt;
        info.nextHarvestAt = nextHarvestAt;
        info.accruedYieldUsd = accruedYieldUsd;
        emit LifecycleUpdated(
            tokenId,
            lastRebalanceAt,
            nextHarvestAt,
            accruedYieldUsd
        );
    }

    function updateRevenueShare(
        uint256 tokenId,
        uint16 revenueShareBps,
        uint16 platformFeeBps,
        uint16 performanceFeeBps
    ) external {
        _requireFactoryOrAuthorized(tokenId);
        _validateFeeSet(revenueShareBps, platformFeeBps, performanceFeeBps);
        CrateInfo storage info = _crateInfo[tokenId];
        info.revenueShareBps = revenueShareBps;
        info.platformFeeBps = platformFeeBps;
        info.performanceFeeBps = performanceFeeBps;
        emit RevenueShareUpdated(
            tokenId,
            revenueShareBps,
            platformFeeBps,
            performanceFeeBps
        );
    }

    function updateDisclosures(
        uint256 tokenId,
        string calldata riskDisclosure,
        string calldata feeDisclosure
    ) external {
        _requireFactoryOrAuthorized(tokenId);
        CrateInfo storage info = _crateInfo[tokenId];
        info.riskDisclosure = riskDisclosure;
        info.feeDisclosure = feeDisclosure;
        emit RiskDisclosureUpdated(tokenId, riskDisclosure);
        emit FeeDisclosureUpdated(tokenId, feeDisclosure);
    }

    function supportsInterface(
        bytes4 interfaceId
    ) public view override(ERC721, ERC2981) returns (bool) {
        return super.supportsInterface(interfaceId);
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
        if (!_isAuthorized(owner, msg.sender, tokenId))
            revert NotApprovedOrOwner();
    }

    function _validatePrice(uint256 priceUsd) internal pure {
        if (priceUsd < MIN_PRICE_USD || priceUsd > MAX_PRICE_USD)
            revert InvalidPrice();
    }

    function _validateBoost(uint16 boostMultiplierBps) internal pure {
        if (
            boostMultiplierBps < MIN_BOOST_BPS ||
            boostMultiplierBps > MAX_BOOST_BPS
        ) revert InvalidBoost();
    }

    function _validateFeeSet(
        uint16 revenueShareBps,
        uint16 platformFeeBps,
        uint16 performanceFeeBps
    ) internal pure {
        if (
            revenueShareBps > MAX_BPS ||
            platformFeeBps > MAX_BPS ||
            performanceFeeBps > MAX_BPS
        ) revert InvalidBps();
        if (
            uint256(revenueShareBps) + platformFeeBps + performanceFeeBps >
            MAX_BPS
        ) revert InvalidBps();
    }

}
