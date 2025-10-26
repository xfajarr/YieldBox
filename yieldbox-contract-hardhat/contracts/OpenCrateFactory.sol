// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./OpenCrateNFT.sol";
import "./ERC6551Registry.sol";
import "./strategies/OpenCrateStrategyRegistry.sol";

/**
 * @title OpenCrateFactory
 * @dev Factory contract for creating yield crates with token payments and lockup system
 * @notice Supports multiple payment tokens and lockup duration with multipliers
 */
contract OpenCrateFactory is Ownable {
    
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
        uint256 basePriceUsd; // Base price before multiplier
        OpenCrateNFT.PositionPayload[] positions;
        uint16 revenueShareBps;
        uint16 platformFeeBps;
        uint16 performanceFeeBps;
        string riskDisclosure;
        string feeDisclosure;
        LockupOption[] lockupOptions;
        address[] supportedPaymentTokens;
    }
    
    struct CratePurchase {
        uint256 templateId;
        uint64 lockupDuration;
        uint16 selectedMultiplierBps;
        address paymentToken;
        uint256 paymentAmount;
        address purchaser;
        uint256 purchasedAt;
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

    event CratePurchased(
        uint256 indexed templateId,
        uint256 indexed tokenId,
        address indexed purchaser,
        address paymentToken,
        uint256 paymentAmount,
        uint64 lockupDuration,
        uint16 multiplierBps
    );
    event CrateTemplateCreated(uint256 indexed templateId, string name, uint256 basePriceUsd);
    event CrateTemplateUpdated(uint256 indexed templateId);
    event CrateTemplateDisabled(uint256 indexed templateId);
    event LockupOptionAdded(uint256 indexed templateId, uint64 duration, uint16 multiplierBps);
    event LockupOptionUpdated(uint256 indexed templateId, uint64 duration, uint16 multiplierBps);
    event LockupOptionRemoved(uint256 indexed templateId, uint64 duration, uint16 multiplierBps);

    OpenCrateNFT public immutable crateNFT;
    ERC6551Registry public immutable erc6551Registry;
    address public immutable erc6551AccountImplementation;
    OpenCrateStrategyRegistry public immutable strategyRegistry;
    
    uint256 private _nextTemplateId;
    mapping(uint256 => CrateTemplate) private _crateTemplates;
    mapping(uint256 => CratePurchase) private _cratePurchases;
    mapping(uint256 => mapping(uint64 => LockupOption)) private _lockupOptions; // templateId => duration => option
    uint256[] private _templateIds;

    constructor(
        address crateNFTAddress,
        address erc6551RegistryAddress,
        address erc6551AccountAddress,
        address strategyRegistryAddress,
        address initialOwner
    ) Ownable(initialOwner) {
        crateNFT = OpenCrateNFT(crateNFTAddress);
        erc6551Registry = ERC6551Registry(erc6551RegistryAddress);
        erc6551AccountImplementation = erc6551AccountAddress;
        strategyRegistry = OpenCrateStrategyRegistry(strategyRegistryAddress);
        _nextTemplateId = 1;
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
            supportedPaymentTokens: supportedPaymentTokens
        });

        // Add lockup options
        for (uint256 i = 0; i < lockupOptions.length; i++) {
            _lockupOptions[templateId][lockupOptions[i].duration] = lockupOptions[i];
        }

        _templateIds.push(templateId);
        emit CrateTemplateCreated(templateId, name, basePriceUsd);
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
        for (uint256 i = 0; i < existingOptions.length; i++) {
            delete _lockupOptions[templateId][existingOptions[i].duration];
        }

        template.name = name;
        template.description = description;

        // Replace positions
        delete template.positions;
        for (uint256 i = 0; i < positions.length; i++) {
            template.positions.push(positions[i]);
        }

        // Replace lockup options and rebuild mapping
        delete template.lockupOptions;
        for (uint256 i = 0; i < lockupOptions.length; i++) {
            LockupOption memory option = lockupOptions[i];
            template.lockupOptions.push(option);
            _lockupOptions[templateId][option.duration] = option;
        }

        // Replace supported payment tokens
        delete template.supportedPaymentTokens;
        for (uint256 i = 0; i < supportedPaymentTokens.length; i++) {
            template.supportedPaymentTokens.push(supportedPaymentTokens[i]);
        }

        emit CrateTemplateUpdated(templateId);
    }

    function addLockupOption(
        uint256 templateId,
        uint64 duration,
        uint16 multiplierBps
    ) external onlyOwner {
        if (_crateTemplates[templateId].basePriceUsd == 0) revert TemplateNotFound();
        if (multiplierBps < 10000 || multiplierBps > 20000) revert InvalidMultiplier(); // 1.0x to 2.0x

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
        if (multiplierBps < 10000 || multiplierBps > 20000) revert InvalidMultiplier(); // 1.0x to 2.0x

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
        for (uint256 i = 0; i < options.length; i++) {
            if (options[i].duration == duration) {
                options[i].enabled = false;
                break;
            }
        }

        emit LockupOptionRemoved(templateId, duration, option.multiplierBps);
    }

    function disableCrateTemplate(uint256 templateId) external onlyOwner {
        if (_crateTemplates[templateId].basePriceUsd == 0) revert TemplateNotFound();
        // Disable all lockup options
        LockupOption[] storage options = _crateTemplates[templateId].lockupOptions;
        for (uint256 i = 0; i < options.length; i++) {
            options[i].enabled = false;
        }
        emit CrateTemplateDisabled(templateId);
    }

    function purchaseCrate(
        uint256 templateId,
        uint64 lockupDuration,
        address paymentToken,
        uint256 paymentAmount
    ) external returns (uint256 tokenId) {
        CrateTemplate memory template = _crateTemplates[templateId];
        if (template.basePriceUsd == 0) revert TemplateNotFound();

        LockupOption memory lockupOption = _lockupOptions[templateId][lockupDuration];
        if (!lockupOption.enabled) revert InvalidLockupOption();

        // Check if payment token is supported
        bool tokenSupported = false;
        for (uint256 i = 0; i < template.supportedPaymentTokens.length; i++) {
            if (template.supportedPaymentTokens[i] == paymentToken) {
                tokenSupported = true;
                break;
            }
        }
        if (!tokenSupported) revert TokenNotSupported(paymentToken);

        // Calculate required payment amount
        uint256 requiredPayment = (template.basePriceUsd * lockupOption.multiplierBps) / 10000;
        if (paymentAmount < requiredPayment) revert InsufficientPayment();

        // Create ERC6551 account for the crate
        uint256 accountSalt = uint256(keccak256(abi.encodePacked(templateId, msg.sender, block.timestamp)));
        address account = erc6551Registry.createAccount(
            erc6551AccountImplementation,
            block.chainid,
            address(crateNFT),
            crateNFT.nextTokenId(), // Predict the upcoming token ID
            accountSalt,
            new bytes(0)
        );

        // Calculate final price with multiplier
        uint256 finalPriceUsd = (template.basePriceUsd * lockupOption.multiplierBps) / 10000;

        // Mint the crate
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
                positions: template.positions
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
            purchasedAt: uint64(block.timestamp)
        });

        emit CratePurchased(
            templateId,
            tokenId,
            msg.sender,
            paymentToken,
            paymentAmount,
            lockupDuration,
            lockupOption.multiplierBps
        );
    }

    function getCrateTemplate(uint256 templateId) external view returns (CrateTemplate memory) {
        return _crateTemplates[templateId];
    }

    function getLockupOption(uint256 templateId, uint64 duration) external view returns (LockupOption memory) {
        return _lockupOptions[templateId][duration];
    }

    function getLockupOptions(uint256 templateId) external view returns (LockupOption[] memory) {
        CrateTemplate memory template = _crateTemplates[templateId];
        LockupOption[] memory options = new LockupOption[](template.lockupOptions.length);
        
        for (uint256 i = 0; i < template.lockupOptions.length; i++) {
            options[i] = template.lockupOptions[i];
        }
        
        return options;
    }

    function getTemplateIds() external view returns (uint256[] memory) {
        return _templateIds;
    }

    function getActiveTemplateIds() external view returns (uint256[] memory) {
        uint256 activeCount = 0;
        for (uint256 i = 0; i < _templateIds.length; i++) {
            if (_crateTemplates[_templateIds[i]].basePriceUsd > 0) {
                activeCount++;
            }
        }
        
        uint256[] memory activeIds = new uint256[](activeCount);
        uint256 index = 0;
        for (uint256 i = 0; i < _templateIds.length; i++) {
            if (_crateTemplates[_templateIds[i]].basePriceUsd > 0) {
                activeIds[index] = _templateIds[i];
                index++;
            }
        }
        
        return activeIds;
    }

    function getCratePurchase(uint256 tokenId) external view returns (CratePurchase memory) {
        return _cratePurchases[tokenId];
    }

    function calculatePurchasePrice(
        uint256 templateId,
        uint64 lockupDuration
    ) external view returns (uint256 priceUsd, uint16 multiplierBps) {
        CrateTemplate memory template = _crateTemplates[templateId];
        if (template.basePriceUsd == 0) revert TemplateNotFound();

        LockupOption memory lockupOption = _lockupOptions[templateId][lockupDuration];
        if (!lockupOption.enabled) revert InvalidLockupOption();

        priceUsd = (template.basePriceUsd * lockupOption.multiplierBps) / 10000;
        multiplierBps = lockupOption.multiplierBps;

        return (priceUsd, multiplierBps);
    }

    function nextTemplateId() external view returns (uint256) {
        return _nextTemplateId;
    }

    function totalTemplates() external view returns (uint256) {
        return _templateIds.length;
    }

    function emergencyWithdrawToken(address token, uint256 amount) external onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }

    function emergencyPauseTemplate(uint256 templateId) external onlyOwner {
        // Disable all lockup options for a template
        LockupOption[] storage options = _crateTemplates[templateId].lockupOptions;
        for (uint256 i = 0; i < options.length; i++) {
            options[i].enabled = false;
        }
    }

    function emergencyUnpauseTemplate(uint256 templateId) external onlyOwner {
        // Re-enable all lockup options for a template
        LockupOption[] storage options = _crateTemplates[templateId].lockupOptions;
        for (uint256 i = 0; i < options.length; i++) {
            options[i].enabled = true;
        }
    }
}
