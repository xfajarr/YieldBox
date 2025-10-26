# YieldBox Monorepo 🚀

YieldBox is a composable launchpad for token-bound DeFi NFTs. It blends a wallet-aware Next.js application with a Hardhat-powered Solidity stack so teams can design strategies, mint token-bound accounts, and orchestrate on-chain cash flows from a single codebase.

## ✨ Product Snapshot

- Curate DeFi yield "crates" with configurable fees, lockups, and supported payment tokens.
- Mint ERC-6551 powered NFTs that each own their own smart account and deployed strategy payload.
- Give operators an admin cockpit for crafting templates while letting users mint and manage positions with a few clicks.
- Target Base Sepolia out of the box, with scripts and artifacts ready for live network deployment and verification.

## 🏗️ Architecture Overview

```
                +-----------------------------+
                |  HyperIndex / GraphQL API   |
                |  (template + token metadata)|
                +--------------+--------------+
                               ^
                               |
Frontend (Next.js 15, React 19)|    wagmi + viem RPC calls
RainbowKit wallet UX           |    (wallet actions, reads)
                               |
                               v
+--------------+------------------------------+
|          Base Sepolia Network               |
|  OpenCrateFactory ⚙  -> mints OpenCrateNFTs |
|  ERC6551Account 🧠  -> token-bound accounts  |
|  Strategy Registry 📚 -> reusable strategies |
+---------------------------------------------+
```

Core concepts:
- **Templates:** Admin-defined blueprints (price, allocations, fees, disclosures, supported tokens).
- **Token-bound NFTs:** Each minted NFT spawns an ERC-6551 smart account that can custody DeFi positions.
- **Indexer:** Frontend pulls template, token, and crate data from a HyperIndex instance for fast reads.
- **Wallet UX:** Users connect via WalletConnect/RainbowKit, preview strategies, and sign mint transactions in real time.

## 🔁 End-to-End Flow

1. 🛠 Admin connects their wallet, fills out the template form, and calls `OpenCrateFactory.createTemplate`.
2. 🧠 Strategy and supported token metadata sync to the indexer for fast consumption in the UI.
3. 👀 Users browse curated strategies, compare allocations, and pick their preferred lockup multiplier.
4. 📨 Mint action signs a transaction through wagmi; the factory mints an `OpenCrateNFT`, wires fees, and registers an ERC-6551 account.
5. 📬 Frontend waits for confirmation, refreshes the indexer data, and surfaces the fresh token-bound account details.

## 📦 Repository Layout

```
yieldbox-fe/
  src/                Next.js app router, features, wagmi config, UI components
  public/             Static assets
  ...                 Tailwind, Husky, and build tooling

yieldbox-contract-hardhat/
  contracts/          Solidity sources (OpenCrate suite, ERC-6551, mocks)
  scripts/            Deploy, verify, and operational scripts
  test/               Node:test suites exercising deployments and flows
  deployments/        Generated deployment outputs (ignored until scripts run)
```

## 🛠️ Prerequisites

- Node.js 20 or newer (Next.js 15 and Hardhat 3 rely on modern Node features).
- npm (all scripts assume npm; swap to pnpm or yarn only if you reconfigure).
- Git with Husky hooks enabled (`npm install` triggers `husky install`).
- For on-chain work: a funded Base Sepolia account plus Etherscan and BaseScan API keys.

## 🚀 Getting Started

```bash
git clone <repo-url>
cd YieldBox

# Frontend setup
cd yieldbox-fe
npm install
cp .env.example .env.local   # populate WalletConnect project ID and indexer URL
npm run dev                  # launches Next.js with Turbopack

# Contracts setup
cd ../yieldbox-contract-hardhat
npm install
cp .env.example .env         # fill Base Sepolia RPC/private key + API keys
npx hardhat test             # runs Node:test suites via viem
```

Note: Turbopack powers both `npm run dev` and `npm run build`, so logs differ from classic Next.js builds.

## 🖥️ Frontend (`yieldbox-fe`)

- **Stack:** Next.js App Router, React 19, Tailwind CSS v4, Radix UI, RainbowKit v2, wagmi, viem, TanStack Query.
- **Features:**
  - Wallet-aware routing and themeable UI built on Radix primitives.
  - DeFi NFT catalogue with detail sheets, mint flows, and token support introspection.
  - Admin workspace for creating templates and feeding data into the indexer.
  - Toast-driven transaction UX via wagmi hooks and on-chain receipts.
- **Core commands:**
  - `npm run dev` - Turbopack development server.
  - `npm run build` - Production bundle (requires WalletConnect env).
  - `npm run type-check` - Required by git hooks before commits.
  - `npm run lint` / `npm run format` - ESLint and Prettier workflows.
- **Key environment variables:**
  - `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID` - Needed for RainbowKit to initialize.
  - `NEXT_PUBLIC_INDEXER_URL` - GraphQL endpoint that hydrates template/token data.

## 🔐 Smart Contracts (`yieldbox-contract-hardhat`)

- **Stack:** Hardhat 3 (ESM), Solidity 0.8.28 with viaIR, viem toolbox, forge-std, TokenBound SDK.
- **Contract suite:**
  - `OpenCrateFactory.sol` - Template registry, payment handling, NFT minting, lockup logic.
  - `OpenCrateNFT.sol` - ERC-6551 friendly NFT that links to strategy payloads.
  - `ERC6551Account.sol` - Token-bound smart account implementation.
  - `MockPriceOracle.sol` - Deterministic price feeds for tests.
  - `strategies/OpenCrateStrategyRegistry.sol` - Manages reusable strategy metadata.
- **Scripts:**
  - `scripts/deploy.ts` - Deploy to local/custom networks.
  - `scripts/deploy-sepolia.ts` - One-command Base Sepolia deployment.
  - `scripts/verify-sepolia.ts` - Verify contracts with Etherscan/BaseScan.
  - `scripts/test-purchase.ts` - Exercise crate purchase flow against deployed instances.
- **Testing:**
  - `npx hardhat test` - Runs Node:test suites (no Mocha/Chai) with fresh deployments per describe block.
  - `npx hardhat test solidity` / `npx hardhat test nodejs` - Target Solidity or TypeScript tests.
- **Required env vars (`.env`):**
  - `BASE_SEPOLIA_RPC_URL` and `BASE_SEPOLIA_PRIVATE_KEY` - RPC endpoint plus funded key.
  - `ETHERSCAN_API_KEY` and `BASESCAN_API_KEY` - Contract verification credentials.
  - Optional `SEPOLIA_*` variables if you cross-compile for Ethereum Sepolia.

## 🧰 Development Workflow Tips

- Husky gates pushes with `npm run type-check`, `npm run lint`, and `npm run build`; keep both workspaces clean.
- Web3 config in `src/wagmi.ts` must define transports for every supported chain to avoid runtime errors.
- Hardhat uses `configVariable`, so missing env vars fail fast - populate `.env` before running scripts.
- Indexer responses power most UI views; when working offline, mock the GraphQL responses or adjust hooks.
- WalletConnect integration requires a valid project ID in both dev and build environments.

## 🩺 Troubleshooting

- **Frontend build fails immediately:** Confirm `NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID` in `.env.local`.
- **`configVariable` throws:** Double-check `.env` inside `yieldbox-contract-hardhat`.
- **Unexpected gas estimates:** viaIR can change gas patterns; tune optimizer runs or enable tracing.
- **Node:test finds no files:** Ensure tests live in `yieldbox-contract-hardhat/test` and use the Node test API.

## 🤝 Contributing

1. Fork and branch (for example `feat/your-feature`).
2. Keep workspace changes isolated; run `npm run type-check && npm run lint` in the front end and `npx hardhat test` for contracts.
3. Update docs whenever ABIs, scripts, or env requirements change.
4. Open a pull request with context on migrations, UI flows, or contract interfaces.

## 📄 License

Add license details here (MIT, Apache 2.0, etc.) once the project licensing is finalized.
