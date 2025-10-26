# YieldBox Frontend ↔ Smart Contracts Integration Guide

This guide explains how the Next.js frontend integrates with the OpenCrate smart contracts deployed on Base Sepolia, using Wagmi + RainbowKit v2 and Viem. It follows project rules in [AGENTS.md](AGENTS.md) and the monorepo conventions.

Key file references:
- [wagmi.ts](yieldbox-fe/src/wagmi.ts)
- [OpenCrateFactory.json](yieldbox-fe/src/contracts/abi/json/OpenCrateFactory.json)
- [OpenCrateNFT.json](yieldbox-fe/src/contracts/abi/json/OpenCrateNFT.json)
- [OpenCrateStrategyRegistry.json](yieldbox-fe/src/contracts/abi/json/OpenCrateStrategyRegistry.json)
- [addresses.ts](yieldbox-fe/src/contracts/addresses.ts)
- [baseSepolia-improved.json](yieldbox-contract-hardhat/deployments/baseSepolia-improved.json)
- [OpenCrateFactory.sol](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol)
- [OpenCrateNFT.sol](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol)

Note: The frontend reads deployed addresses from the contract deployment outputs. Prefer the canonical file [baseSepolia.json](yieldbox-contract-hardhat/deployments/baseSepolia.json). If your deployment script wrote to [baseSepolia-improved.json](yieldbox-contract-hardhat/deployments/baseSepolia-improved.json), copy/rename to match the convention or update the frontend to read the improved filename.

## 1. Prerequisites

- Contracts deployed to Base Sepolia (deployment script outputs saved to yieldbox-contract-hardhat/deployments/).
- Frontend environment configured with WalletConnect Project ID.
- ABIs available under yieldbox-fe/src/contracts/abi/json.
- Node 18+, Next.js app runs with Turbopack.

Environment variables (frontend):
- NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID — required for RainbowKit v2
- NEXT_PUBLIC_DEFAULT_CHAIN_ID (optional, 84532 for Base Sepolia)

## 2. Contract Addresses

Create a typed address map for the frontend. Place it in [addresses.ts](yieldbox-fe/src/contracts/addresses.ts).

Example content:
```ts
export const addresses = {
  baseSepolia: {
    OpenCrateFactory: "0x8a966e800ecd5025190f767232cb748f0917407b",
    OpenCrateNFT: "0xad9604b29a892a1f06bef534c4f5cea5fa729ca7",
    ERC6551Registry: "0xd81fd0e0efb5c8db4ba2b268896c2548416cb026",
    ERC6551Account: "0xcf49794cc85c8f4e2022b88127134ae2c206c402",
    OpenCrateStrategyRegistry: "0x47503954b7626724fdd0dd996ac1d69b8a7d124c",
    MockUSDC: "0x18d6b03a4a0499077a2dc8c45fff8da10af16f64",
    MockIDRX: "0x7aa2608eea7679fa66196decd78989bb13dacd38",
  },
} as const;
```

Tip: Instead of hardcoding, you can write a small build-time step in the frontend to read [baseSepolia.json](yieldbox-contract-hardhat/deployments/baseSepolia.json) and emit [addresses.ts](yieldbox-fe/src/contracts/addresses.ts) (or a JSON in public/) for runtime usage. Keep monorepo boundaries in mind (Next.js bundler may not allow reading outside the app at runtime).

## 3. Wagmi + RainbowKit v2 Setup

Configure Wagmi providers with transports for RainbowKit v2. File: [wagmi.ts](yieldbox-fe/src/wagmi.ts)

Example skeleton:
```ts
import { http, createConfig } from "wagmi";
import { baseSepolia } from "wagmi/chains";
import { getDefaultConfig } from "@rainbow-me/rainbowkit";

const wcProjectId = process.env.NEXT_PUBLIC_WALLETCONNECT_PROJECT_ID!;
export const wagmiConfig = createConfig(
  getDefaultConfig({
    appName: "YieldBox",
    projectId: wcProjectId,
    chains: [baseSepolia],
    transports: {
      [baseSepolia.id]: http("https://sepolia.base.org"), // or your RPC
    },
    ssr: true,
  })
);
```

Wrap providers in [providers.tsx](yieldbox-fe/src/app/providers.tsx) and [layout.tsx](yieldbox-fe/src/app/layout.tsx).

## 4. ABIs

Use ABIs shipped with the frontend:
- [OpenCrateFactory.json](yieldbox-fe/src/contracts/abi/json/OpenCrateFactory.json)
- [OpenCrateNFT.json](yieldbox-fe/src/contracts/abi/json/OpenCrateNFT.json)

Create contract descriptors:
```ts
import factoryAbi from "@/contracts/abi/json/OpenCrateFactory.json";
import nftAbi from "@/contracts/abi/json/OpenCrateNFT.json";
import { addresses } from "@/contracts/addresses";

export const contracts = {
  factory: {
    address: addresses.baseSepolia.OpenCrateFactory as `0x${string}`,
    abi: factoryAbi as const,
  },
  nft: {
    address: addresses.baseSepolia.OpenCrateNFT as `0x${string}`,
    abi: nftAbi as const,
  },
} as const;
```

## 5. Reading Template Price and Required Token Amounts

Use calculatePurchasePrice(templateId, lockupDuration) from [OpenCrateFactory.sol](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol) to compute USD price and token amounts.

```ts
import { useReadContract } from "wagmi";
import factoryAbi from "@/contracts/abi/json/OpenCrateFactory.json";
import { addresses } from "@/contracts/addresses";

export function useCalculatedPrice(templateId: bigint, lockupDuration: bigint) {
  return useReadContract({
    address: addresses.baseSepolia.OpenCrateFactory as `0x${string}`,
    abi: factoryAbi,
    functionName: "calculatePurchasePrice",
    args: [templateId, lockupDuration],
    query: { refetchOnWindowFocus: false },
  });
}
```

Returns: priceUsd (2 decimals), multiplierBps, requiredTokenAmounts[] aligned with template.supportedPaymentTokens order.

## 6. Purchasing a Crate (USDC)

Flow: read price -> approve USDC -> purchaseCrate.

```ts
import { parseUnits } from "viem";
import { useWriteContract } from "wagmi";
import factoryAbi from "@/contracts/abi/json/OpenCrateFactory.json";
import erc20Abi from "@/contracts/abi/erc20"; // ERC20 standard ABI
import { addresses } from "@/contracts/addresses";

export function usePurchaseCrateUSDC() {
  const factoryAddress = addresses.baseSepolia.OpenCrateFactory as `0x${string}`;
  const usdcAddress = addresses.baseSepolia.MockUSDC as `0x${string}`;

  const approveWrite = useWriteContract();
  const purchaseWrite = useWriteContract();

  async function purchase(templateId: bigint, lockDuration: bigint, usdcAmount: string) {
    const amount = parseUnits(usdcAmount, 6);

    await approveWrite.writeContract({
      address: usdcAddress,
      abi: erc20Abi,
      functionName: "approve",
      args: [factoryAddress, amount],
    });

    await purchaseWrite.writeContract({
      address: factoryAddress,
      abi: factoryAbi,
      functionName: "purchaseCrate",
      args: [templateId, lockDuration, usdcAddress, amount, amount], // maxPaymentAmount = amount for no slippage
    });
  }

  return { purchase, approveWrite, purchaseWrite };
}
```

## 7. Purchasing a Crate (IDRX)

Same pattern, 2 decimals.

```ts
import { parseUnits } from "viem";
import { useWriteContract } from "wagmi";
import factoryAbi from "@/contracts/abi/json/OpenCrateFactory.json";
import erc20Abi from "@/contracts/abi/erc20";
import { addresses } from "@/contracts/addresses";

export function usePurchaseCrateIDRX() {
  const factoryAddress = addresses.baseSepolia.OpenCrateFactory as `0x${string}`;
  const idrxAddress = addresses.baseSepolia.MockIDRX as `0x${string}`;

  const approveWrite = useWriteContract();
  const purchaseWrite = useWriteContract();

  async function purchase(templateId: bigint, lockDuration: bigint, idrxAmount: string) {
    const amount = parseUnits(idrxAmount, 2);

    await approveWrite.writeContract({
      address: idrxAddress,
      abi: erc20Abi,
      functionName: "approve",
      args: [factoryAddress, amount],
    });

    await purchaseWrite.writeContract({
      address: factoryAddress,
      abi: factoryAbi,
      functionName: "purchaseCrate",
      args: [templateId, lockDuration, idrxAddress, amount, amount],
    });
  }

  return { purchase, approveWrite, purchaseWrite };
}
```

## 8. Reading Crate Details

```ts
import { useReadContract } from "wagmi";
import nftAbi from "@/contracts/abi/json/OpenCrateNFT.json";
import { addresses } from "@/contracts/addresses";

export function useCrateInfo(tokenId: bigint) {
  return useReadContract({
    address: addresses.baseSepolia.OpenCrateNFT as `0x${string}`,
    abi: nftAbi,
    functionName: "crateInfo",
    args: [tokenId],
  });
}

export function useCratePositions(tokenId: bigint) {
  return useReadContract({
    address: addresses.baseSepolia.OpenCrateNFT as `0x${string}`,
    abi: nftAbi,
    functionName: "getPositions",
    args: [tokenId],
  });
}
```

## 9. Extending Lock / Boost Controls

Call writes on [OpenCrateNFT.sol](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol) via Wagmi:

- extendLock(tokenId, additionalDuration)
- setBoostStatus(tokenId, active, bps)
- setBoostMultiplier(tokenId, bps)

## 10. Chain and RPC

Ensure Base Sepolia (84532) and a stable RPC in [wagmi.ts](yieldbox-fe/src/wagmi.ts).

## 11. Project Conventions

- Use path alias @/* for imports
- Web3 via Wagmi + RainbowKit v2
- Viem for utilities (e.g., parseUnits)
- Strict TS types, addresses typed as `0x${string}`

## 12. Frontend Build & Run

- npm run dev — Turbopack development
- npm run build — production build
- npm run type-check — TypeScript
- npm run lint — ESLint
- npm run format — Prettier

## 13. Integration Checklist

- [ ] WalletConnect Project ID in `.env.local`
- [ ] Configure [wagmi.ts](yieldbox-fe/src/wagmi.ts) transports
- [ ] ABIs present in `src/contracts/abi/json/`
- [ ] Write [addresses.ts](yieldbox-fe/src/contracts/addresses.ts) from deployments
- [ ] Implement read hooks and approve + purchase flows
- [ ] Render crate details and lifecycle controls
- [ ] Validate chain/network in RainbowKit
- [ ] E2E purchase test in UI

## 14. Troubleshooting

- If Etherscan V1 errors appear, use Blockscout links (Base Sepolia).
- Regenerate ABIs from `yieldbox-contract-hardhat/artifacts` if mismatched.
- Sync latest deployments from [baseSepolia-improved.json](yieldbox-contract-hardhat/deployments/baseSepolia-improved.json).
- Ensure USDC (6) and IDRX (2) decimals when calling parseUnits.

## 15. References

- [OpenCrateFactory.sol](yieldbox-contract-hardhat/contracts/OpenCrateFactory.sol)
- [OpenCrateNFT.sol](yieldbox-contract-hardhat/contracts/OpenCrateNFT.sol)
- [verify-sepolia.ts](yieldbox-contract-hardhat/scripts/verify-sepolia.ts)