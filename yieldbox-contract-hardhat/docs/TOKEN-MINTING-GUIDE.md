# Token Minting Guide for YieldBox

This guide explains how users can mint/buy yield crates using supported tokens like USDC and IDRX.

## Overview

The YieldBox system has been enhanced to support direct token payments for minting yield crates. Users can now:

1. Browse available yield crates/templates
2. Select a crate and view details
3. Choose lockup duration with multiplier
4. Pay with supported tokens (USDC, IDRX)
5. Receive minted NFT crate

## Supported Tokens

### Mock USDC
- **Symbol**: USDC
- **Decimals**: 6
- **Price Oracle**: $1.00 USD
- **Contract**: MockUSDC.sol

### Mock IDRX
- **Symbol**: IDRX
- **Decimals**: 2
- **Price Oracle**: Rp 16,500 ($1.00 USD)
- **Contract**: MockIDRX.sol

## User Flow

### 1. Browse Available Crates

```typescript
// Get all active crate templates
const activeTemplateIds = await crateFactory.read.getActiveTemplateIds();

// Get details for each template
for (const templateId of activeTemplateIds) {
  const template = await crateFactory.read.getCrateTemplate([templateId]);
  console.log(`Template: ${template.name}`);
  console.log(`Base Price: $${formatUnits(template.basePriceUsd, 2)}`);
  console.log(`Risk Level: ${template.riskLevel}`);
  console.log(`Strategy: ${template.strategyId}`);
}
```

### 2. View Crate Details

```typescript
// Get detailed information about a specific crate
const template = await crateFactory.read.getCrateTemplate([templateId]);

// View lockup options
console.log("Available Lockup Options:");
for (const option of template.lockupOptions) {
  if (option.enabled) {
    const days = Number(option.duration) / 86400;
    const multiplier = Number(option.multiplierBps) / 10000;
    console.log(`${days} days: ${multiplier}x multiplier`);
  }
}

// View supported payment tokens
console.log("Supported Payment Tokens:");
for (const tokenAddress of template.supportedTokens) {
  const tokenInfo = await crateNFT.read.getSupportedToken([tokenAddress]);
  console.log(`Token: ${tokenAddress}, Decimals: ${tokenInfo.decimals}`);
}
```

### 3. Calculate Purchase Price

```typescript
// Calculate price for specific lockup duration
const lockupDuration = 90 * 86400; // 90 days
const [priceUsd, multiplierBps] = await crateFactory.read.calculatePurchasePrice([
  templateId,
  BigInt(lockupDuration)
]);

console.log(`Price: $${formatUnits(priceUsd, 2)}`);
console.log(`Multiplier: ${Number(multiplierBps) / 10000}x`);
```

### 4. Mint Crate with Token Payment

```typescript
// Approve token spending first
await usdcContract.write.approve([
  crateFactory.address,
  parseUnits("100", 6) // Amount to spend
]);

// Purchase crate
const tx = await crateFactory.write.purchaseCrate([
  templateId,
  BigInt(lockupDuration), // Lockup duration
  usdcContract.address, // Payment token
  parseUnits("100", 6) // Payment amount
]);

// Wait for transaction
const receipt = await publicClient.waitForTransactionReceipt({ hash: tx });

// Find CratePurchased event
const event = receipt.logs.find(log => {
  try {
    const decoded = decodeEventLog({
      abi: crateFactory.abi,
      eventName: "CratePurchased",
      data: log.data,
      topics: log.topics,
    });
    return decoded.eventName === "CratePurchased";
  } catch {
    return false;
  }
});

const tokenId = event.args.tokenId;
console.log(`Crate minted with token ID: ${tokenId}`);
```

## Contract Integration

### OpenCrateNFT

The enhanced NFT contract includes token support functionality:

#### Key Functions

- `addSupportedToken(address token, uint256 priceUsd, uint8 decimals)` - Add supported payment token
- `removeSupportedToken(address token)` - Remove supported payment token  
- `updateTokenPrice(address token, uint256 priceUsd)` - Update token price
- `getSupportedToken(address token)` - Get token information
- `getWhitelistedTokens()` - Get all supported tokens

#### Events

- `TokenAdded(address indexed token, uint256 priceUsd, uint8 decimals)`
- `TokenRemoved(address indexed token)`
- `TokenPriceUpdated(address indexed token, uint256 oldPriceUsd, uint256 newPriceUsd)`

### OpenCrateFactory

The enhanced factory handles template-based crate creation and token payments:

#### Key Functions

- `createCrateTemplate(...)` - Create new crate template with lockup options
- `purchaseCrate(uint256 templateId, uint256 duration, address paymentToken, uint256 paymentAmount)` - Purchase crate
- `calculatePurchasePrice(uint256 templateId, uint256 duration)` - Calculate price with multiplier
- `getCrateTemplate(uint256 templateId)` - Get template details
- `getActiveTemplateIds()` - Get all active templates

#### Events

- `CrateTemplateCreated(uint256 indexed templateId, string name, uint256 basePriceUsd)`
- `CratePurchased(uint256 indexed tokenId, uint256 templateId, address indexed buyer, address paymentToken, uint256 paymentAmount)`

## Lockup Duration and Multipliers

Templates can define multiple lockup options with different multipliers:

```typescript
const lockupOptions = [
  {
    duration: 30 * 86400,    // 30 days
    multiplierBps: 10000,     // 1.0x multiplier
    enabled: true
  },
  {
    duration: 90 * 86400,    // 90 days  
    multiplierBps: 12000,     // 1.2x multiplier
    enabled: true
  },
  {
    duration: 180 * 86400,   // 180 days
    multiplierBps: 15000,     // 1.5x multiplier
    enabled: true
  }
];
```

The multiplier increases the effective crate value:
- Base Price: $100
- 90-day lockup (1.2x): $120 effective value
- 180-day lockup (1.5x): $150 effective value

## Price Calculation

The system calculates token amounts based on USD price:

```typescript
// For USDC (6 decimals)
const usdcAmount = (priceUsd * 10^6) / tokenPriceUsd;

// For IDRX (18 decimals)  
const idrxAmount = (priceUsd * 10^18) / tokenPriceUsd;
```

## Security Features

### Token Validation
- Only whitelisted tokens can be used for payments
- Token prices are maintained in USD
- Decimal precision is handled correctly

### Payment Validation
- Sufficient balance checks
- Allowance verification
- Exact payment amount required

### Access Control
- Only owner can manage supported tokens
- Template creation is owner-controlled
- Purchase is open to anyone

## Testing

The test suite covers all token functionality:

```bash
# Run enhanced tests
npx hardhat test test/YieldBoxEnhanced.test.ts

# Run specific test
npx hardhat test test/YieldBoxEnhanced.test.ts --grep "Token Whitelisting"
```

## Deployment

Deploy the enhanced contracts:

```bash
# Deploy to Base Sepolia
npx hardhat run scripts/deploy-sepolia.ts --network baseSepolia

# Verify contracts
npx hardhat run scripts/verify-sepolia.ts --network baseSepolia
```

## Frontend Integration

### React Example

```typescript
import { useContractRead, useContractWrite } from 'wagmi';

// Fetch available templates
const { data: templates } = useContractRead({
  address: factoryAddress,
  abi: factoryAbi,
  functionName: 'getActiveTemplateIds'
});

// Purchase crate
const { write: purchaseCrate } = useContractWrite({
  address: factoryAddress,
  abi: factoryAbi,
  functionName: 'purchaseCrate'
});

// Handle purchase
const handlePurchase = async (templateId, duration, token, amount) => {
  await purchaseCrate([templateId, duration, token, amount]);
};
```

### UI Flow

1. **Template List**: Display all active templates with base prices
2. **Template Details**: Show lockup options and multipliers
3. **Payment Selection**: Choose from supported tokens
4. **Purchase**: Approve and execute transaction
5. **Confirmation**: Show minted NFT and details

## Error Handling

Common errors and their meanings:

- `TokenNotSupported`: Payment token is not whitelisted
- `InsufficientPayment`: Payment amount is too low
- `InvalidLockupDuration`: Lockup duration not available
- `TemplateNotFound`: Template ID is invalid
- `TransferFailed`: Token transfer failed

## Best Practices

1. **Always approve tokens before purchasing**
2. **Check token allowances before transactions**
3. **Verify lockup durations and multipliers**
4. **Handle transaction failures gracefully**
5. **Update UI based on transaction status**

## Future Enhancements

Potential improvements to the token system:

1. **Dynamic Pricing**: Token prices from oracles
2. **More Tokens**: Support for additional stablecoins
3. **Batch Operations**: Purchase multiple crates
4. **Subscription Model**: Recurring crate purchases
5. **Discount System**: Volume-based discounts
