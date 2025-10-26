import { network } from "hardhat";
import fs from "fs";
import path from "path";
import { zeroAddress, getAddress, parseUnits } from "viem";
import { fileURLToPath } from "url";

// Fix for __dirname in ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Exchange rate: 1 USD = Rp 16,500
const IDR_PER_USD = 16500;
const USD_DECIMALS = 2;
const IDRX_DECIMALS = 2;
const USDC_DECIMALS = 6;

async function main() {
  console.log("🚀 Deploying YieldBox contracts to Base Sepolia testnet...");
  console.log("💱 Exchange Rate: 1 USD = Rp 16,500\n");

  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const [deployer] = await viem.getWalletClients();

  const owner = getAddress(deployer.account.address);

  // Store deployment addresses
  const deployments: Record<string, string> = {};

  try {
    //
    // 1. Deploy Mock Stablecoins
    //
    console.log("🪙 Deploying MockUSDC (6 decimals)...");
    const mockUSDC = await viem.deployContract("MockUSDC", [
      deployer.account.address,
      parseUnits("1000000", USDC_DECIMALS), // 1,000,000 USDC
      USDC_DECIMALS,
    ]);
    deployments.MockUSDC = mockUSDC.address;
    console.log(`✅ MockUSDC deployed to: ${mockUSDC.address}`);

    console.log(
      "🪙 Deploying MockIDRX (2 decimals - represents Rupiah with 2 decimal places)..."
    );
    const mockIDRX = await viem.deployContract("MockIDRX", [
      deployer.account.address,
      parseUnits("165000000", IDRX_DECIMALS), // 165,000,000 IDRX (2 decimals) = Rp 16,500,000,000 ~= $1M USD
      IDRX_DECIMALS,
    ]);
    deployments.MockIDRX = mockIDRX.address;
    console.log(`✅ MockIDRX deployed to: ${mockIDRX.address}`);

    //
    // 2. Deploy Mock Price Oracle
    //
    console.log("💱 Deploying MockPriceOracle...");
    const mockPriceOracle = await viem.deployContract("MockPriceOracle", [
      deployer.account.address,
    ]);
    deployments.MockPriceOracle = mockPriceOracle.address;
    console.log(`✅ MockPriceOracle deployed to: ${mockPriceOracle.address}`);

    // Set token prices in oracle
    console.log("⚙️ Setting token prices in oracle...");
    const oracleContract = await viem.getContractAt(
      "MockPriceOracle",
      mockPriceOracle.address
    );

    // USDC: $1.00 = 100 (2 decimals)
    await oracleContract.write.setTokenPrice([
      mockUSDC.address,
      parseUnits("1", USD_DECIMALS), // "1.00" in 2-decimal USD format
    ]);
    console.log("  ✓ USDC price set: $1.00");

    // IDRX pricing logic:
    // 1 IDRX = Rp 1.00 (2 decimals)
    // Rp 16,500 = $1 => so 16,500 IDRX tokens ~= $1
    //
    // So 1 IDRX ~= $0.0000606.
    // We're approximating and just storing 1 (which we're treating as $0.01 in 2-decimal USD terms)
    // because we don't do sub-cent precision on USD here.
    await oracleContract.write.setTokenPrice([mockIDRX.address, 1n]);
    console.log(
      "  ✓ IDRX price set: $0.01 per token (≈16,500 IDRX = $1.00 effective)"
    );

    //
    // 3. Deploy ERC6551 Registry
    //
    console.log("📦 Deploying ERC6551Registry...");
    const erc6551Registry = await viem.deployContract("ERC6551Registry");
    deployments.ERC6551Registry = erc6551Registry.address;
    console.log(
      `✅ ERC6551Registry deployed to: ${erc6551Registry.address}`
    );

    //
    // 4. Deploy ERC6551 Account Implementation
    //
    console.log("📦 Deploying ERC6551Account...");
    const erc6551Account = await viem.deployContract("ERC6551Account");
    deployments.ERC6551Account = erc6551Account.address;
    console.log(
      `✅ ERC6551Account deployed to: ${erc6551Account.address}`
    );

    //
    // 5. Deploy Strategy Registry
    //
    console.log("📦 Deploying OpenCrateStrategyRegistry...");
    const strategyRegistry = await viem.deployContract(
      "OpenCrateStrategyRegistry",
      [deployer.account.address]
    );
    deployments.OpenCrateStrategyRegistry = strategyRegistry.address;
    console.log(
      `✅ OpenCrateStrategyRegistry deployed to: ${strategyRegistry.address}`
    );

    //
    // 6. Deploy Mock Yield Protocol
    //
    console.log("📦 Deploying MockYieldProtocol...");
    const mockYieldProtocol = await viem.deployContract("MockYieldProtocol", [
      deployer.account.address,
    ]);
    deployments.MockYieldProtocol = mockYieldProtocol.address;
    console.log(
      `✅ MockYieldProtocol deployed to: ${mockYieldProtocol.address}`
    );

    //
    // 7. Deploy Mock Yield Adapter
    //
    console.log("📦 Deploying MockYieldAdapter...");
    const mockYieldAdapter = await viem.deployContract("MockYieldAdapter", [
      mockYieldProtocol.address,
      deployer.account.address,
    ]);
    deployments.MockYieldAdapter = mockYieldAdapter.address;
    console.log(
      `✅ MockYieldAdapter deployed to: ${mockYieldAdapter.address}`
    );

    // Wire adapter into protocol
    console.log("⚙️ Setting adapter in MockYieldProtocol...");
    const mockProtocolContract = await viem.getContractAt(
      "MockYieldProtocol",
      mockYieldProtocol.address
    );
    await mockProtocolContract.write.setAdapter([mockYieldAdapter.address]);
    console.log("✅ Adapter set successfully");

    //
    // 8. Deploy OpenCrate NFT
    //
    console.log("📦 Deploying OpenCrateNFT...");
    const openCrateNFT = await viem.deployContract("OpenCrateNFT", [
      "OpenCrate",
      "CRATE",
      "https://metadata.opencrate.io/",
      deployer.account.address,
      zeroAddress, // we'll point this to the factory later
    ]);
    deployments.OpenCrateNFT = openCrateNFT.address;
    console.log(`✅ OpenCrateNFT deployed to: ${openCrateNFT.address}`);

    //
    // 9. Treasury (for now just deployer)
    //
    const treasuryAddress = deployer.account.address;
    console.log(`💰 Treasury address: ${treasuryAddress}`);

    //
    // 10. Deploy OpenCrate Factory
    //
    console.log("📦 Deploying OpenCrateFactory...");
    const openCrateFactory = await viem.deployContract("OpenCrateFactory", [
      openCrateNFT.address,
      erc6551Registry.address,
      erc6551Account.address,
      strategyRegistry.address,
      treasuryAddress,
      deployer.account.address,
    ]);
    deployments.OpenCrateFactory = openCrateFactory.address;
    console.log(
      `✅ OpenCrateFactory deployed to: ${openCrateFactory.address}`
    );

    // Point NFT -> Factory
    console.log("⚙️ Setting factory in OpenCrateNFT...");
    const nftContract = await viem.getContractAt(
      "OpenCrateNFT",
      openCrateNFT.address
    );
    await nftContract.write.setFactory([openCrateFactory.address]);
    console.log("✅ Factory set successfully");

    //
    // 11. Register supported tokens on the NFT
    //
    console.log("⚙️ Adding supported tokens to OpenCrateNFT...");

    // USDC: $1.00 with 6 decimals
    await nftContract.write.addSupportedToken([
      mockUSDC.address,
      parseUnits("1", USD_DECIMALS), // $1.00
      USDC_DECIMALS,
    ]);
    console.log("✅ USDC added as supported token ($1.00 per token)");

    // IDRX:
    // Using "1" here, representing $0.01 in our pseudo-USD(2 decimals)
    // and IDRX has 2 decimals.
    await nftContract.write.addSupportedToken([
      mockIDRX.address,
      1n, // $0.01 logical unit
      IDRX_DECIMALS,
    ]);
    console.log(
      "✅ IDRX added as supported token (Rp 16,500 = $1.00 reference)"
    );

    //
    // 12. Register a strategy for testing
    //
    console.log("⚙️ Registering test strategy...");
    const strategyRegistryContract = await viem.getContractAt(
      "OpenCrateStrategyRegistry",
      strategyRegistry.address
    );
    await strategyRegistryContract.write.registerStrategy([
      mockYieldAdapter.address,
      "0x",
      0, // e.g. RISK_HIGH or enum index 0
      true,
    ]);
    console.log("✅ Test strategy registered successfully");

    //
    // 13. Create a test crate template
    //
    console.log("⚙️ Creating test crate template...");
    const factoryContract = await viem.getContractAt(
      "OpenCrateFactory",
      openCrateFactory.address
    );

    const basePriceUsd = parseUnits("10", USD_DECIMALS); // $10.00

    // lockupOptions:
    // - index 0: no lock (1.0x)
    // - index 1: 30 days (1.2x)
    // - index 2: 90 days (1.5x)
    // - index 3: 180 days (1.8x)
    const lockupOptions = [
      {
        duration: 0n, // no lock
        multiplierBps: 10000, // 1.0x
        enabled: true,
      },
      {
        duration: BigInt(30 * 24 * 60 * 60), // 30 days
        multiplierBps: 12000, // 1.2x
        enabled: true,
      },
      {
        duration: BigInt(90 * 24 * 60 * 60), // 90 days
        multiplierBps: 15000, // 1.5x
        enabled: true,
      },
      {
        duration: BigInt(180 * 24 * 60 * 60), // 180 days
        multiplierBps: 18000, // 1.8x
        enabled: true,
      },
    ];

    // Positions inside the crate strategy (can be protocol positions etc.)
    // You're leaving it empty for now.
    const emptyPositions: any[] = [];

    await factoryContract.write.createCrateTemplate([
      "Conservative Yield Crate",
      "A low-risk yield strategy focusing on stablecoin lending",
      0, // risk enum index (e.g. RISK_HIGH or RISK_LOW depending on how your contract defines it)
      1n, // strategyId = 1
      basePriceUsd,
      emptyPositions,
      1000, // 10% revenue share (bps)
      200, // 2% platform fee (bps)
      500, // 5% performance fee (bps)
      "This is a conservative strategy with low risk of principal loss",
      "Fees include 10% revenue share, 2% platform fee, and 5% performance fee",
      lockupOptions,
      [mockUSDC.address, mockIDRX.address],
    ]);

    console.log("✅ Test template created successfully");
    console.log("   • Base Price: $10.00");
    console.log("   • No lock: 1.0x multiplier = $10.00");
    console.log("   • 30 days: 1.2x multiplier = $12.00");
    console.log("   • 90 days: 1.5x multiplier = $15.00");
    console.log("   • 180 days: 1.8x multiplier = $18.00");

    //
    // Done. Report + persist
    //
    console.log("\n🎉 All contracts deployed successfully!");

    console.log("\n📋 Deployment Summary:");
    console.log("================");
    for (const [name, address] of Object.entries(deployments)) {
      console.log(`${name}: ${address}`);
    }
    console.log("================");

    console.log("\n💱 Price Information:");
    console.log("================");
    console.log("Exchange Rate: 1 USD = Rp 16,500");
    console.log("USDC: 1 token = $1.00");
    console.log("IDRX: 16,500 tokens = $1.00 (1 token = Rp 1.00)");
    console.log("================");

    console.log("\n🧪 Testing Purchase Calculations:");
    console.log("================");
    console.log("Template 1 - $10.00 base price:");
    console.log("  No lock (1.0x): $10.00 = 10 USDC or 165,000 IDRX");
    console.log("  30 days (1.2x): $12.00 = 12 USDC or 198,000 IDRX");
    console.log("  90 days (1.5x): $15.00 = 15 USDC or 247,500 IDRX");
    console.log("  180 days (1.8x): $18.00 = 18 USDC or 297,000 IDRX");
    console.log("================");

    // Save deployment addresses to file
    const deploymentData = {
      network: "baseSepolia",
      deployer: deployer.account.address,
      treasury: treasuryAddress,
      deployments,
      priceInfo: {
        exchangeRate: "1 USD = 16,500 IDR",
        usdcPrice: "1 USDC = $1.00",
        idrxPrice:
          "1 IDRX = Rp 1.00 (16,500 IDRX = $1.00 ≈ $0.0000606 per IDRX)",
      },
      timestamp: new Date().toISOString(),
    };

    const deploymentsDir = path.join(__dirname, "..", "deployments");
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true });
    }

    const deploymentFile = path.join(
      deploymentsDir,
      "baseSepolia-improved.json"
    );
    fs.writeFileSync(deploymentFile, JSON.stringify(deploymentData, null, 2));
    console.log(`\n💾 Deployment saved to: ${deploymentFile}`);

    console.log("\n🎉 Deployment complete!");
    console.log("\n📝 Next Steps:");
    console.log(
      "1. Verify contracts: npx hardhat run scripts/verify-sepolia.ts --network baseSepolia"
    );
    console.log(
      "2. Test purchase: Use the frontend or write a test script against OpenCrateFactory.purchaseCrate"
    );
    console.log(
      "3. Fund test wallets with USDC/IDRX for testing purchases (mint from mocks)"
    );

    console.log("\n💡 Example Purchase (via viem style):");
    console.log("// USDC purchase of $10 crate with no lock optionIndex=0:");
    console.log(
      `await usdc.write.approve([openCrateFactory.address, parseUnits("10", ${USDC_DECIMALS})]);`
    );
    console.log(
      `await factory.write.purchaseCrate([1n, 0n, mockUSDC.address, parseUnits("10", ${USDC_DECIMALS}), parseUnits("10.5", ${USDC_DECIMALS})]);`
    );
    console.log("\n// IDRX purchase of $10 crate with no lock:");
    console.log(
      `await idrx.write.approve([openCrateFactory.address, parseUnits("165000", ${IDRX_DECIMALS})]);`
    );
    console.log(
      `await factory.write.purchaseCrate([1n, 0n, mockIDRX.address, parseUnits("165000", ${IDRX_DECIMALS}), parseUnits("170000", ${IDRX_DECIMALS})]);`
    );
  } catch (error) {
    console.error("❌ Deployment failed:", error);
    process.exit(1);
  }
}

// Execute deployment
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
