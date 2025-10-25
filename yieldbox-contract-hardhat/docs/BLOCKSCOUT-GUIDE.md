# Blockscout Explorer Guide for YieldBox Contracts

## Quick Start

This guide helps you interact with YieldBox smart contracts on [Base Sepolia Blockscout](https://sepolia.basescan.org/).

## Prerequisites

1. **MetaMask or similar wallet** configured for Base Sepolia
2. **Test ETH** from [Base Sepolia Faucet](https://sepoliafaucet.com/)
3. **Contract addresses** from your deployment (check `deployments/baseSepolia.json`)

## Contract Addresses

After deployment, you'll have these contracts:

```
ERC6551Registry: 0x...
ERC6551Account: 0x...
OpenCrateStrategyRegistry: 0x...
MockYieldProtocol: 0x...
MockYieldAdapter: 0x...
OpenCrateNFT: 0x...
OpenCrateFactory: 0x...
```

## Step-by-Step Interaction Guide

### 1. Verify Contracts on Blockscout

1. Go to [Base Sepolia Blockscout](https://sepolia.basescan.org/)
2. Enter contract address in search bar
3. Click on "Contract" tab
4. Click "Verify and Publish"
5. Fill in verification details:
   - **Compiler Type**: Solidity (Single File)
   - **Compiler Version**: 0.8.28
   - **Optimization**: Yes (200 runs)
   - **License**: MIT
6. Upload the source code from `/contracts` directory
7. Enter constructor arguments if required

### 2. Check Contract Status

Use the "Read Contract" tab to check contract state:

#### Check Your NFT Balance
```
Contract: OpenCrateNFT
Function: balanceOf(address)
Parameter: Your wallet address
```

#### Get Strategy Information
```
Contract: OpenCrateStrategyRegistry
Function: getStrategy(uint256)
Parameter: 1 (for first strategy)
```

#### Check Total Supply
```
Contract: OpenCrateNFT
Function: totalSupply()
Parameters: None
```

### 3. Create Your First Yield Crate

1. Navigate to `OpenCrateFactory` contract
2. Click "Write Contract" tab
3. Connect your wallet
4. Find `createCrate` function
5. Enter parameters:
   ```
   strategyId: 1
   initialDeposit: 1000000000000000000 (1 ETH in wei)
   data: 0x
   ```
6. Click "Write" and confirm transaction

### 4. Add Funds to Existing Crate

1. Navigate to `OpenCrateFactory` contract
2. Click "Write Contract" tab
3. Find `addToCrate` function
4. Enter parameters:
   ```
   tokenId: [Your NFT token ID]
   token: 0x4200000000000000000000000000000000000000006 (WETH on Base)
   amount: 500000000000000000 (0.5 ETH in wei)
   data: 0x
   ```
5. Click "Write" and confirm transaction

### 5. Withdraw Funds from Crate

1. Navigate to `OpenCrateFactory` contract
2. Click "Write Contract" tab
3. Find `withdrawFromCrate` function
4. Enter parameters:
   ```
   tokenId: [Your NFT token ID]
   token: 0x4200000000000000000000000000000000000000006 (WETH on Base)
   amount: 100000000000000000 (0.1 ETH in wei)
   data: 0x
   ```
5. Click "Write" and confirm transaction

### 6. Create Token-Bound Account

1. Navigate to `ERC6551Registry` contract
2. Click "Write Contract" tab
3. Find `createAccount` function
4. Enter parameters:
   ```
   implementation: [ERC6551Account address]
   chainId: 84532 (Base Sepolia)
   tokenContract: [OpenCrateNFT address]
   tokenId: [Your NFT token ID]
   salt: 0x0000000000000000000000000000000000000000000000000000000000000000001
   initData: 0x
   ```
5. Click "Write" and confirm transaction

### 7. Execute Transaction via Token-Bound Account

1. Navigate to your token-bound account address
2. Click "Write Contract" tab
3. Find `executeCall` function
4. Enter parameters:
   ```
   to: [Target contract address]
   value: 0 (or amount in wei)
   data: [Encoded function call data]
   ```
5. Click "Write" and confirm transaction

## Monitoring Events

### Track Crate Creation

1. Go to `OpenCrateFactory` contract
2. Click "Events" tab
3. Look for `CrateCreated` events:
   ```
   CrateCreated(tokenId, strategyId, creator)
   ```

### Track Deposits and Withdrawals

1. Go to `MockYieldAdapter` contract
2. Click "Events" tab
3. Look for `Deposited` and `Withdrawn` events:
   ```
   Deposited(positionId, token, amount)
   Withdrawn(positionId, token, amount)
   ```

### Set Up Event Alerts

1. On Blockscout, click "Subscribe" on contract page
2. Enter your email for notifications
3. Select events to monitor

## Common Operations

### Register New Strategy

```
Contract: OpenCrateStrategyRegistry
Function: registerStrategy
Parameters:
- adapter: [MockYieldAdapter address]
- data: 0x
- riskLevel: 0 (Low), 1 (Medium), or 2 (High)
- active: true
```

### Get Crate Information

```
Contract: OpenCrateFactory
Function: getCrateInfo
Parameter: [Your NFT token ID]
```

### Calculate Yield

```
Contract: MockYieldAdapter
Function: calculateYield
Parameter: [Your position ID]
```

## Troubleshooting

### Transaction Failed

1. **Check Gas Limit**: Increase gas limit if transaction fails
2. **Verify Balance**: Ensure sufficient ETH for gas fees
3. **Check Permissions**: Verify you have required permissions
4. **Validate Parameters**: Double-check function parameters

### Contract Not Verified

1. **Wait for Confirmation**: Some contracts take time to verify
2. **Check Compiler Settings**: Ensure correct compiler version and optimization
3. **Verify Source Code**: Check for syntax errors in source code

### Can't Find Contract

1. **Verify Address**: Double-check contract address
2. **Check Network**: Ensure you're on Base Sepolia
3. **Wait for Indexing**: New contracts may take time to appear

## Gas Cost Reference

### Typical Gas Costs

- **Create Crate**: 150,000 - 200,000 gas
- **Add Funds**: 80,000 - 120,000 gas
- **Withdraw Funds**: 90,000 - 130,000 gas
- **Create Account**: 100,000 - 150,000 gas
- **Execute Call**: 50,000 - 100,000 gas

### Gas Price Tips

- **Base Sepolia**: Usually 0.01 - 0.1 gwei
- **Check Current Gas**: Use Blockscout gas tracker
- **Off-Peak Hours**: Lower gas during low activity

## Security Best Practices

### Before Interacting

1. **Verify Contracts**: Only interact with verified contracts
2. **Check Addresses**: Double-check all contract addresses
3. **Test Small Amounts**: Start with small test amounts
4. **Use Testnet**: Always test on Base Sepolia first

### During Interaction

1. **Review Transactions**: Check all parameters before signing
2. **Monitor Gas**: Watch gas prices and limits
3. **Keep Records**: Save transaction hashes for reference
4. **Secure Wallet**: Use hardware wallets for mainnet

### After Interaction

1. **Verify Results**: Check transaction succeeded
2. **Monitor Events**: Track important events
3. **Update Records**: Keep track of your positions
4. **Set Alerts**: Configure event notifications

## Advanced Usage

### Batch Operations

Use `multicall` pattern for multiple operations:

```
Contract: OpenCrateFactory
Function: multicall
Parameter: Array of encoded function calls
```

### Custom Strategy Data

Encode custom data for strategies:

```
Contract: OpenCrateStrategyRegistry
Function: registerStrategy
Parameters:
- adapter: [Adapter address]
- data: [ABI-encoded custom data]
- riskLevel: [Risk level]
- active: true
```

### Cross-Protocol Operations

Create positions across multiple protocols:

```
Contract: OpenCrateFactory
Function: createCrate
Parameters:
- strategyId: [Different strategy IDs]
- initialDeposit: [Amount for each]
- data: [Protocol-specific data]
```

## Resources

### Useful Links

- **Base Sepolia Blockscout**: https://sepolia.basescan.org/
- **Base Sepolia Faucet**: https://sepoliafaucet.com/
- **Contract Source Code**: `/contracts` directory
- **Test Suite**: `/test/YieldBox.test.ts`
- **Deployment Guide**: `/docs/DEPLOYMENT.md`

### Contract ABIs

Contract ABIs are automatically generated after compilation and available in:
`artifacts/contracts/[ContractName].sol/[ContractName].json`

### Support

For issues:
1. Check transaction details on Blockscout
2. Review event logs for debugging
3. Consult the full contract documentation
4. Test with small amounts first

---

**Remember**: This is testnet. Use test funds and never share private keys.