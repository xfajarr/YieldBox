# Project Coding Rules (Non-Obvious Only)

## Frontend (yieldbox-fe/)
- Always use `cn()` utility from `src/lib/utils.ts` for className merging (combines clsx and tailwind-merge)
- Web3 components must use Wagmi hooks from `wagmi` and RainbowKit v2 components
- All UI components should be built with Radix UI primitives from `@radix-ui/*`
- Path alias `@/*` is configured to map to `./src/*` - use it consistently
- Component files should be in `src/components/` and exported via `src/components/index.ts`
- Environment variables must be prefixed with `NEXT_PUBLIC_` for client-side access
- Wagmi config must include transports parameter for all configured chains (RainbowKit v2 requirement)

## Contracts (yieldbox-contract-hardhat/)
- Use Viem library for all Ethereum interactions, not ethers.js
- Contract tests must use `node:test` runner with `assert` module, not Mocha/Chai
- Solidity version is 0.8.28 with viaIR optimization enabled in hardhat.config.ts
- Test environment setup requires deploying mock tokens and yield adapters for each test suite
- Contract deployment scripts save addresses to `deployments/baseSepolia.json`
- Use `parseUnits()` from Viem for handling token decimals, not manual calculations

## Cross-Project Integration
- Frontend reads contract addresses from `deployments/baseSepolia.json` after contract deployment
- Both projects use TypeScript with strict mode enabled
- Environment variables for contracts go in `.env`, frontend uses `.env.local`
- Base Sepolia testnet is the only configured network for development