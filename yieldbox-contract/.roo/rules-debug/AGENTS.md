# Project Debug Rules (Non-Obvious Only)

- Foundry test files must use .t.sol extension and be placed in test/ directory (no test files exist yet)
- MockStrategyVault has hardcoded MOCK_APY of 1000 (10%) - adjust this value for different testing scenarios
- ERC-6551 Registry interface is incomplete (lines 11-14 in CrateManager.sol) - may cause runtime errors when implementing TBA functionality
- CrateManager constructor requires 4 addresses: _nftAddress, _depositTokenAddress, _treasuryAddress, _registryAddress
- OpenCrateNFT._createPosition can only be called by the crateManager address - set this before testing minting