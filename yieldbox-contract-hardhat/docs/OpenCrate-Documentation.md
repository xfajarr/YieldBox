# OpenCrate Documentation

## Overview

OpenCrate is a sophisticated DeFi yield farming platform built on the ERC6551 Token Bound Accounts standard. It enables users to create NFTs that represent yield farming strategies, with each NFT having its own associated smart contract account that can interact with DeFi protocols. The system combines the liquidity of NFTs with the functionality of smart contracts to create a powerful yield optimization platform.

## Architecture

The OpenCrate system consists of several interconnected components:

### Core Contracts

1. **OpenCrateNFT** - The main NFT contract representing yield crates
2. **OpenCrateFactory** - Factory contract for creating new yield crates
3. **ERC6551Registry** - Registry for creating token-bound accounts
4. **ERC6551Account** - Smart contract accounts bound to NFTs
5. **OpenCrateStrategyRegistry** - Registry for managing yield strategies

### Supporting Contracts

1. **IDeFiAdapter** - Interface for DeFi protocol adapters
2. **MockYieldAdapter** - Example adapter for a yield protocol
3. **MockYieldProtocol** - Mock yield protocol for testing

## Key Concepts

### Token Bound Accounts (ERC6551)

OpenCrate leverages the ERC6551 standard, which allows each NFT to have its own smart contract account. This means:

- Each NFT represents a yield farming position
- The NFT owner controls the associated smart contract account
- The account can interact with DeFi protocols directly
- Ownership of the NFT transfers control of the account

### Yield Crates

A "Crate" is an NFT that represents a yield farming strategy with the following properties:

- **Risk Level**: High (0), Medium (1), or Random (2)
- **Strategy**: The specific yield farming strategy used
- **Price**: USD value of the crate (between $5 and $1000)
- **Boost Multiplier**: Yield boost factor (1.0x to 2.0x)
- **Lock Duration**: Optional lock-up period (up to 365 days)
- **Fee Structure**: Revenue share, platform fees, and performance fees
- **Positions**: Detailed information about underlying DeFi positions

### Strategy System

The platform uses a strategy registry system where:

- Each strategy is associated with a specific DeFi adapter
- Strategies have risk levels and can be activated/deactivated
- Users can select strategies based on their risk tolerance

## Contract Details

### OpenCrateNFT

The main NFT contract that represents yield crates.

**Key Features:**
- ERC721-compliant with ERC2981 royalty support
- Stores comprehensive crate information including risk level, strategy, and performance metrics
- Supports price updates, boost multipliers, and lock extensions
- Manages position data for underlying DeFi investments
- Includes transfer restrictions for locked crates

**Important Functions:**
- `mintCrate()`: Creates a new yield crate (only callable by factory)
- `updatePrice()`: Updates the USD price of a crate
- `setBoostMultiplier()`: Sets the yield boost multiplier
- `extendLock()`: Extends the lock duration
- `updatePositions()`: Updates the underlying DeFi positions
- `updateLifecycle()`: Updates rebalancing and harvesting schedules

### OpenCrateFactory

Factory contract responsible for creating new yield crates and their associated token-bound accounts.

**Key Features:**
- Creates ERC6551 accounts for each crate
- Validates strategy compatibility and risk levels
- Manages the relationship between crates and their accounts
- Provides prediction functions for account addresses

**Important Functions:**
- `mintCrate()`: Creates a new crate with associated account
- `predictAccount()`: Predicts the account address before creation
- `crateAdapter()`: Retrieves the adapter and data for a crate
- `accountOf()`: Gets the account address for a specific crate

### ERC6551Registry

Registry contract for creating and managing token-bound accounts according to the ERC6551 standard.

**Key Features:**
- Creates deterministic addresses for token-bound accounts
- Supports initialization data for account setup
- Emits events for account creation

**Important Functions:**
- `createAccount()`: Creates a new token-bound account
- `account()`: Predicts the account address

### ERC6551Account

Implementation of the ERC6551 account standard that provides smart contract functionality to NFTs.

**Key Features:**
- Execute arbitrary calls on behalf of the NFT owner
- Implements signature verification (ERC1271)
- Tracks transaction nonces
- Provides token ownership information

**Important Functions:**
- `executeCall()`: Executes calls to other contracts
- `owner()`: Returns the NFT owner
- `token()`: Returns the associated NFT information
- `isValidSignature()`: Verifies signatures

### OpenCrateStrategyRegistry

Registry for managing yield farming strategies and their associated adapters.

**Key Features:**
- Registers and manages yield strategies
- Categorizes strategies by risk level
- Enables strategy activation/deactivation

**Important Functions:**
- `registerStrategy()`: Registers a new strategy
- `updateStrategy()`: Updates an existing strategy
- `setStrategyStatus()`: Activates or deactivates a strategy
- `strategiesByRisk()`: Gets strategies by risk level

### DeFi Adapters

Adapters provide a standardized interface for interacting with different DeFi protocols.

**IDeFiAdapter Interface:**
- `deposit()`: Deposits funds into a protocol
- `withdraw()`: Withdraws funds from a protocol
- `claim()`: Claims yield/rewards
- `currentValue()`: Gets the current value of a position
- `position()`: Gets detailed position information

## Workflow

### Creating a Yield Crate

1. User selects a strategy from the strategy registry
2. User calls `mintCrate()` on the factory with desired parameters
3. Factory creates a new ERC6551 account for the crate
4. Factory mints a new NFT representing the crate
5. The NFT owner now controls the associated account

### Managing a Yield Crate

1. The NFT owner can interact with the DeFi protocol through the ERC6551 account
2. The account calls the adapter's `deposit()`, `withdraw()`, and `claim()` functions
3. Performance metrics are tracked in the NFT metadata
4. The crate can be updated with new positions or parameters

### Yield Generation

1. Funds are deposited into DeFi protocols through adapters
2. Yield accrues according to the protocol's mechanics
3. Yield can be claimed and reinvested or withdrawn
4. Performance fees are automatically deducted

## Security Features

### Access Control

- Factory-only minting of crates
- Owner-only updates to crate parameters
- Adapter authorization for protocol interactions
- Strategy registry controlled by platform owner

### Validation

- Price range validation ($5 - $1000)
- Boost multiplier limits (1.0x - 2.0x)
- Lock duration limits (max 365 days)
- Fee structure validation (total fees ≤ 100%)
- Position allocation validation (total ≤ 100%)

### Transfer Restrictions

- Locked crates cannot be transferred until lock expires
- Authorization checks for sensitive operations
- Strategy risk level validation

## Testing

The project includes comprehensive tests covering:

- Strategy registry management
- Crate minting and factory operations
- Price and parameter updates
- Position management
- DeFi adapter functionality
- Security validations and edge cases

## Usage Examples

### Basic Crate Creation

```solidity
// Mint a new crate with default parameters
OpenCrateFactory.MintParams memory params = OpenCrateFactory.MintParams({
    to: user,
    riskLevel: 0, // High risk
    strategyId: 1,
    salt: 12345,
    priceUsd: 750, // $7.50
    boostMultiplierBps: 10000, // 1.0x
    lockDuration: 30 days,
    creator: user,
    revenueShareBps: 1000, // 10%
    platformFeeBps: 200, // 2%
    performanceFeeBps: 500, // 5%
    riskDisclosure: "High risk investment",
    feeDisclosure: "Fees as disclosed",
    lastRebalanceAt: 0,
    nextHarvestAt: 0,
    accruedYieldUsd: 0,
    boostActive: false,
    accountInitData: "",
    adapterData: ""
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
        1000e18, // 1000 tokens
        "" // no additional data
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
```

## Future Enhancements

Potential areas for future development:

1. **Additional DeFi Protocol Adapters**: Support for more yield protocols
2. **Automated Rebalancing**: Smart contract-based position management
3. **Yield Optimization**: Algorithmic yield enhancement strategies
4. **Governance**: Community-driven strategy and parameter management
5. **Insurance**: Protection against yield farming losses

## Conclusion

OpenCrate represents an innovative approach to yield farming by combining NFTs with smart contract functionality through the ERC6551 standard. This creates a more flexible, composable, and user-friendly yield farming experience while maintaining the security and decentralization benefits of DeFi.

The modular architecture allows for easy integration of new protocols and strategies, making the platform adaptable to the evolving DeFi landscape. The comprehensive testing and security features ensure a robust foundation for yield farming activities.