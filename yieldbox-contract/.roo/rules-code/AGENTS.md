# Project Coding Rules (Non-Obvious Only)

- ERC-6551 Token Bound Account implementation is incomplete in CrateManager.sol (lines 128-157) - this is the core functionality that needs to be implemented
- CrateManager.sol has redundant access control modifiers (Ownable and onlyOwner on lines 68-80) - only one should be used
- OpenCrateNFT.sol uses pragma ^0.8.24 while other contracts use ^0.8.20/^0.8.28 - version mismatch must be resolved
- CrateInfo struct has an `asset` field (line 41) but addCrate function doesn't set it - this will cause issues when the asset differs from underlyingAsset
- MockStrategyVault uses simplified yield calculation that doesn't compound - only suitable for basic testing