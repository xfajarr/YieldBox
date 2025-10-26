// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./OpenCrateNFT.sol";
import "./ERC6551Registry.sol";
import "./strategies/OpenCrateStrategyRegistry.sol";

/**
 * @title OpenCrateFactory
 * @dev Factory contract for creating yield crates with token payments and lockup system
 * @notice Supports multiple payment tokens and lockup duration with multipliers
 */
contract OpenCrateFactory is Ownable, ReentrancyGuard, Pausable {
    using SafeERC20 for IERC20;
    
    // Constants
    uint256 private constant BPS_DIVISOR = 10_000;
    uint16 private constant MIN_MULTIPLIER_BPS = 10_000; // 1.0x
    uint16 private constant MAX_MULTIPLIER_BPS = 20_000; // 2.0x
    uint256 private constant MAX_SLIPPAGE_BPS = 500; // 5% max slippage
    
    struct LockupOption {
        uint64 duration; // Lockup duration in seconds
        uint16 multiplierBps; // Multiplier in basis points (10000 = 1.0x)
        bool enabled;
    }
    
    struct CrateTemplate {
        string name;
        string description;
        uint8 riskLevel;
        uint256 strategyId;
        uint256 basePriceUsd; // Base price before multiplier (2 decimals)
        OpenCrateNFT.PositionPayload[] positions;
        uint16 revenueShareBps;
        uint16 platformFeeBps;
        uint16 performanceFeeBps;
        string riskDisclosure;
        string feeDisclosure;
        LockupOption[] lockupOptions;
        address[] supportedPaymentTokens;
        uint256 version; // Template version for tracking updates
    }
    
    struct CratePurchase {
        uint256 templateId;
        uint64 lockupDuration;
        uint16 selectedMultiplierBps;
        address paymentToken;
        uint256 paymentAmount;
        address purchaser;
        uint64 purchasedAt;
        uint256 templateVersion;
    }

    error Unauthorized();
    error InvalidTemplate();
    error InvalidLockupOption();
    error TokenNotSupported(address token);
    error InsufficientPayment();
    error InvalidPurchaseAmount();
    error TemplateNotFound();
    error InvalidMultiplier();
    error TemplateNameRequired();
    error TemplateDescriptionRequired();
    error TemplateLockupRequired();
    error TemplatePaymentTokenRequired();
    error SlippageExceeded();
    error PaymentTransferFailed();
    error AccountCreationFailed();
    error ZeroAddress();

    event CratePurchased(
        uint256 indexed templateId,
        uint256 indexed tokenId,
        address indexed purchaser,
        address paymentToken,
        uint256 paymentAmount,
        uint64 lockupDuration,
        uint16 multiplierBps,
        uint256 timestamp
    );
    event CrateTemplateCreated(uint256 indexed templateId, string name, uint256 basePriceUsd, uint256 version);
    event CrateTemplateUpdated(uint256 indexed templateId, uint256 newVersion);
    event CrateTemplateDisabled(uint256 indexed templateId);
    event LockupOptionAdded(uint256 indexed templateId, uint64 duration, uint16 multiplierBps);
    event LockupOptionUpdated(uint256 indexed templateId, uint64 duration, uint16 multiplierBps);
    event LockupOptionRemoved(uint256 indexed templateId, uint64 duration, uint16 multiplierBps);
    event TreasuryUpdated(address indexed oldTreasury, address indexed newTreasury);
    event EmergencyWithdraw(address indexed token, uint256 amount, address indexed recipient);

    OpenCrateNFT public immutable crateNFT;
    ERC6551Registry public immutable erc6551Registry;
    address public immutable erc6551AccountImplementation;
    OpenCrateStrategyRegistry public immutable strategyRegistry;
    
    address public treasury;
    
    uint256 private _nextTemplateId;
    mapping(uint256 => CrateTemplate) private _crateTemplates;
    mapping(uint256 => CratePurchase) private _cratePurchases;
    mapping(uint256 => mapping(uint64 => LockupOption)) private _lockupOptions;
    uint256[] private _templateIds;

    constructor(
        address crateNFTAddress,
        address erc6551RegistryAddress,
        address erc6551AccountAddress,
        address strategyRegistryAddress,
        address treasuryAddress,
        address initialOwner
    ) Ownable(initialOwner) {
        if (crateNFTAddress == address(0)) revert ZeroAddress();
        if (erc6551RegistryAddress == address(0)) revert ZeroAddress();
        if (erc6551AccountAddress == address(0)) revert ZeroAddress();
        if (strategyRegistryAddress == address(0)) revert ZeroAddress();
        if (treasuryAddress == address(0)) revert ZeroAddress();
        
        crateNFT = OpenCrateNFT(crateNFTAddress);
        erc6551Registry = ERC6551Registry(erc6551RegistryAddress);
        erc6551AccountImplementation = erc6551AccountAddress;
        strategyRegistry = OpenCrateStrategyRegistry(strategyRegistryAddress);
        treasury = treasuryAddress;
        _nextTemplateId = 1;
    }

    /**
     * @notice Updates the treasury address
     * @param newTreasury The new treasury address
     */
    function setTreasury(address newTreasury) external onlyOwner {
        if (newTreasury == address(0)) revert ZeroAddress();
        address oldTreasury = treasury;
        treasury = newTreasury;
        emit TreasuryUpdated(oldTreasury, newTreasury);
    }

    /**
     * @notice Pauses all crate purchases
     */
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @notice Unpauses crate purchases
     */
    function unpause() external onlyOwner {
        _unpause();
    }

    function createCrateTemplate(
        string memory name,
        string memory description,
        uint8 riskLevel,
        uint256 strategyId,
        uint256 basePriceUsd,
        OpenCrateNFT.PositionPayload[] calldata positions,
        uint16 revenueShareBps,
        uint16 platformFeeBps,
        uint16 performanceFeeBps,
        string calldata riskDisclosure,
        string calldata feeDisclosure,
        LockupOption[] calldata lockupOptions,
        address[] calldata supportedPaymentTokens
    ) external onlyOwner returns (uint256 templateId) {
        if (bytes(name).length == 0) revert TemplateNameRequired();
        if (bytes(description).length == 0) revert TemplateDescriptionRequired();
        if (lockupOptions.length == 0) revert TemplateLockupRequired();
        if (supportedPaymentTokens.length == 0) revert TemplatePaymentTokenRequired();

        templateId = _nextTemplateId;
        unchecked {
            ++_nextTemplateId;
        }

        _crateTemplates[templateId] = CrateTemplate({
            name: name,
            description: description,
            riskLevel: riskLevel,
            strategyId: strategyId,
            basePriceUsd: basePriceUsd,
            positions: positions,
            revenueShareBps: revenueShareBps,
            platformFeeBps: platformFeeBps,
            performanceFeeBps: performanceFeeBps,
            riskDisclosure: riskDisclosure,
            feeDisclosure: feeDisclosure,
            lockupOptions: lockupOptions,
            supportedPaymentTokens: supportedPaymentTokens,
            version: 1
        });

        uint256 lockupLength = lockupOptions.length;
        for (uint256 i = 0; i < lockupLength;) {
            _lockupOptions[templateId][lockupOptions[i].duration] = lockupOptions[i];
            unchecked { ++i; }
        }

        _templateIds.push(templateId);
        emit CrateTemplateCreated(templateId, name, basePriceUsd, 1);
    }

    function updateCrateTemplate(
        uint256 templateId,
        string memory name,
        string memory description,
        OpenCrateNFT.PositionPayload[] calldata positions,
        LockupOption[] calldata lockupOptions,
        address[] calldata supportedPaymentTokens
    ) external onlyOwner {
        if (_crateTemplates[templateId].basePriceUsd == 0) revert TemplateNotFound();
        if (bytes(name).length == 0) revert TemplateNameRequired();
        if (bytes(description).length == 0) revert TemplateDescriptionRequired();
        if (lockupOptions.length == 0) revert TemplateLockupRequired();

        CrateTemplate storage template = _crateTemplates[templateId];

        // Clear existing lockup option mapping entries
        LockupOption[] storage existingOptions = template.lockupOptions;
        uint256 existingLength = existingOptions.length;
        for (uint256 i = 0; i < existingLength;) {
            delete _lockupOptions[templateId][existingOptions[i].duration];
            unchecked { ++i; }
        }

        template.name = name;
        template.description = description;
        template.version++;

        // Replace positions
        delete template.positions;
        uint256 positionsLength = positions.length;
        for (uint256 i = 0; i < positionsLength;) {
            template.positions.push(positions[i]);
            unchecked { ++i; }
        }

        // Replace lockup options and rebuild mapping
        delete template.lockupOptions;
        uint256 lockupLength = lockupOptions.length;
        for (uint256 i = 0; i < lockupLength;) {
            LockupOption memory option = lockupOptions[i];
            template.lockupOptions.push(option);
            _lockupOptions[templateId][option.duration] = option;
            unchecked { ++i; }
        }

        // Replace supported payment tokens
        delete template.supportedPaymentTokens;
        uint256 tokensLength = supportedPaymentTokens.length;
        for (uint256 i = 0; i < tokensLength;) {
            template.supportedPaymentTokens.push(supportedPaymentTokens[i]);
            unchecked { ++i; }
        }

        emit CrateTemplateUpdated(templateId, template.version);
    }

    function addLockupOption(
        uint256 templateId,
        uint64 duration,
        uint16 multiplierBps
    ) external onlyOwner {
        if (_crateTemplates[templateId].basePriceUsd == 0) revert TemplateNotFound();
        if (multiplierBps < MIN_MULTIPLIER_BPS || multiplierBps > MAX_MULTIPLIER_BPS) revert InvalidMultiplier();

        _lockupOptions[templateId][duration] = LockupOption({
            duration: duration,
            multiplierBps: multiplierBps,
            enabled: true
        });

        emit LockupOptionAdded(templateId, duration, multiplierBps);
    }

    function updateLockupOption(
        uint256 templateId,
        uint64 duration,
        uint16 multiplierBps
    ) external onlyOwner {
        if (_crateTemplates[templateId].basePriceUsd == 0) revert TemplateNotFound();
        if (multiplierBps < MIN_MULTIPLIER_BPS || multiplierBps > MAX_MULTIPLIER_BPS) revert InvalidMultiplier();

        _lockupOptions[templateId][duration].multiplierBps = multiplierBps;
        _lockupOptions[templateId][duration].enabled = true;

        emit LockupOptionUpdated(templateId, duration, multiplierBps);
    }

    function removeLockupOption(
        uint256 templateId,
        uint64 duration
    ) external onlyOwner {
        if (_crateTemplates[templateId].basePriceUsd == 0) revert TemplateNotFound();

        LockupOption storage option = _lockupOptions[templateId][duration];
        option.enabled = false;

        LockupOption[] storage options = _crateTemplates[templateId].lockupOptions;
        uint256 optionsLength = options.length;
        for (uint256 i = 0; i < optionsLength;) {
            if (options[i].duration == duration) {
                options[i].enabled = false;
                break;
            }
            unchecked { ++i; }
        }

        emit LockupOptionRemoved(templateId, duration, option.multiplierBps);
    }

    function disableCrateTemplate(uint256 templateId) external onlyOwner {
        if (_crateTemplates[templateId].basePriceUsd == 0) revert TemplateNotFound();
        LockupOption[] storage options = _crateTemplates[templateId].lockupOptions;
        uint256 optionsLength = options.length;
        for (uint256 i = 0; i < optionsLength;) {
            options[i].enabled = false;
            unchecked { ++i; }
        }
        emit CrateTemplateDisabled(templateId);
    }

    /**
     * @notice Purchases a crate using a template with slippage protection
     * @param templateId The ID of the template to use
     * @param lockupDuration The lockup duration to apply
     * @param paymentToken The ERC20 token to pay with
     * @param paymentAmount The amount of tokens to pay
     * @param maxPaymentAmount Maximum amount willing to pay (slippage protection)
     * @return tokenId The ID of the newly minted NFT
     */
    function purchaseCrate(
        uint256 templateId,
        uint64 lockupDuration,
        address paymentToken,
        uint256 paymentAmount,
        uint256 maxPaymentAmount
    ) external nonReentrant whenNotPaused returns (uint256 tokenId) {
        // Load template from storage
        CrateTemplate storage template = _crateTemplates[templateId];
        if (template.basePriceUsd == 0) revert TemplateNotFound();

        // Validate lockup option
        LockupOption memory lockupOption = _lockupOptions[templateId][lockupDuration];
        if (!lockupOption.enabled) revert InvalidLockupOption();

        // Check if payment token is supported
        bool tokenSupported = false;
        uint256 tokensLength = template.supportedPaymentTokens.length;
        for (uint256 i = 0; i < tokensLength;) {
            if (template.supportedPaymentTokens[i] == paymentToken) {
                tokenSupported = true;
                break;
            }
            unchecked { ++i; }
        }
        if (!tokenSupported) revert TokenNotSupported(paymentToken);

        // Calculate required payment amount with multiplier
        uint256 finalPriceUsd = (template.basePriceUsd * lockupOption.multiplierBps) / BPS_DIVISOR;
        
        // Get token info from NFT contract
        OpenCrateNFT.TokenInfo memory tokenInfo = crateNFT.getSupportedToken(paymentToken);
        if (!tokenInfo.enabled) revert TokenNotSupported(paymentToken);
        
        // Calculate required token amount
        uint256 requiredTokenAmount = (finalPriceUsd * (10 ** tokenInfo.decimals)) / tokenInfo.priceUsd;
        
        // Validate payment amount
        if (paymentAmount < requiredTokenAmount) revert InsufficientPayment();
        
        // Slippage protection
        if (paymentAmount > maxPaymentAmount) revert SlippageExceeded();
        
        // Additional safety: check slippage is reasonable
        uint256 slippageBps = ((paymentAmount - requiredTokenAmount) * BPS_DIVISOR) / requiredTokenAmount;
        if (slippageBps > MAX_SLIPPAGE_BPS) revert SlippageExceeded();

        // Transfer payment tokens from user to treasury
        IERC20(paymentToken).safeTransferFrom(msg.sender, treasury, paymentAmount);

        // Predict next token ID
        uint256 nextTokenId = crateNFT.nextTokenId();

        // Create ERC6551 account for the crate
        uint256 accountSalt = uint256(keccak256(abi.encodePacked(templateId, msg.sender, block.timestamp, nextTokenId)));
        
        address account = erc6551Registry.account(
            erc6551AccountImplementation,
            block.chainid,
            address(crateNFT),
            nextTokenId,
            accountSalt
        );

        // Check if account already exists, if not create it
        if (account.code.length == 0) {
            account = erc6551Registry.createAccount(
                erc6551AccountImplementation,
                block.chainid,
                address(crateNFT),
                nextTokenId,
                accountSalt,
                new bytes(0)
            );
        }

        if (account == address(0)) revert AccountCreationFailed();

        // Prepare positions array
        OpenCrateNFT.PositionPayload[] memory positions = new OpenCrateNFT.PositionPayload[](template.positions.length);
        uint256 positionsLength = template.positions.length;
        for (uint256 i = 0; i < positionsLength;) {
            positions[i] = template.positions[i];
            unchecked { ++i; }
        }

        // Mint the crate via NFT contract
        tokenId = crateNFT.buyCrate(
            paymentToken,
            paymentAmount,
            OpenCrateNFT.MintParams({
                to: msg.sender,
                riskLevel: template.riskLevel,
                strategyId: template.strategyId,
                account: account,
                priceUsd: finalPriceUsd,
                boostMultiplierBps: lockupOption.multiplierBps,
                lockDuration: lockupDuration,
                creator: msg.sender,
                revenueShareBps: template.revenueShareBps,
                platformFeeBps: template.platformFeeBps,
                performanceFeeBps: template.performanceFeeBps,
                riskDisclosure: template.riskDisclosure,
                feeDisclosure: template.feeDisclosure,
                lastRebalanceAt: uint64(block.timestamp),
                nextHarvestAt: uint64(block.timestamp + 30 days),
                accruedYieldUsd: 0,
                boostActive: true,
                positions: positions
            })
        );

        // Record purchase
        _cratePurchases[tokenId] = CratePurchase({
            templateId: templateId,
            lockupDuration: lockupDuration,
            selectedMultiplierBps: lockupOption.multiplierBps,
            paymentToken: paymentToken,
            paymentAmount: paymentAmount,
            purchaser: msg.sender,
            purchasedAt: uint64(block.timestamp),
            templateVersion: template.version
        });

        emit CratePurchased(
            templateId,
            tokenId,
            msg.sender,
            paymentToken,
            paymentAmount,
            lockupDuration,
            lockupOption.multiplierBps,
            block.timestamp
        );
    }

    function getCrateTemplate(uint256 templateId) external view returns (CrateTemplate memory) {
        return _crateTemplates[templateId];
    }

    function getLockupOption(uint256 templateId, uint64 duration) external view returns (LockupOption memory) {
        return _lockupOptions[templateId][duration];
    }

    function getLockupOptions(uint256 templateId) external view returns (LockupOption[] memory) {
        CrateTemplate storage template = _crateTemplates[templateId];
        LockupOption[] memory options = new LockupOption[](template.lockupOptions.length);
        
        uint256 optionsLength = template.lockupOptions.length;
        for (uint256 i = 0; i < optionsLength;) {
            options[i] = template.lockupOptions[i];
            unchecked { ++i; }
        }
        
        return options;
    }

    function getTemplateIds() external view returns (uint256[] memory) {
        return _templateIds;
    }

    function getActiveTemplateIds() external view returns (uint256[] memory) {
        uint256 activeCount = 0;
        uint256 idsLength = _templateIds.length;
        
        for (uint256 i = 0; i < idsLength;) {
            if (_crateTemplates[_templateIds[i]].basePriceUsd > 0) {
                unchecked { ++activeCount; }
            }
            unchecked { ++i; }
        }
        
        uint256[] memory activeIds = new uint256[](activeCount);
        uint256 index = 0;
        
        for (uint256 i = 0; i < idsLength;) {
            if (_crateTemplates[_templateIds[i]].basePriceUsd > 0) {
                activeIds[index] = _templateIds[i];
                unchecked { ++index; }
            }
            unchecked { ++i; }
        }
        
        return activeIds;
    }

    function getCratePurchase(uint256 tokenId) external view returns (CratePurchase memory) {
        return _cratePurchases[tokenId];
    }

    function calculatePurchasePrice(
        uint256 templateId,
        uint64 lockupDuration
    ) external view returns (uint256 priceUsd, uint16 multiplierBps, uint256[] memory requiredTokenAmounts) {
        CrateTemplate storage template = _crateTemplates[templateId];
        if (template.basePriceUsd == 0) revert TemplateNotFound();

        LockupOption memory lockupOption = _lockupOptions[templateId][lockupDuration];
        if (!lockupOption.enabled) revert InvalidLockupOption();

        priceUsd = (template.basePriceUsd * lockupOption.multiplierBps) / BPS_DIVISOR;
        multiplierBps = lockupOption.multiplierBps;

        // Calculate required amounts for all supported tokens
        uint256 tokensLength = template.supportedPaymentTokens.length;
        requiredTokenAmounts = new uint256[](tokensLength);
        
        for (uint256 i = 0; i < tokensLength;) {
            address token = template.supportedPaymentTokens[i];
            OpenCrateNFT.TokenInfo memory tokenInfo = crateNFT.getSupportedToken(token);
            
            if (tokenInfo.enabled) {
                requiredTokenAmounts[i] = (priceUsd * (10 ** tokenInfo.decimals)) / tokenInfo.priceUsd;
            }
            unchecked { ++i; }
        }

        return (priceUsd, multiplierBps, requiredTokenAmounts);
    }

    function nextTemplateId() external view returns (uint256) {
        return _nextTemplateId;
    }

    function totalTemplates() external view returns (uint256) {
        return _templateIds.length;
    }

    /**
     * @notice Emergency function to withdraw tokens from the contract
     * @dev Only callable by owner in case of emergency
     */
    function emergencyWithdrawToken(address token, uint256 amount, address recipient) external onlyOwner {
        if (recipient == address(0)) revert ZeroAddress();
        IERC20(token).safeTransfer(recipient, amount);
        emit EmergencyWithdraw(token, amount, recipient);
    }

    function emergencyPauseTemplate(uint256 templateId) external onlyOwner {
        LockupOption[] storage options = _crateTemplates[templateId].lockupOptions;
        uint256 optionsLength = options.length;
        for (uint256 i = 0; i < optionsLength;) {
            options[i].enabled = false;
            unchecked { ++i; }
        }
    }

    function emergencyUnpauseTemplate(uint256 templateId) external onlyOwner {
        LockupOption[] storage options = _crateTemplates[templateId].lockupOptions;
        uint256 optionsLength = options.length;
        for (uint256 i = 0; i < optionsLength;) {
            options[i].enabled = true;
            unchecked { ++i; }
        }
    }
}