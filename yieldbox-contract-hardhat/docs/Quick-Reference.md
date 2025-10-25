# OpenCrate Quick Reference

## System Overview

OpenCrate is a DeFi yield farming platform that creates NFTs representing yield strategies, with each NFT having an associated ERC6551 token-bound account for interacting with DeFi protocols.

## Contract Summary

| Contract | Purpose | Key Functions |
|----------|---------|---------------|
| `OpenCrateNFT` | NFT representing yield crates | `mintCrate()`, `updatePrice()`, `setBoostMultiplier()` |
| `OpenCrateFactory` | Creates crates and accounts | `mintCrate()`, `predictAccount()` |
| `ERC6551Registry` | Token-bound account registry | `createAccount()`, `account()` |
| `ERC6551Account` | Smart contract accounts | `executeCall()`, `isValidSignature()` |
| `OpenCrateStrategyRegistry` | Manages yield strategies | `registerStrategy()`, `updateStrategy()` |
| `IDeFiAdapter` | Interface for DeFi adapters | `deposit()`, `withdraw()`, `claim()` |

## Key Data Structures

### CrateInfo
```solidity
struct CrateInfo {
    uint8 riskLevel;            // 0=High, 1=Medium, 2=Random
    uint256 strategyId;         // Strategy ID
    address creator;            // Creator address
    uint256 priceUsd;           // Price in USD (2 decimals)
    uint16 boostMultiplierBps;  // Boost multiplier (10000=1.0x)
    bool boostActive;           // Whether boost is active
    uint64 lockedUntil;         // Lock expiry timestamp
    uint64 lastLockAt;          // Last lock timestamp
    uint64 lastBoostAt;         // Last boost timestamp
    uint16 revenueShareBps;     // Revenue share (10000=100%)
    uint16 platformFeeBps;      // Platform fee
    uint16 performanceFeeBps;   // Performance fee
    string riskDisclosure;      // Risk disclosure text
    string feeDisclosure;       // Fee disclosure text
    uint64 lastRebalanceAt;     // Last rebalance timestamp
    uint64 nextHarvestAt;       // Next harvest timestamp
    uint256 accruedYieldUsd;    // Accrued yield in USD
    address account;            // Associated ERC6551 account
    uint64 mintedAt;            // Mint timestamp
}
```

### PositionDetails
```solidity
struct PositionDetails {
    string protocol;           // Protocol name
    string asset;              // Asset symbol
    string strategyType;       // Strategy type
    string chain;              // Chain name
    string infoURL;            // Information URL
    uint16 allocationBps;      // Allocation percentage
    uint256 allocationUsd;     // Allocation in USD
    uint16 netApyBps;          // Net APY
    uint16 baseAprBps;         // Base APR
    uint16 incentivesAprBps;   // Incentives APR
    uint16 feeBps;             // Fee percentage
    uint8 riskScore;           // Risk score
    uint64 openedAt;           // Open timestamp
    uint64 lastRebalancedAt;   // Last rebalance timestamp
    uint64 nextHarvestAt;      // Next harvest timestamp
    uint256 accruedYieldUsd;   // Accrued yield in USD
}
```

## Constants and Limits

| Parameter | Min | Max | Description |
|-----------|-----|-----|-------------|
| Price (USD) | 500 | 100000 | Crate price (2 decimals) |
| Boost Multiplier | 10000 | 20000 | 1.0x to 2.0x (basis points) |
| Lock Duration | 0 | 31536000 | 0 to 365 days (seconds) |
| Total Fees | 0 | 10000 | 0% to 100% (basis points) |
| Risk Level | 0 | 2 | 0=High, 1=Medium, 2=Random |

## Key Workflows

### 1. Create a Yield Crate
```solidity
// Prepare mint parameters
OpenCrateFactory.MintParams memory params = OpenCrateFactory.MintParams({
    to: user,
    riskLevel: 0,                    // High risk
    strategyId: 1,
    salt: 12345,
    priceUsd: 750,                   // $7.50
    boostMultiplierBps: 10000,       // 1.0x
    lockDuration: 30 days,
    creator: user,
    revenueShareBps: 1000,           // 10%
    platformFeeBps: 200,            // 2%
    performanceFeeBps: 500,          // 5%
    riskDisclosure: "High risk investment",
    feeDisclosure: "Fees as disclosed",
    // ... other fields
});

// Mint the crate
(uint256 tokenId, address account) = factory.mintCrate(params, positions);
```

### 2. Interact with DeFi Protocol
```solidity
// Deposit through the ERC6551 account
ERC6551Account(account).executeCall(
    address(adapter),
    0,
    abi.encodeWithSelector(
        IDeFiAdapter.deposit.selector,
        account,
        1000e18,
        ""
    )
);

// Claim yield
ERC6551Account(account).executeCall(
    address(adapter),
    0,
    abi.encodeWithSelector(
        IDeFiAdapter.claim.selector,
        account,
        ""
    )
);

// Withdraw funds
ERC6551Account(account).executeCall(
    address(adapter),
    0,
    abi.encodeWithSelector(
        IDeFiAdapter.withdraw.selector,
        account,
        500e18,
        ""
    )
);
```

### 3. Update Crate Parameters
```solidity
// Update price
crateNFT.updatePrice(tokenId, 800);

// Set boost multiplier
crateNFT.setBoostMultiplier(tokenId, 15000); // 1.5x

// Extend lock
crateNFT.extendLock(tokenId, 60 days);

// Update positions
crateNFT.updatePositions(tokenId, newPositions);

// Update revenue share
crateNFT.updateRevenueShare(tokenId, 1500, 300, 400);
```

## Error Codes

| Error | Description |
|-------|-------------|
| `Unauthorized` | Caller not authorized |
| `InvalidPrice` | Price outside allowed range |
| `InvalidBoost` | Boost multiplier outside range |
| `InvalidLockDuration` | Lock duration exceeds maximum |
| `InvalidBps` | Basis points sum exceeds 10000 |
| `StrategyInactive` | Strategy is not active |
| `StrategyRiskMismatch` | Strategy risk level mismatch |
| `NotApprovedOrOwner` | Not approved or owner |
| `AdapterUnauthorized` | Adapter not authorized |
| `AdapterInvalidData` | Invalid adapter data |
| `AdapterZeroAmount` | Zero amount not allowed |

## Events

### OpenCrateNFT
```solidity
event CrateMinted(
    uint256 indexed tokenId,
    address indexed to,
    address account,
    uint8 riskLevel,
    uint256 strategyId
);

event PriceUpdated(uint256 indexed tokenId, uint256 newPrice);

event BoostMultiplierSet(
    uint256 indexed tokenId,
    uint16 boostMultiplierBps,
    bool active
);

event LockExtended(
    uint256 indexed tokenId,
    uint64 newLockedUntil
);

event PositionsUpdated(uint256 indexed tokenId);
```

### OpenCrateFactory
```solidity
event CrateCreated(
    uint256 indexed tokenId,
    address indexed to,
    address account,
    uint256 strategyId,
    uint8 riskLevel
);
```

### ERC6551Registry
```solidity
event AccountCreated(
    address indexed account,
    uint256 indexed tokenId,
    address indexed implementation,
    uint256 salt
);
```

## Gas Optimization Tips

1. **Batch Operations**: Use `updatePositions()` to update multiple positions at once
2. **Predictive Address**: Use `predictAccount()` before minting to avoid extra calls
3. **Efficient Updates**: Update multiple parameters in a single transaction when possible
4. **Lock Duration**: Longer locks provide better yields but reduce liquidity

## Security Considerations

1. **Access Control**: Always verify caller permissions
2. **Input Validation**: Validate all inputs against allowed ranges
3. **Reentrancy**: Use reentrancy guards where applicable
4. **Strategy Validation**: Ensure strategies match risk levels
5. **Adapter Authorization**: Only authorized adapters can interact with accounts