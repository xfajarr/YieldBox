# Project Architecture Rules (Non-Obvious Only)

## System Architecture
- Monorepo with frontend (Next.js) and smart contracts (Hardhat) as separate projects
- Frontend reads deployed contract addresses from `deployments/baseSepolia.json` after deployment
- Base Sepolia testnet is the only configured network - no mainnet or other testnets
- Web3 integration uses Wagmi + Viem + RainbowKit stack (not ethers.js)
- Smart contracts use ERC6551 for token-bound accounts with custom yield adapters

## Critical Architectural Constraints
- Frontend build fails without WalletConnect Project ID but doesn't crash during development
- Contract deployment must be done before frontend can interact with contracts
- All contract tests use Viem library - ethers.js is not available in the project
- Hardhat 3 Beta with native Node.js test runner - not the standard Mocha setup
- Solidity 0.8.28 with viaIR optimization enabled - affects gas optimization patterns

## Data Flow Architecture
- Frontend → Wagmi → Viem → Base Sepolia Network → Smart Contracts
- Contract deployment → JSON file → Frontend reads addresses → Web3 interactions
- Test environment deploys fresh contracts for each test suite via setupEnvironment()
- Mock tokens and yield adapters are deployed for each test run

## Integration Points
- Contract addresses flow from `deployments/baseSepolia.json` to frontend Web3 config
- Environment variables are split between projects (.env vs .env.local)
- Git hooks enforce quality gates across both projects
- Both projects use TypeScript but with different configurations and build systems

## Performance Considerations
- Frontend uses Turbopack for faster development builds
- Contracts use viaIR optimization for better gas efficiency
- Viem library is used throughout for better performance than ethers.js
- Radix UI primitives for frontend component performance