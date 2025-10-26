# Project Documentation Rules (Non-Obvious Only)

## Documentation Structure
- Frontend docs are in `yieldbox-fe/README.md` - comprehensive setup and usage guide
- Contract docs are split between `yieldbox-contract-hardhat/README.md` and `USAGE.md`
- `USAGE.md` contains step-by-step deployment instructions with troubleshooting
- `DEPLOYMENT.md` (in contracts dir) has detailed deployment procedures
- Contract API documentation is in `docs/CONTRACT-DOCUMENTATION.md`

## Key Documentation Sources
- Frontend Web3 setup: Check `yieldbox-fe/src/wagmi.ts` for network configuration
- Contract architecture: `yieldbox-contract-hardhat/docs/OpenCrate-Documentation.md`
- Quick reference: `yieldbox-contract-hardhat/docs/Quick-Reference.md`
- Token minting guide: `yieldbox-contract-hardhat/docs/TOKEN-MINTING-GUIDE.md`
- Blockscout usage: `yieldbox-contract-hardhat/docs/BLOCKSCOUT-GUIDE.md`

## Counterintuitive Organization
- Contract tests use Node.js native test runner, not Hardhat's default Mocha
- Frontend uses Turbopack instead of standard Next.js webpack build system
- Environment variables are split: `.env` for contracts, `.env.local` for frontend
- Base Sepolia is the only configured network despite having Ethereum Sepolia config
- Deployment addresses are saved to JSON, not hardcoded or stored in env vars

## Hidden Dependencies
- Frontend requires WalletConnect Project ID or shows warnings but doesn't fail
- Contract verification needs both ETHERSCAN_API_KEY and BASESCAN_API_KEY
- Git hooks enforce type checking, linting, and successful build before pushes
- Hardhat uses ES modules (`"type": "module"`) which affects import syntax
- Viem library is used instead of ethers.js throughout the project