# OpenCrate - Yield Farming with Token Bound Accounts

## What is OpenCrate?

OpenCrate is a DeFi yield farming platform that leverages the ERC6551 Token Bound Accounts standard to create NFTs that represent yield farming strategies. Each NFT has its own associated smart contract account that can interact with DeFi protocols, combining the liquidity of NFTs with the functionality of smart contracts.

## Key Features

- **Token Bound Accounts**: Each NFT has its own smart contract account (ERC6551)
- **Yield Farming Strategies**: Support for multiple DeFi protocols through adapters
- **Risk Categorization**: High, Medium, and Random risk levels
- **Boost Multipliers**: Up to 2x yield boost on positions
- **Lock Mechanisms**: Optional lock-up periods with enhanced rewards
- **Fee Structure**: Platform fees, performance fees, and revenue sharing
- **Comprehensive Tracking**: Detailed position and performance metrics

## How It Works

1. **Create a Crate**: Users mint an NFT representing a yield farming strategy
2. **Token Bound Account**: Each NFT gets its own smart contract account
3. **Yield Farming**: The account interacts with DeFi protocols through adapters
4. **Track Performance**: All metrics are stored in the NFT metadata
5. **Manage Positions**: Update, rebalance, or withdraw as needed

## Architecture

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   OpenCrateNFT  │    │  ERC6551Account  │    │  DeFi Adapter   │
│   (NFT Crate)   │◄──►│ (Smart Contract) │◄──►│   (Protocol)    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   CrateInfo     │    │   Execute Call   │    │  Yield Farming  │
│   - Risk Level  │    │   - Deposit      │    │   - Deposit     │
│   - Strategy    │    │   - Withdraw     │    │   - Withdraw    │
│   - Positions   │    │   - Claim        │    │   - Claim       │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## Contract Components

### Core Contracts
- **OpenCrateNFT**: The main NFT contract representing yield crates
- **OpenCrateFactory**: Factory for creating new crates and accounts
- **ERC6551Registry**: Registry for token-bound accounts
- **ERC6551Account**: Smart contract accounts bound to NFTs
- **OpenCrateStrategyRegistry**: Registry for managing yield strategies

### Interfaces and Adapters
- **IDeFiAdapter**: Standard interface for DeFi protocol adapters
- **MockYieldAdapter**: Example adapter implementation
- **MockYieldProtocol**: Mock protocol for testing

## Getting Started

### Prerequisites
- Node.js 18+
- npm or pnpm
- Hardhat 3.0.9+

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd yieldbox-contract-hardhat

# Install dependencies
npm install
# or
pnpm install
```

### Running Tests

```bash
# Run all tests
npx hardhat test

# Run specific test suites
npx hardhat test solidity
npx hardhat test nodejs
```

### Deployment

```bash
# Deploy to local network
npx hardhat ignition deploy ignition/modules/Counter.ts

# Deploy to Sepolia (requires SEPOLIA_PRIVATE_KEY)
npx hardhat ignition deploy --network sepolia ignition/modules/Counter.ts
```

## Example Usage

### Creating a Yield Crate

```solidity
// Mint a new crate with high-risk strategy
OpenCrateFactory.MintParams memory params = OpenCrateFactory.MintParams({
    to: user,
    riskLevel: 0, // High risk
    strategyId: 1,
    salt: 12345,
    priceUsd: 750, // $7.50
    boostMultiplierBps: 10000, // 1.0x
    lockDuration: 30 days,
    // ... other parameters
});

(uint256 tokenId, address account) = factory.mintCrate(params, positions);
```

### Yield Farming Through Token-Bound Account

```solidity
// Deposit funds through the ERC6551 account
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
```

## Key Data Structures

### CrateInfo
```solidity
struct CrateInfo {
    uint8 riskLevel;            // Risk level (0=High, 1=Medium, 2=Random)
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

## Security Features

- Access control for sensitive operations
- Input validation for all parameters
- Transfer restrictions for locked crates
- Strategy risk level validation
- Adapter authorization system

## Documentation

For detailed documentation, see [OpenCrate-Documentation.md](docs/OpenCrate-Documentation.md)

## License

MIT License