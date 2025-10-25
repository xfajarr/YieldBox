# Quick Start Guide - How to Use the Deployment Script

## Step 1: Setup Environment

1. **Copy the environment template:**
```bash
cp .env.example .env
```

2. **Edit the `.env` file** with your actual values:
```env
BASE_SEPOLIA_RPC_URL=https://sepolia.base.org
BASE_SEPOLIA_PRIVATE_KEY=0x_your_private_key_here
```

3. **Get test ETH** from [Base Sepolia faucet](https://sepoliafaucet.com/)

## Step 2: Install Dependencies

```bash
pnpm install
```

## Step 3: Deploy Contracts

Run the deployment script:

```bash
npx hardhat run scripts/deploy-sepolia.ts --network baseSepolia
```

## Step 4: Verify Contracts (Optional)

To verify contracts on BaseScan for transparency:

```bash
npx hardhat run scripts/verify-sepolia.ts --network baseSepolia
```

## Step 5: Check Results

After deployment completes, you'll see:
- Contract addresses in the console
- A `deployments/baseSepolia.json` file with all addresses

## Example Output

```
🚀 Deploying YieldBox contracts to Base Sepolia testnet...
📦 Deploying ERC6551Registry...
✅ ERC6551Registry deployed to: 0x1234567890123456789012345678901234567890
📦 Deploying ERC6551Account...
✅ ERC6551Account deployed to: 0x2345678901234567890123456789012345678901
...
🎉 All contracts deployed successfully!

📋 Deployment Summary:
================
ERC6551Registry: 0x1234567890123456789012345678901234567890
ERC6551Account: 0x2345678901234567890123456789012345678901
OpenCrateStrategyRegistry: 0x3456789012345678901234567890123456789012
...
================

💾 Deployment saved to: deployments/baseSepolia.json
🎉 Deployment complete!
```

## Troubleshooting

### "Insufficient funds" error
- Get more test ETH from the faucet
- Check your account balance on Base Sepolia explorer

### "Network not configured" error
- Ensure you're using the correct network name: `baseSepolia`
- Check your hardhat.config.ts has the baseSepolia network

### "Private key invalid" error
- Make sure your private key starts with `0x`
- Check that the private key is 64 characters long (excluding `0x`)

## Next Steps

1. **Run tests** to verify everything works:
```bash
npx hardhat test
```

2. **Check deployed contracts** on [Base Sepolia Explorer](https://sepolia.basescan.org/)

3. **Verify contracts** on BaseScan (if not done already):
```bash
npx hardhat run scripts/verify-sepolia.ts --network baseSepolia
```

3. **Use the contract addresses** from `deployments/baseSepolia.json` in your frontend

## Need Help?

- Check the full `DEPLOYMENT.md` for detailed instructions
- Review the test file to understand contract usage
- Check Hardhat documentation for network configuration