// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import "@openzeppelin/contracts/access/Ownable.sol";
import "../interfaces/IDeFiAdapter.sol";
import "../mock/MockYieldProtocol.sol";

contract MockYieldAdapter is IDeFiAdapter, Ownable {
    MockYieldProtocol public immutable protocol;

    error InvalidProtocolAddress();

    constructor(MockYieldProtocol protocol_, address owner_) Ownable(owner_ == address(0) ? msg.sender : owner_) {
        if (address(protocol_) == address(0)) {
            revert InvalidProtocolAddress();
        }
        protocol = protocol_;
    }

    modifier onlyAuthorized(address account) {
        if (msg.sender != account && msg.sender != owner()) {
            revert AdapterUnauthorized(msg.sender, account);
        }
        _;
    }

    function deposit(address account, uint256 amount, bytes calldata data) external override onlyAuthorized(account) returns (uint256) {
        if (amount == 0) {
            revert AdapterZeroAmount();
        }
        _ensureRegistered();

        address receiver = _resolveReceiver(account, data);
        uint256 deposited = protocol.depositFor(account, amount, receiver);

        emit Deposited(account, receiver, deposited, data);
        return deposited;
    }

    function withdraw(address account, uint256 amount, bytes calldata data) external override onlyAuthorized(account) returns (uint256) {
        if (amount == 0) {
            revert AdapterZeroAmount();
        }
        _ensureRegistered();

        address receiver = _resolveReceiver(account, data);
        uint256 withdrawn = protocol.withdrawTo(account, amount, receiver);

        emit Withdrawn(account, receiver, withdrawn, data);
        return withdrawn;
    }

    function claim(address account, bytes calldata data) external override onlyAuthorized(account) returns (uint256) {
        _ensureRegistered();

        address receiver = _resolveReceiver(account, data);
        uint256 claimed = protocol.claimTo(account, receiver);

        emit YieldClaimed(account, receiver, claimed, data);
        return claimed;
    }

    function currentValue(address account) external view override returns (uint256) {
        MockYieldProtocol.Position memory pos = protocol.position(account);
        return pos.principal + pos.pendingYield;
    }

    function position(address account) external view override returns (Position memory info) {
        MockYieldProtocol.Position memory pos = protocol.position(account);
        info.principal = pos.principal;
        info.pendingYield = pos.pendingYield;
    }

    function _resolveReceiver(address account, bytes calldata data) private pure returns (address receiver) {
        if (data.length == 0) {
            return account;
        }
        if (data.length != 32) {
            revert AdapterInvalidData();
        }
        receiver = abi.decode(data, (address));
        if (receiver == address(0)) {
            receiver = account;
        }
    }

    function _ensureRegistered() private view {
        if (protocol.adapter() != address(this)) {
            revert AdapterNotRegistered();
        }
    }
}
