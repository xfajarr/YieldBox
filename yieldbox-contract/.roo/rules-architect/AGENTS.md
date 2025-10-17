# Project Architecture Rules (Non-Obvious Only)

- OpenCrate is an NFT-based yield farming protocol where each NFT represents a yield position
- The protocol uses ERC-6551 Token Bound Accounts to associate each NFT with a smart contract wallet
- CrateManager is the central contract that orchestrates between NFTs, strategy vaults, and users
- mintCrate() and redeemCrate() functions are intentionally incomplete - they require ERC-6551 integration
- The architecture supports multiple strategy vaults (Aave, etc.) but only MockStrategyVault exists
- Performance fees are mentioned in comments but not implemented in the current codebase