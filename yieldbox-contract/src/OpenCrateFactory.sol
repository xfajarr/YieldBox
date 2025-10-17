// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./OpenCrateNFT.sol";
import "./strategies/OpenCrateStrategyRegistry.sol";
import "./interfaces/IERC6551Registry.sol";

contract OpenCrateFactory is Ownable {
    struct MintParams {
        address to;
        uint8 riskLevel;
        uint256 strategyId;
        uint256 salt;
        uint256 priceUsd;
        uint16 boostMultiplierBps;
        uint64 lockDuration;
        bytes accountInitData;
        bytes adapterData;
    }

    struct CrateDeployment {
        uint256 strategyId;
        uint8 riskLevel;
        uint256 salt;
        address account;
        address adapter;
        bytes adapterData;
        uint256 priceUsd;
        uint16 boostMultiplierBps;
        uint64 lockedUntil;
    }

    error ZeroAddress();
    error StrategyNotFound(uint256 strategyId);
    error StrategyInactive(uint256 strategyId);
    error StrategyRiskMismatch(uint8 expected, uint8 provided);
    error AccountCreationFailed();
    error CrateUnknown(uint256 tokenId);

    event CrateCreated(
        uint256 indexed tokenId,
        address indexed owner,
        address indexed account,
        uint256 strategyId,
        uint8 riskLevel,
        address adapter,
        uint256 priceUsd,
        uint16 boostMultiplierBps,
        uint64 lockedUntil
    );
    event StrategyRegistryUpdated(address indexed newRegistry);
    event AccountImplementationUpdated(address indexed newImplementation);

    OpenCrateNFT public immutable crateNFT;
    IERC6551Registry public immutable registry;
    address public accountImplementation;
    OpenCrateStrategyRegistry public strategyRegistry;

    mapping(uint256 => CrateDeployment) private _crateDeployments;

    constructor(
        OpenCrateNFT crateNFT_,
        IERC6551Registry registry_,
        address accountImplementation_,
        OpenCrateStrategyRegistry strategyRegistry_,
        address owner_
    ) Ownable(owner_ == address(0) ? msg.sender : owner_) {
        if (address(crateNFT_) == address(0)) revert ZeroAddress();
        if (address(registry_) == address(0)) revert ZeroAddress();
        if (accountImplementation_ == address(0)) revert ZeroAddress();
        if (address(strategyRegistry_) == address(0)) revert ZeroAddress();

        crateNFT = crateNFT_;
        registry = registry_;
        accountImplementation = accountImplementation_;
        strategyRegistry = strategyRegistry_;
    }

    function setStrategyRegistry(OpenCrateStrategyRegistry newRegistry) external onlyOwner {
        if (address(newRegistry) == address(0)) revert ZeroAddress();
        strategyRegistry = newRegistry;
        emit StrategyRegistryUpdated(address(newRegistry));
    }

    function setAccountImplementation(address newImplementation) external onlyOwner {
        if (newImplementation == address(0)) revert ZeroAddress();
        accountImplementation = newImplementation;
        emit AccountImplementationUpdated(newImplementation);
    }

    function mintCrate(MintParams calldata params) external returns (uint256 tokenId, address account) {
        address recipient = params.to == address(0) ? msg.sender : params.to;

        OpenCrateStrategyRegistry.StrategyConfig memory config = strategyRegistry.strategy(params.strategyId);
        if (config.adapter == address(0)) revert StrategyNotFound(params.strategyId);
        if (!config.active) revert StrategyInactive(params.strategyId);
        if (config.riskLevel != params.riskLevel) {
            revert StrategyRiskMismatch(config.riskLevel, params.riskLevel);
        }

        uint256 tokenIdToMint = crateNFT.nextTokenId();
        account = registry.createAccount(
            accountImplementation,
            block.chainid,
            address(crateNFT),
            tokenIdToMint,
            params.salt,
            params.accountInitData
        );

        if (account == address(0)) revert AccountCreationFailed();

        bytes memory adapterDataToUse = params.adapterData.length != 0 ? params.adapterData : config.adapterData;

        tokenId = crateNFT.mintCrate(
            recipient,
            params.riskLevel,
            params.strategyId,
            account,
            params.priceUsd,
            params.boostMultiplierBps,
            params.lockDuration
        );

        OpenCrateNFT.CrateInfo memory mintedInfo = crateNFT.crateInfo(tokenId);

        _crateDeployments[tokenId] = CrateDeployment({
            strategyId: params.strategyId,
            riskLevel: params.riskLevel,
            salt: params.salt,
            account: account,
            adapter: config.adapter,
            adapterData: adapterDataToUse,
            priceUsd: mintedInfo.priceUsd,
            boostMultiplierBps: mintedInfo.boostMultiplierBps,
            lockedUntil: mintedInfo.lockedUntil
        });

        emit CrateCreated(
            tokenId,
            recipient,
            account,
            params.strategyId,
            params.riskLevel,
            config.adapter,
            mintedInfo.priceUsd,
            mintedInfo.boostMultiplierBps,
            mintedInfo.lockedUntil
        );
    }

    function crateDeployment(uint256 tokenId) external view returns (CrateDeployment memory) {
        CrateDeployment memory deployment = _crateDeployments[tokenId];
        if (deployment.account == address(0)) revert CrateUnknown(tokenId);
        return deployment;
    }

    function crateAdapter(uint256 tokenId) external view returns (address adapter, bytes memory adapterData) {
        CrateDeployment memory deployment = _crateDeployments[tokenId];
        if (deployment.account == address(0)) revert CrateUnknown(tokenId);
        adapter = deployment.adapter;
        adapterData = deployment.adapterData;
    }

    function accountOf(uint256 tokenId) external view returns (address) {
        CrateDeployment memory deployment = _crateDeployments[tokenId];
        if (deployment.account == address(0)) revert CrateUnknown(tokenId);
        return deployment.account;
    }

    function predictAccount(uint256 tokenId, uint256 salt) external view returns (address) {
        return registry.account(accountImplementation, block.chainid, address(crateNFT), tokenId, salt);
    }

    function predictAccountForNext(uint256 salt) external view returns (address) {
        return registry.account(accountImplementation, block.chainid, address(crateNFT), crateNFT.nextTokenId(), salt);
    }
}
