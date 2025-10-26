import fs from "fs";
import path from "path";
import { execSync } from "child_process";
import { fileURLToPath } from "url";
import { parseUnits, zeroAddress } from "viem";

// ESM __dirname shim
const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

// Decimals (must match deploy.ts)
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

// Fully Qualified Names to disambiguate identical bytecode (Blockscout/Etherscan)
const fqMap: Record<string, string> = {
  MockUSDC: "contracts/mock/MockUSDC.sol:MockUSDC",
  MockIDRX: "contracts/mock/MockIDRX.sol:MockIDRX",
  MockPriceOracle: "contracts/MockPriceOracle.sol:MockPriceOracle",
  ERC6551Registry: "contracts/ERC6551Registry.sol:ERC6551Registry",
  ERC6551Account: "contracts/ERC6551Account.sol:ERC6551Account",
  OpenCrateStrategyRegistry:
    "contracts/strategies/OpenCrateStrategyRegistry.sol:OpenCrateStrategyRegistry",
  MockYieldProtocol: "contracts/mock/MockYieldProtocol.sol:MockYieldProtocol",
  MockYieldAdapter: "contracts/adapters/MockYieldAdapter.sol:MockYieldAdapter",
  OpenCrateNFT: "contracts/OpenCrateNFT.sol:OpenCrateNFT",
  OpenCrateFactory: "contracts/OpenCrateFactory.sol:OpenCrateFactory",
};

function wasBlockscoutSuccess(text: string): boolean {
  const t = text.toLowerCase();
  return (
    t.includes("contract verified successfully on blockscout") ||
    t.includes("has already been verified on blockscout")
  );
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

  // Verification order (dependencies first)
  const order = [
    // Mocks and infra
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
        return [
          "OpenCrate",
          "CRATE",
          "https://metadata.opencrate.io/",
          deployer,
          zeroAddress,
        ];

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

  const force = process.env.VERIFY_FORCE === "1";

  for (const name of order) {
    const address = deployments[name];
    if (!address) {
      console.log(`⏭️ Skipping ${name} (not present in deployment file)`);
      continue;
    }

    const fq = fqMap[name];
    if (!fq) {
      console.log(
        `⚠️ No fully-qualified name mapping for ${name}, attempting generic verification`
      );
    }

    const args = constructorArgsFor(name);
    const argsString = args.map((a) => quote(a)).join(" ");
    const forceFlag = force ? " --force" : "";
    const contractFlag = fq ? ` --contract ${fq}` : "";

    const command =
      `npx hardhat verify --network baseSepolia${contractFlag}${forceFlag} ${address}` +
      (args.length ? ` ${argsString}` : "");

    console.log(`\n➡️  Verifying ${name} at ${address}`);
    console.log(`   $ ${command}`);

    let attempts = 0;
    const maxAttempts = 3;

    for (; attempts < maxAttempts; attempts++) {
      try {
        execSync(command, { stdio: "inherit" });
        console.log(`✅ ${name} verified successfully`);
        break;
      } catch (error: any) {
        // Collect any string we can get from the error to inspect explorer output
        const combined =
          (error?.message ? String(error.message) : "") +
          (error?.stdout ? String(error.stdout) : "") +
          (error?.stderr ? String(error.stderr) : "");

        // Treat Blockscout success as success even if Etherscan part failed
        if (wasBlockscoutSuccess(combined)) {
          console.log(`✅ ${name} verified on Blockscout`);
          break;
        }

        // Handle "Already Verified"
        if (combined.toLowerCase().includes("already verified")) {
          console.log(`✅ ${name} already verified`);
          break;
        }

        // Retry on transient explorer errors
        const transient =
          combined.includes("ECONNRESET") ||
          combined.includes("429") ||
          combined.includes("ETIMEDOUT");
        if (attempts < maxAttempts - 1 && transient) {
          console.log("⚠️ Transient explorer error. Retrying in 3s...");
          await sleep(3000);
          continue;
        }

        console.log(`❌ Failed to verify ${name}`);
        console.log(
          "   You may retry or verify manually at: https://base-sepolia.blockscout.com/ or https://sepolia.basescan.org/"
        );
        break;
      }
    }

    // Avoid rate limiting between verifications
    await sleep(2000);
  }

  console.log("\n🎉 Verification complete!");
  console.log(
    "Tip: Ensure BASESCAN_API_KEY (and ETHERSCAN_API_KEY if needed) are set in .env. Use VERIFY_FORCE=1 to pass --force."
  );
}

main()
  .then(() => process.exit(0))
  .catch((err) => {
    console.error(err);
    process.exit(1);
  });
