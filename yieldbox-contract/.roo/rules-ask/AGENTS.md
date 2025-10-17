# Project Documentation Rules (Non-Obvious Only)

- README.md contains only generic Foundry documentation, not project-specific information
- AaveLending.sol in src/protocol/ is just a stub file with only SPDX and pragma lines
- The protocol is designed to use ERC-6551 Token Bound Accounts but implementation is incomplete
- CrateManager.sol contains extensive TODO comments (lines 96-181) that explain the intended implementation
- MockStrategyVault is not a real yield strategy - it simulates yield with simple time-based calculation