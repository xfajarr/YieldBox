# YieldBox Monorepo

Composable infrastructure for launching and managing token-bound DeFi NFTs. This repository hosts both the Next.js front end and the Hardhat smart contract suite that power YieldBox end to end.

## Highlights

- Full-stack monorepo: Next.js 15 + React 19 UI and a Hardhat 3 (beta) Solidity workspace.
- Wallet-native UX with RainbowKit v2, wagmi, viem, and Radix UI components tailored for Web3 flows.
- Token-bound ERC-6551 architecture (_OpenCrateNFT_ + _ERC6551Account_) with factory orchestration and strategy registry integrations.
- Base Sepolia deployment pipeline with viaIR-optimized Solidity builds and automated verification scripts.

## Repository Layout

```
yieldbox-fe/                 # Next.js frontend (Turbopack build pipeline)
├─ src/                      # App router, features, Wagmi config, UI components
├─ public/                   # Static assets
└─ ...                       # Husky hooks, Tailwind config, etc.

yieldbox-contract-hardhat/   # Hardhat 3 + Viem smart contract workspace
├─ contracts/                # Solidity sources (ERC6551Account, OpenCrate, mocks)
├─ scripts/                  # Deploy, verify, and utility scripts
├─ test/                     # Node:test suites (per-suite fresh deployments)
└─ deployments/              # Generated deployment artifacts
```

## Prerequisites

- Node.js 20+ (Next.js 15 and Hardhat 3 expect modern Node features).
- npm (repo scripts assume npm; adapt to pnpm/yarn if preferred).
- Git configured with Husky hooks enabled (`npm install` runs `husky install` automatically).
- For smart contract work: funded Base Sepolia account and API keys for Etherscan/BaseScan.

## Getting Started

Clone the repository, install dependencies for each workspace, then run the front end and tests as needed.

```bash
git clone <repo-url>
cd YieldBox

# Frontend setup
cd yieldbox-fe
npm install
cp .env.example .env.local   # ensure WalletConnect + backend URLs are configured
npm run dev                  # launches Next.js with Turbopack

# Contracts setup
cd ../yieldbox-contract-hardhat
npm install
cp .env.example .env         # fill in Base Sepolia + API keys
npx hardhat test             # run Node:test suites via Viem
```

> Turbopack powers both `npm run dev` and `npm run build`; expect different logs than the default Next.js compiler.

## Frontend (`yieldbox-fe`)

- **Stack:** Next.js App Router, React 19, Tailwind CSS v4 (via experimental PostCSS), Radix UI primitives, RainbowKit v2, wagmi, viem, TanStack Query.
- **Key features:**
  - Wallet-aware interface with chain-aware transports defined in `src/wagmi.ts`.
  - Token-bound NFT discovery, minting, and management flows (`src/features/defi-nfts`).
  - Admin tooling for template creation and on-chain transaction orchestration.
  - Dynamic visual components (`hero-section`, `case-opening-modal`, etc.) backed by Tailwind utility layers.
- **Important commands**
  - `npm run dev` — Launch Turbopack dev server.
  - `npm run build` — Production build (fails without required env vars like the WalletConnect Project ID).
  - `npm run type-check` — TypeScript must pass before commits (enforced by hooks).
  - `npm run lint` / `npm run format` — Linting & formatting (pre-push hooks run lint + build).
- **Environment variables**
  - `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID` — Required for RainbowKit; missing value triggers runtime warnings and build failures.
  - `NEXT_PUBLIC_INDEXER_URL` — Backend/indexer endpoint used for NFT data hydration.

## Smart Contracts (`yieldbox-contract-hardhat`)

- **Stack:** Hardhat 3 (ESM), Solidity 0.8.28 with viaIR optimization, Viem-based toolbox, forge-std test utilities, TokenBound SDK.
- **Core contracts:**
  - `OpenCrateFactory.sol` — Deploys token-bound wallets and orchestrates templates.
  - `OpenCrateNFT.sol` — ERC-6551 compatible NFT that anchors DeFi strategies.
  - `ERC6551Account.sol` & registry bindings — Account implementation for token-bound operations.
  - `MockPriceOracle.sol` — Test oracle for strategy simulations.
- **Scripts:**
  - `scripts/deploy.ts` — Local or custom network deployments.
  - `scripts/deploy-sepolia.ts` — Deploys to Base Sepolia (uses env-configured RPC + key).
  - `scripts/verify-sepolia.ts` — Runs verification against Etherscan/BaseScan APIs.
  - `scripts/test-purchase.ts` — Utility script for exercising purchase flow post-deploy.
- **Testing:**
  - `npx hardhat test` — Runs all Node:test suites (no Mocha/Chai). Each suite deploys fresh contracts, sets up mock tokens and adapters.
  - `npx hardhat test solidity` / `npx hardhat test nodejs` — Filtered test runs.
- **Environment variables:** define RPC URLs, private keys, and API keys in `.env`.
  - `BASE_SEPOLIA_RPC_URL`, `BASE_SEPOLIA_PRIVATE_KEY` (required for anything on Base Sepolia).
  - `ETHERSCAN_API_KEY`, `BASESCAN_API_KEY` for verification.
  - Optional Ethereum Sepolia variables for cross-network references.

## Development Workflow Tips

- Husky hooks enforce `npm run type-check`, `npm run lint`, and a successful build before pushes—keep both workspaces green.
- When tweaking Web3 configuration (`src/wagmi.ts`), ensure transports are set for every chain to avoid runtime errors.
- Contract scripts use `configVariable` from Hardhat for environment safety; missing variables throw early.
- Frontend fetchers expect the indexer URL to be reachable; update mocks or `.env.local` when developing offline.
- WalletConnect integration requires a valid project ID on both dev and build; requests fail silently otherwise.

## Troubleshooting

- **Frontend build fails immediately:** double-check `.env.local` for `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID`.
- **Hardhat commands throw configVariable errors:** ensure the `.env` file exists and all required keys are populated.
- **Gas estimation quirks on Base Sepolia:** viaIR is enabled; consider adjusting optimizer runs or enabling tracing if debugging.
- **Node:test not discovering suites:** confirm files reside under `yieldbox-contract-hardhat/test` and use the built-in `node:test` API.

## Contributing

1. Fork and branch (`feat/your-feature`).
2. Keep changes isolated per workspace; run `npm run type-check && npm run lint` in the front end and `npx hardhat test` for contracts.
3. Update documentation if public APIs, contract ABIs, or environment requirements change.
4. Submit a pull request with context around smart contract migrations or front-end state changes.

## License

Add license details here (MIT, Apache 2.0, etc.) once the project’s licensing is finalized.

