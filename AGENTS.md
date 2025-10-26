# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Project Structure

This is a monorepo with two main projects:
- `yieldbox-fe/` - Next.js frontend with Web3 integration
- `yieldbox-contract-hardhat/` - Hardhat smart contract project

## Critical Commands

### Frontend (yieldbox-fe/)
- `npm run dev` - Development server with Turbopack
- `npm run build` - Production build with Turbopack
- `npm run type-check` - TypeScript type checking (required before commits)
- `npm run lint` - ESLint (runs on pre-push hook)
- `npm run format` - Prettier formatting

### Contracts (yieldbox-contract-hardhat/)
- `npx hardhat test` - Run all tests (uses node:test runner, not Mocha)
- `npx hardhat test solidity` - Run only Solidity tests
- `npx hardhat test nodejs` - Run only TypeScript integration tests
- `npx hardhat run scripts/deploy-sepolia.ts --network baseSepolia` - Deploy to testnet
- `npx hardhat run scripts/verify-sepolia.ts --network baseSepolia` - Verify contracts

## Non-Obvious Conventions

### Frontend
- Uses Turbopack for both dev and build (not standard Next.js)
- WalletConnect Project ID must be set in `.env.local` or app shows warnings
- Path alias `@/*` maps to `./src/*` (configured in tsconfig.json)
- All UI components use Radix UI primitives with custom styling
- Web3 configuration in `src/wagmi.ts` uses RainbowKit v2 with multiple chains
- Wagmi config includes transports parameter for all configured chains
- Git hooks enforce type checking, linting, and successful build before push

### Contracts
- Uses Hardhat 3 Beta with native Node.js test runner (`node:test`)
- Tests use Viem library, not ethers.js
- Solidity 0.8.28 with viaIR optimization enabled
- Environment variables must be set in `.env` (copy from `.env.example`)
- Deployment saves addresses to `deployments/baseSepolia.json`
- Contract verification requires both ETHERSCAN_API_KEY and BASESCAN_API_KEY

### Testing Patterns
- Frontend: No test framework configured (add your preferred one)
- Contracts: Uses `node:test` with `assert` module, not Mocha/Chai
- Contract tests deploy fresh contracts for each test suite
- Test environment setup includes mock tokens and yield adapters

## Gotchas

- Frontend build will fail without WalletConnect Project ID
- Contract tests require Base Sepolia network configuration
- Hardhat uses ES modules (`"type": "module"` in package.json)
- Pre-commit hooks run automatically via Husky
- Contract deployment scripts expect specific environment variable names