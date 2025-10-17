// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

contract OpenCrateStrategyRegistry is Ownable {
    uint8 public constant RISK_HIGH = 0;
    uint8 public constant RISK_MEDIUM = 1;
    uint8 public constant RISK_RANDOM = 2;

    error StrategyAdapterRequired();
    error StrategyUnsupportedRisk(uint8 risk);
    error StrategyMissing(uint256 strategyId);

    struct StrategyConfig {
        address adapter;
        bytes adapterData;
        uint8 riskLevel;
        bool active;
    }

    uint256 private _strategyCount;
    mapping(uint256 => StrategyConfig) private _strategies;
    mapping(uint8 => uint256[]) private _strategiesByRisk;

    event StrategyRegistered(uint256 indexed strategyId, address indexed adapter, uint8 riskLevel);
    event StrategyUpdated(uint256 indexed strategyId, address indexed adapter, uint8 riskLevel, bytes adapterData);
    event StrategyStatusUpdated(uint256 indexed strategyId, bool active);

    constructor(address owner_) Ownable(owner_ == address(0) ? msg.sender : owner_) {}

    function registerStrategy(address adapter, bytes calldata adapterData, uint8 riskLevel, bool active) external onlyOwner returns (uint256 strategyId) {
        if (adapter == address(0)) {
            revert StrategyAdapterRequired();
        }
        if (riskLevel > RISK_RANDOM) {
            revert StrategyUnsupportedRisk(riskLevel);
        }

        strategyId = ++_strategyCount;
        _strategies[strategyId] = StrategyConfig(adapter, adapterData, riskLevel, active);
        _strategiesByRisk[riskLevel].push(strategyId);

        emit StrategyRegistered(strategyId, adapter, riskLevel);
    }

    function updateStrategy(uint256 strategyId, address adapter, bytes calldata adapterData, uint8 riskLevel) external onlyOwner {
        StrategyConfig storage config = _strategies[strategyId];
        if (config.adapter == address(0)) {
            revert StrategyMissing(strategyId);
        }
        if (adapter == address(0)) {
            revert StrategyAdapterRequired();
        }
        if (riskLevel > RISK_RANDOM) {
            revert StrategyUnsupportedRisk(riskLevel);
        }

        config.adapter = adapter;
        config.adapterData = adapterData;
        config.riskLevel = riskLevel;

        emit StrategyUpdated(strategyId, adapter, riskLevel, adapterData);
    }

    function setStrategyStatus(uint256 strategyId, bool active) external onlyOwner {
        StrategyConfig storage config = _strategies[strategyId];
        if (config.adapter == address(0)) {
            revert StrategyMissing(strategyId);
        }

        config.active = active;

        emit StrategyStatusUpdated(strategyId, active);
    }

    function strategiesByRisk(uint8 riskLevel) external view returns (uint256[] memory) {
        return _strategiesByRisk[riskLevel];
    }

    function strategy(uint256 strategyId) external view returns (StrategyConfig memory) {
        return _strategies[strategyId];
    }

    function strategyCount() external view returns (uint256) {
        return _strategyCount;
    }
}
