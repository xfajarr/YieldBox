# Project Debug Rules (Non-Obvious Only)

## Frontend Debugging
- WalletConnect warnings appear in console if NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID is not set
- Web3 connection failures are logged via RainbowKit's built-in error handling
- Turbopack build errors show detailed stack traces in dev server output
- Pre-commit hooks run automatically - check `.husky/pre-push` for debugging hook failures

## Contract Debugging
- Hardhat uses Viem, not ethers.js - all debugging must use Viem's error patterns
- Contract test failures use Node.js `assert` module error format, not Mocha/Chai
- Base Sepolia testnet RPC failures require checking BASE_SEPOLIA_RPC_URL in .env
- Contract verification fails silently if ETHERSCAN_API_KEY or BASESCAN_API_KEY are missing
- Deployment scripts write to `deployments/baseSepolia.json` - check this file for deployed addresses

## Common Debug Scenarios
- Frontend build failures: Check for missing WalletConnect Project ID first
- Contract test failures: Verify Base Sepolia network configuration in hardhat.config.ts
- Git hook failures: Run `npm run type-check` and `npm run lint` manually to see specific errors
- Deployment failures: Ensure private key starts with `0x` and account has test ETH
- Integration issues: Frontend expects contract addresses in `deployments/baseSepolia.json`

## Debug Tools
- Use `npx hardhat test nodejs` for TypeScript test debugging
- Use `npx hardhat test solidity` for Solidity test debugging
- Frontend errors appear in browser console and Turbopack dev server output
- Contract events can be decoded using Viem's `decodeEventLog` function