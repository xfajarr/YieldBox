# YieldBox Contract Deployment Guide

This guide provides instructions for deploying the YieldBox contracts to Base Sepolia testnet using the Viem-based deployment script.

## Prerequisites

1. **Node.js and npm/pnpm installed**
2. **Base Sepolia testnet ETH** - Get from [Base Sepolia faucet](https://sepoliafaucet.com/)
3. **Environment variables configured** - Copy `.env.example` to `.env` and fill in your values

## Environment Setup

1. Copy the environment template:
```bash
cp .env.example .env
```

2. Edit `.env` with your values:
```env
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
BASE_SEPOLIA_PRIVATE_KEY=your_private_key_here
```

## Installation

Install dependencies:
```bash
pnpm install
```

## Deployment

### Deploy to Base Sepolia

Run the deployment script:
```bash
npx hardhat run scripts/deploy-sepolia.ts --network baseSepolia
```

### What gets deployed?

The script deploys the following contracts in order:

1. **ERC6551Registry** - Registry for token-bound accounts
2. **ERC6551Account** - Implementation contract for token-bound accounts
3. **OpenCrateStrategyRegistry** - Registry for yield strategies
4. **MockYieldProtocol** - Mock yield protocol for testing
5. **MockYieldAdapter** - Adapter for the mock yield protocol
6. **OpenCrateNFT** - The main NFT contract representing yield crates
7. **OpenCrateFactory** - Factory contract for creating crates

### Post-deployment configuration

The script automatically:
- Sets the adapter in the MockYieldProtocol
- Sets the factory in the OpenCrateNFT contract
- Registers a test strategy in the strategy registry

## Deployment Output

After successful deployment, you'll see:
- Console output with all deployed contract addresses
- A `deployments/baseSepolia.json` file with deployment details

Example output:
```
🚀 Deploying YieldBox contracts to Base Sepolia testnet...
📦 Deploying ERC6551Registry...
✅ ERC6551Registry deployed to: 0x1234...
📦 Deploying ERC6551Account...
✅ ERC6551Account deployed to: 0x5678...
...
🎉 All contracts deployed successfully!

📋 Deployment Summary:
================
ERC6551Registry: 0x1234...
ERC6551Account: 0x5678...
OpenCrateStrategyRegistry: 0xabcd...
...
================

💾 Deployment saved to: deployments/baseSepolia.json
🎉 Deployment complete!
```

## Verification

After deployment, you can verify contracts on BaseScan using the separate verification script:

```bash
npx hardhat run scripts/verify-sepolia.ts --network baseSepolia
```

This script will:
- Read the deployment file automatically
- Verify each contract with the correct constructor arguments
- Handle already verified contracts gracefully

### Manual Verification

If automatic verification fails, you can verify manually:

1. Go to [Base Sepolia BaseScan](https://sepolia.basescan.org/verifyContract)
2. Enter the contract address
3. Select "Solidity (Single File)"
4. Choose compiler version `0.8.28`
5. Optimization enabled with 200 runs
6. Paste the contract source code
7. Enter constructor arguments if needed

### Constructor Arguments

- **OpenCrateStrategyRegistry**: `[deployer_address]`
- **MockYieldProtocol**: `[deployer_address]`
- **MockYieldAdapter**: `[mockYieldProtocol_address, deployer_address]`
- **OpenCrateNFT**: `["OpenCrate", "CRATE", "https://metadata.opencrate.io/", deployer_address, "0x0000000000000000000000000000000000000000"]`
- **OpenCrateFactory**: `[openCrateNFT_address, erc6551Registry_address, erc6551Account_address, strategyRegistry_address, deployer_address]`

## Testing

After deployment, you can test the contracts using the comprehensive test suite:

```bash
npx hardhat test
```

## Troubleshooting

### Common Issues

1. **Insufficient funds**: Ensure you have enough Base Sepolia ETH for gas
2. **Network issues**: Check your RPC URL and network connectivity
3. **Private key format**: Ensure your private key is in the correct format (0x...)

### Debug Mode

For more detailed output, you can modify the script to add more logging or use Hardhat's verbose mode:

```bash
npx hardhat run scripts/deploy-sepolia.ts --network baseSepolia --verbose
```

## Security Considerations

- Never commit your `.env` file to version control
- Use a dedicated deployer account with limited funds
- Verify contract addresses before interacting with them
- Test thoroughly on testnet before mainnet deployment

## Next Steps

1. Interact with the deployed contracts using a frontend or scripts
2. Add contract verification support
3. Set up monitoring and alerting for your deployed contracts
4. Prepare for mainnet deployment following the same process