import fs from "fs";
import path from "path";
import { zeroAddress } from "viem";
import { execSync } from "child_process";
import { fileURLToPath } from "url";

// Fix for __dirname in ES modules
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

async function main() {
  console.log("🔍 Verifying contracts on Base Sepolia...");

  // Read deployment file
  const deploymentFile = path.join(__dirname, "..", "deployments", "baseSepolia.json");
  
  if (!fs.existsSync(deploymentFile)) {
    console.error("❌ Deployment file not found. Please deploy first using: npx hardhat run scripts/deploy-sepolia.ts --network baseSepolia");
    process.exit(1);
  }

  const deploymentData = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
  const { deployments } = deploymentData;

  // Get deployer address for constructor arguments
  const deployer = deploymentData.deployer;

  for (const [name, address] of Object.entries(deployments)) {
    try {
      console.log(`Verifying ${name} at ${address}...`);
      
      // Get constructor arguments based on contract name
      let constructorArgs: any[] = [];
      if (name === "OpenCrateStrategyRegistry") {
        constructorArgs = [deployer];
      } else if (name === "MockYieldProtocol") {
        constructorArgs = [deployer];
      } else if (name === "MockYieldAdapter") {
        constructorArgs = [deployments.MockYieldProtocol, deployer];
      } else if (name === "OpenCrateNFT") {
        constructorArgs = ["OpenCrate", "CRATE", "https://metadata.opencrate.io/", deployer, zeroAddress];
      } else if (name === "OpenCrateFactory") {
        constructorArgs = [
          deployments.OpenCrateNFT,
          deployments.ERC6551Registry,
          deployments.ERC6551Account,
          deployments.OpenCrateStrategyRegistry,
          deployer
        ];
      } else if (name === "OpenCrateNFTEnhanced") {
        constructorArgs = []; // No constructor args
      } else if (name === "OpenCrateFactoryEnhanced") {
        constructorArgs = []; // No constructor args
      }

      // Skip contracts with no constructor args
      if (constructorArgs.length === 0) {
        console.log(`⏭️ Skipping ${name} (no constructor arguments to verify)`);
        continue;
      }
      
      // Build verification command
      const argsString = constructorArgs.map(arg => `"${arg}"`).join(" ");
      const command = `npx hardhat verify --network baseSepolia ${address} ${argsString}`;
      
      console.log(`Running: ${command}`);
      
      try {
        execSync(command, { stdio: 'inherit' });
        console.log(`✅ ${name} verified successfully`);
      } catch (error: any) {
        if (error.message?.includes("Already Verified") || error.stdout?.includes("Already Verified")) {
          console.log(`✅ ${name} already verified`);
        } else {
          console.log(`❌ Failed to verify ${name}`);
          console.log("   You may need to verify manually at: https://sepolia.basescan.org/verifyContract");
        }
      }
      
    } catch (error: any) {
      console.log(`❌ Error processing ${name}: ${error.message}`);
    }
  }

  console.log("\n🎉 Verification complete!");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });