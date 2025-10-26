# Frontend → Smart Contract Functions Reference

This document lists the on-chain functions used by the frontend, grouped by read vs. write operations, access requirements, and typical UI use-cases. Each function entry links to its Solidity definition for quick reference.

Contracts
- [OpenCrateFactory.sol](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol)
- [OpenCrateNFT.sol](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol)
- Deployment addresses: [baseSepolia-improved.json](yieldbox-contract-hardhat/deployments/baseSepolia-improved.json) or [baseSepolia.json](yieldbox-contract-hardhat/deployments/baseSepolia.json)

Network
- Base Sepolia (chainId 84532). Configure Wagmi transports in [wagmi.ts](yieldbox-fe/src/wagmi.ts).

---

## Read functions (public, no transaction)

OpenCrateFactory
- [OpenCrateFactory.getTemplateIds()](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:495)
  - Returns all template IDs created.
- [OpenCrateFactory.getActiveTemplateIds()](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:499)
  - Returns currently active template IDs (basePriceUsd > 0).
- [OpenCrateFactory.getCrateTemplate(uint256)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:474)
  - Loads template details (name, description, risk, strategy, fees, positions, supported payment tokens).
- [OpenCrateFactory.getLockupOptions(uint256)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:482)
  - Returns full list of lockup options for a template.
- [OpenCrateFactory.getLockupOption(uint256,uint64)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:478)
  - Returns a specific lockup option for duration (seconds).
- [OpenCrateFactory.calculatePurchasePrice(uint256,uint64)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:528)
  - Computes final USD price (2 decimals), multiplierBps, and requiredTokenAmounts[] aligned with template.supportedPaymentTokens.
- [OpenCrateFactory.getCratePurchase(uint256)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:524)
  - Historical purchase record for a tokenId.
- [OpenCrateFactory.nextTemplateId()](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:558)
- [OpenCrateFactory.totalTemplates()](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:562)

OpenCrateNFT
- [OpenCrateNFT.crateInfo(uint256)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:606)
  - Returns crate metadata (risk, strategy, ERC6551 account, lock status, fees, lifecycle, payment info).
- [OpenCrateNFT.getPositions(uint256)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:676)
  - Returns detailed position metrics for the token.
- [OpenCrateNFT.positionsCount(uint256)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:687)
- [OpenCrateNFT.nextTokenId()](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:613)
- [OpenCrateNFT.totalMinted()](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:617)
- [OpenCrateNFT.tokenURI(uint256)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:621)
  - Returns metadata URL if baseURI is set.
- [OpenCrateNFT.getSupportedToken(address)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:523)
- [OpenCrateNFT.getWhitelistedTokens()](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:529)

---

## Write functions (user wallet transaction)

Purchasing via Factory (primary user flow)
- [OpenCrateFactory.purchaseCrate(uint256,uint64,address,uint256,uint256)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:338)
  - Flow:
    1) Read price with [OpenCrateFactory.calculatePurchasePrice(uint256,uint64)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:528).
    2) Approve ERC20 (USDC 6 decimals or IDRX 2 decimals) to factory.
    3) Call this function with matching paymentToken and paymentAmount.
  - Validates supported paymentToken, lockup option, amount, slippage; transfers payment to treasury; mints ERC721 crate via NFT.

Post-purchase crate lifecycle (owner or approved)
- [OpenCrateNFT.extendLock(uint256,uint64)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:373)
  - Requires owner/approved or factory; enforces min 1 day and overall max lock from now.
- [OpenCrateNFT.setBoostStatus(uint256,bool,uint16)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:652)
  - Set boost active flag; validates boost BPS within [MIN_BOOST_BPS..MAX_BOOST_BPS].
- [OpenCrateNFT.setBoostMultiplier(uint256,uint16)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:638)
  - Enable boost and set multiplier; validates BPS.
- [OpenCrateNFT.updatePositions(uint256,PositionPayload[])](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:668)
  - Replace position metrics (allocationBps validated; totalBps ≤ MAX_BPS).
- [OpenCrateNFT.updateLifecycle(uint256,uint64,uint64,uint256)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:691)
  - Update lifecycle timestamps and accrued yield USD.
- [OpenCrateNFT.updateRevenueShare(uint256,uint16,uint16,uint16)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:710)
  - Update fees (sum ≤ MAX_BPS).
- [OpenCrateNFT.updateDisclosures(uint256,string,string)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:730)
  - Update risk/fee disclosures.

Notes
- Lock and boost updates are guarded by authorization checks; the UI should ensure the connected wallet is owner/approved or use factory-admin flows where appropriate.
- For all writing flows using Wagmi, addresses should be typed as \`0x\${string}\`, ABIs imported from json files, and amounts provided using Viem’s parseUnits with correct token decimals.

---

## Admin functions (restricted to contract owner)

Factory admin
- [OpenCrateFactory.createCrateTemplate(...)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:157)
- [OpenCrateFactory.updateCrateTemplate(...)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:209)
- [OpenCrateFactory.addLockupOption(uint256,uint64,uint16)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:265)
- [OpenCrateFactory.updateLockupOption(uint256,uint64,uint16)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:282)
- [OpenCrateFactory.removeLockupOption(uint256,uint64)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:296)
- [OpenCrateFactory.disableCrateTemplate(uint256)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:318)
- [OpenCrateFactory.setTreasury(address)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:136)
- [OpenCrateFactory.pause()](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:146) / [OpenCrateFactory.unpause()](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:153)
- [OpenCrateFactory.emergencyWithdrawToken(address,uint256,address)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:570)
- [OpenCrateFactory.emergencyPauseTemplate(uint256)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:576) / [OpenCrateFactory.emergencyUnpauseTemplate(uint256)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:585)

NFT admin
- [OpenCrateNFT.addSupportedToken(address,uint256,uint8)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:493)
- [OpenCrateNFT.removeSupportedToken(address)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:509)
- [OpenCrateNFT.updateTokenPrice(address,uint256)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:514)
- [OpenCrateNFT.setBaseURI(string)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:477)
- [OpenCrateNFT.setFactory(address)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:471)
- [OpenCrateNFT.setDefaultRoyalty(address,uint96)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:482) / [OpenCrateNFT.deleteDefaultRoyalty()](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:489)
- [OpenCrateNFT.toggleEmergencyMode()](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:220) / [OpenCrateNFT.emergencyUnlock(uint256)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:243)

---

## Events (for UI observability)

Factory
- [event CrateTemplateCreated](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:88)
- [event CrateTemplateUpdated](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:89)
- [event CrateTemplateDisabled](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:90)
- [event LockupOptionAdded](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:91)
- [event LockupOptionUpdated](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:92)
- [event LockupOptionRemoved](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:93)
- [event CratePurchased](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:78)

NFT
- [event CrateMinted](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:136)
- [event PriceUpdated](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:148)
- [event BoostUpdated](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:149)
- [event BoostStatusUpdated](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:175)
- [event LockExtended](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:150)
- [event PositionsUpdated](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:151)
- [event PositionMetricsUpdated](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:156)
- [event LifecycleUpdated](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:161)
- [event RevenueShareUpdated](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:167)
- [event RiskDisclosureUpdated](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:173)
- [event FeeDisclosureUpdated](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:174)
- [event TokenAdded](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:180) / [event TokenRemoved](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:181) / [event TokenPriceUpdated](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:182)
- [event EmergencyModeToggled](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:183) / [event EmergencyUnlock](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:184)

---

## Data and decimals

- USD values in protocol use 2 decimals (cents). See [OpenCrateNFT.USD_DECIMALS](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:17).
- Boost multipliers are in basis points (bps). Validated in [OpenCrateNFT._validateBoost(uint16)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:770) and factory multiplier constraints.
- Payment tokens:
  - USDC uses 6 decimals.
  - IDRX uses 2 decimals.
- Required token amounts from [OpenCrateFactory.calculatePurchasePrice(uint256,uint64)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:528) align with `supportedPaymentTokens` order in the template. Display accordingly.

---

## Typical frontend flows

Browse templates
- Read IDs via [OpenCrateFactory.getTemplateIds()](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:495) or [OpenCrateFactory.getActiveTemplateIds()](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:499).
- For each ID, load via [OpenCrateFactory.getCrateTemplate(uint256)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:474) and [OpenCrateFactory.getLockupOptions(uint256)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:482).

Price calculation and purchase
- Compute price using [OpenCrateFactory.calculatePurchasePrice(uint256,uint64)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:528).
- Approve ERC20 then call [OpenCrateFactory.purchaseCrate(uint256,uint64,address,uint256,uint256)](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol:338).

Post-purchase display
- Derive the new tokenId from [OpenCrateNFT.nextTokenId()](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:613) minus one right after purchase.
- Load crate via [OpenCrateNFT.crateInfo(uint256)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:606), positions via [OpenCrateNFT.getPositions(uint256)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:676).

Owner actions
- Lock extension: [OpenCrateNFT.extendLock(uint256,uint64)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:373).
- Boost controls: [OpenCrateNFT.setBoostStatus(uint256,bool,uint16)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:652), [OpenCrateNFT.setBoostMultiplier(uint256,uint16)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:638).
- Position and lifecycle updates: [OpenCrateNFT.updatePositions(uint256,PositionPayload[])](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:668), [OpenCrateNFT.updateLifecycle(uint256,uint64,uint64,uint256)](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol:691).

Admin UI (restricted)
- Template management and lockup options via factory admin functions above.
- Token support management via NFT admin functions above.

---

## Integration notes

- Use Wagmi hooks with Viem utils (parseUnits/formatUnits). Ensure correct decimals when approving/purchasing.
- Ensure RainbowKit v2 transports configured for Base Sepolia.
- Respect authorization: many write functions require factory or token owner/approval; the UI must check wallet ownership before enabling controls.