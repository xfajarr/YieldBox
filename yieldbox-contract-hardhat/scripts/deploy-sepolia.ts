import { network } from "hardhat";
import fs from "fs";
import path from "path";
import { zeroAddress, getAddress, parseUnits } from "viem";
import { fileURLToPath } from "url";

// Fix for __dirname in ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function main() {
  console.log("🚀 Deploying YieldBox contracts to Base Sepolia testnet...");

  // Get deployer account
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const [deployer] = await viem.getWalletClients();

  const owner = getAddress(deployer.account.address);
  
  // Store deployment addresses
  const deployments: any = {};

  try {
    // 1. Deploy Mock Stablecoins
    console.log("🪙 Deploying MockUSDC...");
    const mockUSDC = await viem.deployContract("MockUSDC");
    deployments.MockUSDC = mockUSDC.address;
    console.log(`✅ MockUSDC deployed to: ${mockUSDC.address}`);

    console.log("🪙 Deploying MockIDRX...");
    const mockIDRX = await viem.deployContract("MockIDRX", [
      deployer.account.address,
      parseUnits("1000000", 2), // 10M IDRX = Rp 165,000,000,000
      2 // 2 decimals for Rp 16,500
    ]);
    deployments.MockIDRX = mockIDRX.address;
    console.log(`✅ MockIDRX deployed to: ${mockIDRX.address}`);

    // 2. Deploy ERC6551 Registry
    console.log("📦 Deploying ERC6551Registry...");
    const erc6551Registry = await viem.deployContract("ERC6551Registry");
    deployments.ERC6551Registry = erc6551Registry.address;
    console.log(`✅ ERC6551Registry deployed to: ${erc6551Registry.address}`);

    // 3. Deploy ERC6551 Account Implementation
    console.log("📦 Deploying ERC6551Account...");
    const erc6551Account = await viem.deployContract("ERC6551Account");
    deployments.ERC6551Account = erc6551Account.address;
    console.log(`✅ ERC6551Account deployed to: ${erc6551Account.address}`);

    // 4. Deploy Strategy Registry
    console.log("📦 Deploying OpenCrateStrategyRegistry...");
    const strategyRegistry = await viem.deployContract("OpenCrateStrategyRegistry", [deployer.account.address]);
    deployments.OpenCrateStrategyRegistry = strategyRegistry.address;
    console.log(`✅ OpenCrateStrategyRegistry deployed to: ${strategyRegistry.address}`);

    // 5. Deploy Mock Yield Protocol
    console.log("📦 Deploying MockYieldProtocol...");
    const mockYieldProtocol = await viem.deployContract("MockYieldProtocol", [deployer.account.address]);
    deployments.MockYieldProtocol = mockYieldProtocol.address;
    console.log(`✅ MockYieldProtocol deployed to: ${mockYieldProtocol.address}`);

    // 6. Deploy Mock Yield Adapter
    console.log("📦 Deploying MockYieldAdapter...");
    const mockYieldAdapter = await viem.deployContract("MockYieldAdapter", [
      mockYieldProtocol.address,
      deployer.account.address
    ]);
    deployments.MockYieldAdapter = mockYieldAdapter.address;
    console.log(`✅ MockYieldAdapter deployed to: ${mockYieldAdapter.address}`);

    // Set adapter in protocol
    console.log("⚙️ Setting adapter in MockYieldProtocol...");
    const mockProtocolContract = await viem.getContractAt("MockYieldProtocol", mockYieldProtocol.address);
    await mockProtocolContract.write.setAdapter([mockYieldAdapter.address]);
    console.log("✅ Adapter set successfully");

    // 7. Deploy Enhanced OpenCrate NFT
    console.log("📦 Deploying OpenCrateNFT...");
    const openCrateNFT = await viem.deployContract("OpenCrateNFT");
    deployments.OpenCrateNFT = openCrateNFT.address;
    console.log(`✅ OpenCrateNFT deployed to: ${openCrateNFT.address}`);

    // 8. Deploy Enhanced OpenCrate Factory
    console.log("📦 Deploying OpenCrateFactory...");
    const openCrateFactory = await viem.deployContract("OpenCrateFactory");
    deployments.OpenCrateFactory = openCrateFactory.address;
    console.log(`✅ OpenCrateFactory deployed to: ${openCrateFactory.address}`);

    // Set factory in NFT contract
    console.log("⚙️ Setting factory in OpenCrateNFT...");
    const nftContract = await viem.getContractAt("OpenCrateNFT", openCrateNFT.address);
    await nftContract.write.setFactory([openCrateFactory.address]);
    console.log("✅ Factory set successfully");

    // 9. Add supported tokens to NFT
    console.log("⚙️ Adding supported tokens to OpenCrateNFT...");
    await nftContract.write.addSupportedToken([
      mockUSDC.address,
      parseUnits("1", 2), // $1.00 USD
      6
    ]);
    console.log("✅ USDC added as supported token");

    await nftContract.write.addSupportedToken([
      mockIDRX.address,
      parseUnits("16500", 2), // Rp 16,500 = $1.00 USD
      2 // 2 decimals
    ]);
    console.log("✅ IDRX added as supported token");

    // 10. Register a strategy for testing
    console.log("⚙️ Registering test strategy...");
    const strategyRegistryContract = await viem.getContractAt("OpenCrateStrategyRegistry", strategyRegistry.address);
    await strategyRegistryContract.write.registerStrategy([
      mockYieldAdapter.address,
      "0x",
      0, // RISK_LOW
      true
    ]);
    console.log("✅ Test strategy registered successfully");

    console.log("\n🎉 All contracts deployed successfully!");
    console.log("\n📋 Deployment Summary:");
    console.log("================");
    for (const [name, address] of Object.entries(deployments)) {
      console.log(`${name}: ${address}`);
    }
    console.log("================");

    // Save deployment addresses to file
    const deploymentData = {
      network: "baseSepolia",
      deployer: deployer.account.address,
      deployments,
      timestamp: new Date().toISOString()
    };

    const deploymentsDir = path.join(__dirname, "..", "deployments");
    if (!fs.existsSync(deploymentsDir)) {
      fs.mkdirSync(deploymentsDir, { recursive: true });
    }

    const deploymentFile = path.join(deploymentsDir, "baseSepolia.json");
    fs.writeFileSync(deploymentFile, JSON.stringify(deploymentData, null, 2));
    console.log(`\n💾 Deployment saved to: ${deploymentFile}`);

    console.log("\n🎉 Deployment complete!");
    console.log("\n📝 To verify contracts, run:");
    console.log("   npx hardhat run scripts/verify-sepolia.ts --network baseSepolia");

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
