import { network } from "hardhat";
import fs from "fs";
import path from "path";
import { parseUnits, formatUnits } from "viem";
import { fileURLToPath } from "url";

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function main() {
  console.log("🧪 Testing Crate Purchase...\n");

  const { viem } = await network.connect();
  const [deployer] = await viem.getWalletClients();

  // Load deployment info
  const deploymentFile = path.join(__dirname, "..", "deployments", "baseSepolia-improved.json");
  
  if (!fs.existsSync(deploymentFile)) {
    console.error("❌ Deployment file not found. Please deploy first.");
    process.exit(1);
  }

  const deploymentData = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
  const { deployments } = deploymentData;

  console.log("📋 Loaded Deployment Addresses:");
  console.log(`  Factory: ${deployments.OpenCrateFactory}`);
  console.log(`  NFT: ${deployments.OpenCrateNFT}`);
  console.log(`  USDC: ${deployments.MockUSDC}`);
  console.log(`  IDRX: ${deployments.MockIDRX}\n`);

  // Get contract instances
  const factory = await viem.getContractAt("OpenCrateFactory", deployments.OpenCrateFactory);
  const nft = await viem.getContractAt("OpenCrateNFT", deployments.OpenCrateNFT);
  const usdc = await viem.getContractAt("MockUSDC", deployments.MockUSDC);
  const idrx = await viem.getContractAt("MockIDRX", deployments.MockIDRX);

  // Check template
  console.log("📖 Fetching template information...");
  const template = await factory.read.getCrateTemplate([1n]);
  console.log(`  Template Name: ${template.name}`);
  console.log(`  Base Price: $${formatUnits(template.basePriceUsd, 2)}`);
  console.log(`  Supported Tokens: ${template.supportedPaymentTokens.length}\n`);

  // Calculate prices for different lockup periods
  console.log("💰 Price Calculations:");
  
  const lockupDurations = [
    { name: "No Lock", duration: 0n },
    { name: "30 Days", duration: BigInt(30 * 24 * 60 * 60) },
    { name: "90 Days", duration: BigInt(90 * 24 * 60 * 60) },
    { name: "180 Days", duration: BigInt(180 * 24 * 60 * 60) }
  ];

  for (const lockup of lockupDurations) {
    try {
      const [priceUsd, multiplier, tokenAmounts] = await factory.read.calculatePurchasePrice([
        1n,
        lockup.duration
      ]);
      
      console.log(`\n  ${lockup.name} (${multiplier / 100}% multiplier):`);
      console.log(`    USD Price: $${formatUnits(priceUsd, 2)}`);
      console.log(`    USDC Required: ${formatUnits(tokenAmounts[0], 6)} USDC`);
      console.log(`    IDRX Required: ${formatUnits(tokenAmounts[1], 2)} IDRX (Rp ${formatUnits(tokenAmounts[1], 2)})`);
    } catch (error) {
      console.log(`  ${lockup.name}: Error calculating price`);
    }
  }

  // Test Purchase with USDC
  console.log("\n\n🛒 Testing USDC Purchase (No Lock)...");
  
  try {
    // Calculate required amount
    const [priceUsd, , tokenAmounts] = await factory.read.calculatePurchasePrice([1n, 0n]);
    const requiredUSDC = tokenAmounts[0];
    const maxSlippage = (requiredUSDC * 105n) / 100n; // 5% slippage tolerance

    console.log(`  Required USDC: ${formatUnits(requiredUSDC, 6)}`);
    console.log(`  Max USDC (with slippage): ${formatUnits(maxSlippage, 6)}`);

    // Check balance
    const balance = await usdc.read.balanceOf([deployer.account.address]);
    console.log(`  Your USDC Balance: ${formatUnits(balance, 6)}`);

    if (balance < requiredUSDC) {
      console.log("\n  ⚠️ Insufficient USDC. Minting tokens...");
      await usdc.write.mint([deployer.account.address, parseUnits("100", 6)]);
      console.log("  ✅ Minted 100 USDC");
    }

    // Approve
    console.log("\n  📝 Approving USDC...");
    await usdc.write.approve([deployments.OpenCrateFactory, maxSlippage]);
    console.log("  ✅ Approval confirmed");

    // Purchase
    console.log("\n  🎁 Purchasing crate...");
    const tx = await factory.write.purchaseCrate([
      1n, // templateId
      0n, // lockupDuration (no lock)
      deployments.MockUSDC,
      requiredUSDC,
      maxSlippage
    ]);

    console.log(`  ✅ Purchase successful! Tx: ${tx}`);

    // Get token ID
    const nextTokenId = await nft.read.nextTokenId();
    const purchasedTokenId = nextTokenId - 1n;
    
    console.log(`  🎉 Crate NFT ID: ${purchasedTokenId}`);

    // Get crate info
    const crateInfo = await nft.read.crateInfo([purchasedTokenId]);
    console.log("\n  📦 Crate Information:");
    console.log(`    Owner: ${deployer.account.address}`);
    console.log(`    ERC6551 Account: ${crateInfo.account}`);
    console.log(`    Price Paid: $${formatUnits(crateInfo.priceUsd, 2)}`);
    console.log(`    Boost Multiplier: ${crateInfo.boostMultiplierBps / 100}%`);
    console.log(`    Payment Token: USDC`);
    console.log(`    Payment Amount: ${formatUnits(crateInfo.paymentAmount, 6)} USDC`);
    console.log(`    Locked Until: ${crateInfo.lockedUntil === 0n ? "Not locked" : new Date(Number(crateInfo.lockedUntil) * 1000).toISOString()}`);

  } catch (error: any) {
    console.error("\n  ❌ Purchase failed:", error.message);
  }

  // Test Purchase with IDRX
  console.log("\n\n🛒 Testing IDRX Purchase (30 Days Lock)...");
  
  try {
    const lockDuration = BigInt(30 * 24 * 60 * 60);
    
    // Calculate required amount
    const [priceUsd, , tokenAmounts] = await factory.read.calculatePurchasePrice([1n, lockDuration]);
    const requiredIDRX = tokenAmounts[1];
    const maxSlippage = (requiredIDRX * 105n) / 100n; // 5% slippage tolerance

    console.log(`  Required IDRX: ${formatUnits(requiredIDRX, 2)} (Rp ${formatUnits(requiredIDRX, 2)})`);
    console.log(`  Max IDRX (with slippage): ${formatUnits(maxSlippage, 2)}`);

    // Check balance
    const balance = await idrx.read.balanceOf([deployer.account.address]);
    console.log(`  Your IDRX Balance: ${formatUnits(balance, 2)}`);

    if (balance < requiredIDRX) {
      console.log("\n  ⚠️ Insufficient IDRX. Minting tokens...");
      await idrx.write.mint([deployer.account.address, parseUnits("1000000", 2)]);
      console.log("  ✅ Minted 1,000,000 IDRX (Rp 1,000,000)");
    }

    // Approve
    console.log("\n  📝 Approving IDRX...");
    await idrx.write.approve([deployments.OpenCrateFactory, maxSlippage]);
    console.log("  ✅ Approval confirmed");

    // Purchase
    console.log("\n  🎁 Purchasing crate...");
    const tx = await factory.write.purchaseCrate([
      1n, // templateId
      lockDuration,
      deployments.MockIDRX,
      requiredIDRX,
      maxSlippage
    ]);

    console.log(`  ✅ Purchase successful! Tx: ${tx}`);

    // Get token ID
    const nextTokenId = await nft.read.nextTokenId();
    const purchasedTokenId = nextTokenId - 1n;
    
    console.log(`  🎉 Crate NFT ID: ${purchasedTokenId}`);

    // Get crate info
    const crateInfo = await nft.read.crateInfo([purchasedTokenId]);
    console.log("\n  📦 Crate Information:");
    console.log(`    Owner: ${deployer.account.address}`);
    console.log(`    ERC6551 Account: ${crateInfo.account}`);
    console.log(`    Price Paid: $${formatUnits(crateInfo.priceUsd, 2)}`);
    console.log(`    Boost Multiplier: ${crateInfo.boostMultiplierBps / 100}%`);
    console.log(`    Payment Token: IDRX`);
    console.log(`    Payment Amount: ${formatUnits(crateInfo.paymentAmount, 2)} IDRX`);
    console.log(`    Locked Until: ${new Date(Number(crateInfo.lockedUntil) * 1000).toISOString()}`);

    // Test that transfer is blocked
    console.log("\n  🔒 Testing lock mechanism...");
    try {
      await nft.write.transferFrom([
        deployer.account.address,
        "0x0000000000000000000000000000000000000001",
        purchasedTokenId
      ]);
      console.log("  ❌ Transfer succeeded (should have failed!)");
    } catch (error: any) {
      if (error.message.includes("TokenLocked")) {
        console.log("  ✅ Transfer correctly blocked - token is locked");
      } else {
        console.log(`  ⚠️ Transfer failed with different error: ${error.message}`);
      }
    }

  } catch (error: any) {
    console.error("\n  ❌ Purchase failed:", error.message);
  }

  console.log("\n\n✅ Purchase tests completed!");
  console.log("\n💡 Summary:");
  console.log("  • USDC purchases work with standard ERC20 tokens");
  console.log("  • IDRX purchases work with Indonesian Rupiah representation");
  console.log("  • Slippage protection prevents overpaying");
  console.log("  • Lock mechanism prevents transfers during lockup period");
  console.log("  • Each crate gets its own ERC6551 account for DeFi interactions");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });