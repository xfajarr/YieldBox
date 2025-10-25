# YieldBox Smart Contract Documentation

## Overview

YieldBox is a comprehensive DeFi yield aggregation platform built on Base that leverages ERC6551 token-bound accounts to create dynamic yield positions across multiple protocols including Uniswap V4, Morpho, and Aave.

## Contract Architecture

### Core Components

1. **ERC6551Registry** - Registry for token-bound accounts
2. **ERC6551Account** - Implementation contract for token-bound accounts
3. **OpenCrateStrategyRegistry** - Registry for yield strategies
4. **MockYieldProtocol** - Mock yield protocol for testing
5. **MockYieldAdapter** - Adapter for the mock yield protocol
6. **OpenCrateNFT** - The main NFT contract representing yield crates
7. **OpenCrateFactory** - Factory contract for creating crates

## Contract Details

### ERC6551Registry

**Purpose**: Creates and manages token-bound accounts linked to NFTs.

**Key Functions**:
- `createAccount(implementation, chainId, tokenContract, tokenId, salt, initData)` - Creates a new token-bound account
- `account(implementation, chainId, tokenContract, tokenId, salt)` - Computes the address of a token-bound account

**Events**:
- `AccountCreated(address account, uint256 chainId, address tokenContract, uint256 tokenId)`

### ERC6551Account

**Purpose**: Implementation contract for token-bound accounts that can hold assets and execute transactions.

**Key Functions**:
- `executeCall(to, value, data)` - Execute arbitrary calls on behalf of the account
- `token()` - Returns the parent NFT information
- `owner()` - Returns the owner of the parent NFT

**Events**:
- `TransactionExecuted(address to, uint256 value, bytes data)`

### OpenCrateStrategyRegistry

**Purpose**: Manages yield strategies and their associated adapters.

**Key Functions**:
- `registerStrategy(adapter, data, riskLevel, active)` - Register a new yield strategy
- `updateStrategy(strategyId, adapter, data, riskLevel, active)` - Update an existing strategy
- `getStrategy(strategyId)` - Get strategy details
- `getActiveStrategies()` - Get all active strategies

**Events**:
- `StrategyRegistered(uint256 strategyId, address adapter, uint256 riskLevel)`
- `StrategyUpdated(uint256 strategyId, address adapter, uint256 riskLevel)`

### MockYieldProtocol

**Purpose**: Mock yield protocol for testing purposes.

**Key Functions**:
- `deposit(token, amount)` - Deposit tokens into the protocol
- `withdraw(token, amount)` - Withdraw tokens from the protocol
- `getBalance(token, account)` - Get account balance
- `setAdapter(adapter)` - Set the adapter contract

**Events**:
- `Deposited(address indexed user, address indexed token, uint256 amount)`
- `Withdrawn(address indexed user, address indexed token, uint256 amount)`

### MockYieldAdapter

**Purpose**: Adapter that connects YieldBox to the mock yield protocol.

**Key Functions**:
- `deposit(positionId, token, amount, data)` - Deposit into yield position
- `withdraw(positionId, token, amount, data)` - Withdraw from yield position
- `getPosition(positionId)` - Get position details
- `calculateYield(positionId)` - Calculate accrued yield

**Events**:
- `Deposited(uint256 indexed positionId, address indexed token, uint256 amount)`
- `Withdrawn(uint256 indexed positionId, address indexed token, uint256 amount)`
- `YieldCalculated(uint256 indexed positionId, uint256 yieldAmount)`

### OpenCrateNFT

**Purpose**: NFT contract representing yield crates with ERC6551 token-bound accounts.

**Key Functions**:
- `mint(to, tokenId)` - Mint a new crate NFT
- `tokenURI(tokenId)` - Get the metadata URI for a token
- `setFactory(factory)` - Set the factory contract
- `getAccount(tokenId)` - Get the token-bound account for a token

**Events**:
- `Transfer(address from, address to, uint256 tokenId)`
- `AccountCreated(uint256 indexed tokenId, address indexed account)`

### OpenCrateFactory

**Purpose**: Factory contract for creating and managing yield crates.

**Key Functions**:
- `createCrate(strategyId, initialDeposit, data)` - Create a new yield crate
- `addToCrate(tokenId, token, amount, data)` - Add funds to an existing crate
- `withdrawFromCrate(tokenId, token, amount, data)` - Withdraw funds from a crate
- `getCrateInfo(tokenId)` - Get crate information

**Events**:
- `CrateCreated(uint256 indexed tokenId, uint256 strategyId, address indexed creator)`
- `FundsAdded(uint256 indexed tokenId, address indexed token, uint256 amount)`
- `FundsWithdrawn(uint256 indexed tokenId, address indexed token, uint256 amount)`

## Protocol Integration

### Uniswap V4 Integration

YieldBox supports Uniswap V4 positions through dedicated adapters:

- **Position Types**: Concentrated liquidity positions
- **Key Data**: Pool ID, tick range, liquidity amount
- **Yield Calculation**: Based on trading fees and position performance

**Example Position Data**:
```json
{
  "protocol": "uniswap_v4",
  "poolId": "0x1234567890123456789012345678901234567890",
  "tickLower": -60,
  "tickUpper": 60,
  "liquidity": "1000000"
}
```

### Morpho Integration

YieldBox integrates with Morpho for lending and borrowing:

- **Position Types**: Lending positions, isolated borrowing
- **Key Data**: Market address, supplied amount, borrowed amount
- **Yield Calculation**: Based on interest rates and market conditions

**Example Position Data**:
```json
{
  "protocol": "morpho",
  "market": "0xabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd",
  "supplyAmount": "1000000000000000000",
  "borrowAmount": "500000000000000000"
}
```

### Aave Integration

YieldBox supports Aave V3 for liquidity provision:

- **Position Types**: aToken positions, variable rate lending
- **Key Data**: Asset address, supplied amount, health factor
- **Yield Calculation**: Based on Aave interest rate model

**Example Position Data**:
```json
{
  "protocol": "aave_v3",
  "asset": "0xdac17f958d2ee523a2206206994597c13d831ec7",
  "amount": "1000000000000000000",
  "aToken": "0x1234567890123456789012345678901234567890"
}
```

## Using Contracts on Base Blockscout Explorer

### 1. Contract Verification

After deployment, contracts can be verified on [Base Sepolia Blockscout](https://sepolia.basescan.org/):

1. Navigate to the contract address
2. Click on "Contract" tab
3. Click "Verify and Publish"
4. Select compiler version `0.8.28`
5. Enable optimization with 200 runs
6. Upload source code and constructor arguments

### 2. Reading Contract State

Use Blockscout's "Read Contract" tab to interact with view functions:

**Example: Check Crate Balance**
```
Function: balanceOf(address owner)
Parameter: Your wallet address
```

**Example: Get Strategy Information**
```
Function: getStrategy(uint256 strategyId)
Parameter: Strategy ID (e.g., 1)
```

### 3. Writing to Contracts

Use Blockscout's "Write Contract" tab to execute functions:

**Example: Create New Crate**
```
Function: createCrate(uint256 strategyId, uint256 initialDeposit, bytes data)
Parameters:
- strategyId: 1
- initialDeposit: 1000000000000000000 (1 ETH)
- data: 0x (empty)
```

**Example: Add Funds to Crate**
```
Function: addToCrate(uint256 tokenId, address token, uint256 amount, bytes data)
Parameters:
- tokenId: Your NFT token ID
- token: Token contract address
- amount: Amount to add (in wei)
- data: 0x (empty)
```

## Event Monitoring

### Key Events to Monitor

1. **CrateCreated**: New yield crate creation
2. **Deposited**: Funds added to yield positions
3. **Withdrawn**: Funds withdrawn from yield positions
4. **YieldCalculated**: Yield computation events
5. **StrategyRegistered**: New strategy registration

### Event Filtering on Blockscout

1. Go to contract's "Events" tab
2. Use filters to monitor specific events
3. Set up alerts for important events

## Security Considerations

### Contract Audits

- All contracts implement OpenZeppelin security standards
- Reentrancy protection on critical functions
- Access control with owner/role-based permissions
- Proper input validation and bounds checking

### Best Practices

1. **Verify Contracts**: Always verify deployed contracts on Blockscout
2. **Check Addresses**: Double-check contract addresses before interaction
3. **Test on Testnet**: Use Base Sepolia for testing before mainnet
4. **Monitor Events**: Set up event monitoring for important activities
5. **Secure Private Keys**: Use hardware wallets for mainnet operations

## Gas Optimization

### Deployment Gas Costs

- **ERC6551Registry**: ~2.5M gas
- **ERC6551Account**: ~3.2M gas
- **OpenCrateStrategyRegistry**: ~2.8M gas
- **MockYieldProtocol**: ~2.1M gas
- **MockYieldAdapter**: ~2.3M gas
- **OpenCrateNFT**: ~3.5M gas
- **OpenCrateFactory**: ~4.1M gas

### Transaction Gas Costs

- **Create Crate**: ~150,000 gas
- **Add Funds**: ~80,000 gas
- **Withdraw Funds**: ~90,000 gas
- **Calculate Yield**: ~45,000 gas

## Troubleshooting

### Common Issues

1. **Transaction Failed**: Check gas limits and contract allowances
2. **Invalid Address**: Verify contract addresses on Blockscout
3. **Permission Denied**: Ensure you have required permissions/roles
4. **Incorrect Parameters**: Double-check function parameters and data encoding

### Debug Tools

1. **Blockscout Transaction Viewer**: Analyze failed transactions
2. **Event Logs**: Check event emission for debugging
3. **Contract State**: Use "Read Contract" to verify state
4. **Gas Estimator**: Estimate gas costs before execution

## Development Resources

### Contract Source Code

All contract source code is available in the `/contracts` directory:
- `ERC6551Registry.sol`
- `ERC6551Account.sol`
- `OpenCrateStrategyRegistry.sol`
- `MockYieldProtocol.sol`
- `MockYieldAdapter.sol`
- `OpenCrateNFT.sol`
- `OpenCrateFactory.sol`

### Testing

Comprehensive test suite available in `/test/YieldBox.test.ts`:
- Unit tests for all contracts
- Integration tests for complete workflows
- Fuzz testing for edge cases
- Protocol-specific tests

### Deployment Scripts

- `scripts/deploy-sepolia.ts`: Deploy to Base Sepolia
- `scripts/verify-sepolia.ts`: Verify contracts on Blockscout

## Support

For questions or issues:
1. Check the documentation in `/docs` directory
2. Review test cases for usage examples
3. Examine event logs for debugging
4. Use Blockscout explorer for contract analysis

---

**Note**: This documentation is for the Base Sepolia testnet deployment. For mainnet deployment, ensure all security audits and testing are completed.