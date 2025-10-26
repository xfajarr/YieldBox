import fs from "fs";
import path from "path";
import { execSync } from "child_process";
import { fileURLToPath } from "url";
import { parseUnits, zeroAddress } from "viem";

// __dirname for ESM
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const USDC_DECIMALS = 6;
const IDRX_DECIMALS = 2;

function sleep(ms: number) {
  return new Promise((res) => setTimeout(res, ms));
}

function pickDeploymentFile(): string {
  const deploymentsDir = path.join(__dirname, "..", "deployments");
  const candidates = [
    path.join(deploymentsDir, "baseSepolia-improved.json"),
    path.join(deploymentsDir, "baseSepolia.json"),
  ];
  for (const f of candidates) {
    if (fs.existsSync(f)) return f;
  }
  throw new Error(
    `Deployment file not found. Expected one of:
 - ${candidates[0]}
 - ${candidates[1]}
Run the deploy script first.`
  );
}

function normalizeArg(arg: any): string {
  if (typeof arg === "bigint") return arg.toString(10);
  if (typeof arg === "number") return String(arg);
  if (typeof arg === "string") return arg;
  if (Array.isArray(arg)) return JSON.stringify(arg);
  if (arg === null || arg === undefined) return "";
  return String(arg);
}

function quote(arg: any): string {
  // Always quote to keep CLI safe (addresses, strings, bigints)
  return `"${normalizeArg(arg)}"`;
}

async function main() {
  console.log("🔍 Verifying contracts on Base Sepolia...");

  const deploymentFile = pickDeploymentFile();
  console.log(`ℹ️ Using deployment file: ${deploymentFile}`);

  const deploymentData = JSON.parse(fs.readFileSync(deploymentFile, "utf8"));
  const deployments: Record<string, string> = deploymentData.deployments || {};
  const deployer: string = deploymentData.deployer;
  const treasury: string = deploymentData.treasury || deployer;

  if (!deployer) {
    throw new Error("Deployer address missing in deployment file.");
  }

  const order = [
    // Mocks and utilities first
    "MockUSDC",
    "MockIDRX",
    "MockPriceOracle",
    "ERC6551Registry",
    "ERC6551Account",
    // Strategy infra
    "OpenCrateStrategyRegistry",
    "MockYieldProtocol",
    "MockYieldAdapter",
    // Core protocol
    "OpenCrateNFT",
    "OpenCrateFactory",
  ];

  function constructorArgsFor(name: string): any[] {
    switch (name) {
      case "MockUSDC":
        // constructor(address owner, uint256 initialSupply, uint8 decimals)
        return [deployer, parseUnits("1000000", USDC_DECIMALS), USDC_DECIMALS];

      case "MockIDRX":
        // constructor(address owner, uint256 initialSupply, uint8 decimals)
        // 165,000,000 IDRX with 2 decimals = 1,650,000.00 IDRX nominal amount for demo
        return [deployer, parseUnits("165000000", IDRX_DECIMALS), IDRX_DECIMALS];

      case "MockPriceOracle":
        // constructor(address owner)
        return [deployer];

      case "ERC6551Registry":
        // no constructor args
        return [];

      case "ERC6551Account":
        // no constructor args
        return [];

      case "OpenCrateStrategyRegistry":
        // constructor(address owner)
        return [deployer];

      case "MockYieldProtocol":
        // constructor(address owner)
        return [deployer];

      case "MockYieldAdapter":
        // constructor(address protocol, address owner)
        return [deployments.MockYieldProtocol, deployer];

      case "OpenCrateNFT":
        // constructor(string name, string symbol, string baseURI, address owner, address factory)
        return ["OpenCrate", "CRATE", "https://metadata.opencrate.io/", deployer, zeroAddress];

      case "OpenCrateFactory":
        // constructor(
        //   address crateNFTAddress,
        //   address erc6551RegistryAddress,
        //   address erc6551AccountAddress,
        //   address strategyRegistryAddress,
        //   address treasuryAddress,
        //   address initialOwner
        // )
        return [
          deployments.OpenCrateNFT,
          deployments.ERC6551Registry,
          deployments.ERC6551Account,
          deployments.OpenCrateStrategyRegistry,
          treasury,
          deployer,
        ];

      default:
        return [];
    }
  }

  for (const name of order) {
    const address = deployments[name];
    if (!address) {
      console.log(`⏭️ Skipping ${name} (not present in deployment file)`);
      continue;
    }

    const args = constructorArgsFor(name);
    const argsString = args.map((a) => quote(a)).join(" ");
    const command =
      `npx hardhat verify --network baseSepolia ${address}` +
      (args.length ? ` ${argsString}` : "");

    console.log(`\n➡️  Verifying ${name} at ${address}`);
    console.log(`   $ ${command}`);

    try {
      execSync(command, { stdio: "inherit" });
      console.log(`✅ ${name} verified successfully`);
    } catch (error: any) {
      const msg = (error?.message || "").toString();
      const std = (error?.stdout || "").toString() + (error?.stderr || "").toString();
      if (msg.includes("Already Verified") || std.includes("Already Verified")) {
        console.log(`✅ ${name} already verified`);
      } else {
        console.log(`❌ Failed to verify ${name}`);
        console.log("   You may retry or verify manually at: https://sepolia.basescan.org/verifyContract");
      }
    }

    // Avoid rate limiting
    await sleep(3000);
  }

  console.log("\n🎉 Verification complete!");
  console.log("Tip: Ensure BASESCAN_API_KEY (and ETHERSCAN_API_KEY if needed) are set in .env");
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
