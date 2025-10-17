// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IDeFiAdapter {
    error AdapterUnauthorized(address caller, address account);
    error AdapterZeroAmount();
    error AdapterNotRegistered();
    error AdapterInvalidData();

    struct Position {
        uint256 principal;
        uint256 pendingYield;
    }

    event Deposited(address indexed account, address indexed receiver, uint256 amount, bytes data);
    event Withdrawn(address indexed account, address indexed receiver, uint256 amount, bytes data);
    event YieldClaimed(address indexed account, address indexed receiver, uint256 amount, bytes data);

    function deposit(address account, uint256 amount, bytes calldata data) external returns (uint256 depositedAmount);

    function withdraw(address account, uint256 amount, bytes calldata data) external returns (uint256 withdrawnAmount);

    function claim(address account, bytes calldata data) external returns (uint256 claimedYield);

    function currentValue(address account) external view returns (uint256 totalValue);

    function position(address account) external view returns (Position memory info);
}
