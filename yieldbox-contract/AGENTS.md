# AGENTS.md

This file provides guidance to agents when working with code in this repository.

## Build/Test Commands
- Build: `forge build`
- Test: `forge test` (no test files exist yet)
- Format: `forge fmt`
- Gas snapshots: `forge snapshot`

## Project Architecture
OpenCrate is an NFT-based yield farming protocol built with Foundry. The architecture consists of:
- `OpenCrateNFT`: ERC721 tokens representing yield positions
- `CrateManager`: Main contract handling crate creation, minting, and redemption
- `IStrategyVault`: Interface for yield strategies (Aave, etc.)
- `MockStrategyVault`: Testing implementation with simulated APY

## Critical Non-Obvious Patterns
1. **ERC-6551 Integration**: The protocol uses Token Bound Accounts (TBAs) for each NFT, but the implementation is incomplete in `CrateManager.sol` (see TODO comments in lines 128-157)
2. **Custom Access Control**: `CrateManager.sol` has both `Ownable` and `onlyOwner` modifiers (lines 68-80) - this is redundant and should be consolidated
3. **Version Inconsistency**: `OpenCrateNFT.sol` uses pragma ^0.8.24 while others use ^0.8.20/^0.8.28 - this could cause compilation issues
4. **Incomplete Implementation**: `mintCrate` and `redeemCrate` functions in `CrateManager.sol` are incomplete (see TODO comments)
5. **Interface Mismatch**: `CrateInfo` struct has `asset` field but `addCrate` function doesn't set it (line 89)

## Code Style Guidelines
- Uses custom errors instead of revert strings (gas optimization)
- Events follow indexed parameters pattern
- SPDX identifiers required
- OpenZeppelin contracts imported for standard functionality
- Foundry project structure with src/, test/, script/ directories

## Testing Notes
- No test files exist yet
- MockStrategyVault provides testing utilities with simulated APY
- Tests should be placed in test/ directory with .t.sol extension