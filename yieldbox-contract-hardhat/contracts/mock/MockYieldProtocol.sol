// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";

contract MockYieldProtocol is Ownable {
    struct Position {
        uint256 principal;
        uint256 pendingYield;
    }

    struct RewardState {
        uint256 index;
        uint256 lastAccrual;
        uint256 totalPrincipal;
    }

    struct AccountState {
        uint256 principal;
        uint256 rewardIndex;
        uint256 accruedRewards;
    }

    error AdapterNotInitialized();
    error AdapterOnly(address caller);
    error InvalidAdapter(address adapter);
    error InvalidAmount(uint256 amount);
    error InsufficientPrincipal(uint256 requested, uint256 balance);
    error LengthMismatch(uint256 accountsLength, uint256 amountsLength);
    error ZeroAccount();

    uint256 private constant RAY = 1e27;

    mapping(address => AccountState) private _accounts;
    address public adapter;
    uint256 public rewardRate;
    RewardState public rewardState;

    event AdapterUpdated(address indexed adapter);
    event RewardRateUpdated(uint256 rewardRate);
    event Deposited(address indexed account, address indexed receiver, uint256 amount);
    event Withdrawn(address indexed account, address indexed receiver, uint256 amount);
    event YieldClaimed(address indexed account, address indexed receiver, uint256 amount);
    event YieldAccrued(address indexed account, uint256 amount);

    modifier onlyAdapter() {
        if (adapter == address(0)) {
            revert AdapterNotInitialized();
        }
        if (msg.sender != adapter) {
            revert AdapterOnly(msg.sender);
        }
        _;
    }

    constructor(address owner_) Ownable(owner_ == address(0) ? msg.sender : owner_) {
        rewardState.lastAccrual = block.timestamp;
    }

    function setAdapter(address adapter_) external onlyOwner {
        if (adapter_ == address(0)) {
            revert InvalidAdapter(adapter_);
        }
        adapter = adapter_;
        emit AdapterUpdated(adapter_);
    }

    function setRewardRate(uint256 rewardRate_) external onlyOwner {
        _accrueGlobal();
        rewardRate = rewardRate_;
        emit RewardRateUpdated(rewardRate_);
    }

    function depositFor(address account, uint256 amount, address receiver) external onlyAdapter returns (uint256) {
        if (amount == 0) {
            revert InvalidAmount(amount);
        }
        if (account == address(0)) {
            revert ZeroAccount();
        }

        address targetReceiver = receiver == address(0) ? account : receiver;
        _accrueGlobal();

        AccountState storage accountState = _settleAccount(account);
        accountState.principal += amount;

        rewardState.totalPrincipal += amount;

        emit Deposited(account, targetReceiver, amount);
        return amount;
    }

    function withdrawTo(address account, uint256 amount, address receiver) external onlyAdapter returns (uint256) {
        if (amount == 0) {
            revert InvalidAmount(amount);
        }
        if (account == address(0)) {
            revert ZeroAccount();
        }

        address targetReceiver = receiver == address(0) ? account : receiver;
        _accrueGlobal();

        AccountState storage accountState = _settleAccount(account);
        if (accountState.principal < amount) {
            revert InsufficientPrincipal(amount, accountState.principal);
        }

        accountState.principal -= amount;
        rewardState.totalPrincipal -= amount;

        emit Withdrawn(account, targetReceiver, amount);
        return amount;
    }

    function claimTo(address account, address receiver) external onlyAdapter returns (uint256) {
        if (account == address(0)) {
            revert ZeroAccount();
        }

        address targetReceiver = receiver == address(0) ? account : receiver;
        _accrueGlobal();

        AccountState storage accountState = _settleAccount(account);
        uint256 yieldAmount = accountState.accruedRewards;
        accountState.accruedRewards = 0;

        emit YieldClaimed(account, targetReceiver, yieldAmount);
        return yieldAmount;
    }

    function creditYield(address account, uint256 amount) external onlyOwner {
        if (amount == 0) {
            revert InvalidAmount(amount);
        }
        if (account == address(0)) {
            revert ZeroAccount();
        }
        _accrueGlobal();
        AccountState storage accountState = _settleAccount(account);
        accountState.accruedRewards += amount;
        emit YieldAccrued(account, amount);
    }

    function creditYieldBatch(address[] calldata accounts, uint256[] calldata amounts) external onlyOwner {
        uint256 length = accounts.length;
        if (length != amounts.length) {
            revert LengthMismatch(length, amounts.length);
        }

        _accrueGlobal();

        for (uint256 i = 0; i < length; ) {
            address account = accounts[i];
            if (account == address(0)) {
                revert ZeroAccount();
            }
            uint256 amount = amounts[i];
            if (amount == 0) {
                revert InvalidAmount(amount);
            }
            AccountState storage accountState = _settleAccount(account);
            accountState.accruedRewards += amount;
            emit YieldAccrued(account, amount);
            unchecked {
                ++i;
            }
        }
    }

    function accrue() external {
        _accrueGlobal();
    }

    function position(address account) external view returns (Position memory) {
        (uint256 accruedPrincipal, uint256 accruedRewards) = _previewAccount(account);
        return Position({principal: accruedPrincipal, pendingYield: accruedRewards});
    }

    function _accrueGlobal() internal {
        uint256 lastAccrual = rewardState.lastAccrual;
        uint256 totalPrincipal = rewardState.totalPrincipal;
        uint256 rate = rewardRate;

        if (totalPrincipal == 0 || rate == 0) {
            rewardState.lastAccrual = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - lastAccrual;
        if (elapsed == 0) {
            return;
        }

        uint256 accruedIndex = (rate * elapsed * RAY) / totalPrincipal;
        rewardState.index += accruedIndex;
        rewardState.lastAccrual = block.timestamp;
    }

    function _settleAccount(address account) internal returns (AccountState storage accountState) {
        accountState = _accounts[account];

        uint256 indexDelta = rewardState.index - accountState.rewardIndex;
        if (indexDelta != 0) {
            accountState.accruedRewards += (accountState.principal * indexDelta) / RAY;
            accountState.rewardIndex = rewardState.index;
        }
    }

    function _previewAccount(address account) internal view returns (uint256 principal, uint256 pendingRewards) {
        if (account == address(0)) {
            return (0, 0);
        }

        RewardState memory state = rewardState;
        uint256 effectiveIndex = state.index;

        if (state.totalPrincipal != 0 && rewardRate != 0) {
            uint256 elapsed = block.timestamp - state.lastAccrual;
            if (elapsed != 0) {
                effectiveIndex += (rewardRate * elapsed * RAY) / state.totalPrincipal;
            }
        }

        AccountState memory accountState = _accounts[account];
        principal = accountState.principal;
        pendingRewards = accountState.accruedRewards;

        uint256 accountIndex = accountState.rewardIndex;
        if (effectiveIndex > accountIndex) {
            uint256 indexDelta = effectiveIndex - accountIndex;
            pendingRewards += (accountState.principal * indexDelta) / RAY;
        }
    }
}
