import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";
import { parseUnits, formatUnits, keccak256, toHex, decodeEventLog, encodeFunctionData } from "viem";

// Type definitions for better type safety
interface PositionDetails {
  protocol: string;
  asset: string;
  strategyType: string;
  chain: string;
  infoURL: string;
  allocationBps: number;
  allocationUsd: bigint;
  netApyBps: number;
  baseAprBps: number;
  incentivesAprBps: number;
  feeBps: number;
  riskScore: number;
  openedAt: bigint;
  lastRebalancedAt: bigint;
  nextHarvestAt: bigint;
  accruedYieldUsd: bigint;
}

interface MintParams {
  to: `0x${string}`;
  riskLevel: number;
  strategyId: bigint;
  salt: bigint;
  priceUsd: bigint;
  boostMultiplierBps: number;
  lockDuration: bigint;
  creator: `0x${string}`;
  revenueShareBps: number;
  platformFeeBps: number;
  performanceFeeBps: number;
  riskDisclosure: string;
  feeDisclosure: string;
  lastRebalanceAt: bigint;
  nextHarvestAt: bigint;
  accruedYieldUsd: bigint;
  boostActive: boolean;
  accountInitData: `0x${string}`;
  adapterData: `0x${string}`;
}

// Constants for testing
const USD_DECIMALS = 2;
const MIN_PRICE_USD = parseUnits("5.00", USD_DECIMALS);
const MAX_PRICE_USD = parseUnits("1000.00", USD_DECIMALS);
const MIN_BOOST_BPS = 10000; // 1.0x
const MAX_BOOST_BPS = 20000; // 2.0x
const MAX_BPS = 10000;
const MAX_LOCK_DURATION = 365n * 24n * 60n * 60n; // 365 days in seconds

// Protocol-specific position data
const UNISWAP_V4_POSITIONS: PositionDetails[] = [
  {
    protocol: "Uniswap V4",
    asset: "ETH/USDC",
    strategyType: "Concentrated Liquidity",
    chain: "Ethereum",
    infoURL: "https://docs.uniswap.org/contracts/v4",
    allocationBps: 4000,
    allocationUsd: parseUnits("4000", USD_DECIMALS),
    netApyBps: 1200,
    baseAprBps: 800,
    incentivesAprBps: 400,
    feeBps: 100,
    riskScore: 3,
    openedAt: BigInt(Math.floor(Date.now() / 1000) - 7 * 24 * 60 * 60), // 7 days ago
    lastRebalancedAt: BigInt(Math.floor(Date.now() / 1000) - 2 * 24 * 60 * 60), // 2 days ago
    nextHarvestAt: BigInt(Math.floor(Date.now() / 1000) + 1 * 24 * 60 * 60), // 1 day from now
    accruedYieldUsd: parseUnits("125.50", USD_DECIMALS),
  },
  {
    protocol: "Uniswap V4",
    asset: "WBTC/ETH",
    strategyType: "Concentrated Liquidity",
    chain: "Arbitrum",
    infoURL: "https://docs.uniswap.org/contracts/v4",
    allocationBps: 3000,
    allocationUsd: parseUnits("3000", USD_DECIMALS),
    netApyBps: 1500,
    baseAprBps: 1000,
    incentivesAprBps: 500,
    feeBps: 150,
    riskScore: 4,
    openedAt: BigInt(Math.floor(Date.now() / 1000) - 14 * 24 * 60 * 60), // 14 days ago
    lastRebalancedAt: BigInt(Math.floor(Date.now() / 1000) - 3 * 24 * 60 * 60), // 3 days ago
    nextHarvestAt: BigInt(Math.floor(Date.now() / 1000) + 2 * 24 * 60 * 60), // 2 days from now
    accruedYieldUsd: parseUnits("210.75", USD_DECIMALS),
  },
];

const MORPHO_POSITIONS: PositionDetails[] = [
  {
    protocol: "Morpho",
    asset: "USDC",
    strategyType: "Lending",
    chain: "Ethereum",
    infoURL: "https://docs.morpho.org",
    allocationBps: 5000,
    allocationUsd: parseUnits("5000", USD_DECIMALS),
    netApyBps: 800,
    baseAprBps: 600,
    incentivesAprBps: 200,
    feeBps: 50,
    riskScore: 2,
    openedAt: BigInt(Math.floor(Date.now() / 1000) - 30 * 24 * 60 * 60), // 30 days ago
    lastRebalancedAt: BigInt(Math.floor(Date.now() / 1000) - 5 * 24 * 60 * 60), // 5 days ago
    nextHarvestAt: BigInt(Math.floor(Date.now() / 1000) + 3 * 24 * 60 * 60), // 3 days from now
    accruedYieldUsd: parseUnits("95.25", USD_DECIMALS),
  },
  {
    protocol: "Morpho",
    asset: "WETH",
    strategyType: "Lending",
    chain: "Ethereum",
    infoURL: "https://docs.morpho.org",
    allocationBps: 2000,
    allocationUsd: parseUnits("2000", USD_DECIMALS),
    netApyBps: 600,
    baseAprBps: 500,
    incentivesAprBps: 100,
    feeBps: 30,
    riskScore: 3,
    openedAt: BigInt(Math.floor(Date.now() / 1000) - 21 * 24 * 60 * 60), // 21 days ago
    lastRebalancedAt: BigInt(Math.floor(Date.now() / 1000) - 4 * 24 * 60 * 60), // 4 days ago
    nextHarvestAt: BigInt(Math.floor(Date.now() / 1000) + 4 * 24 * 60 * 60), // 4 days from now
    accruedYieldUsd: parseUnits("45.80", USD_DECIMALS),
  },
];

const AAVE_POSITIONS: PositionDetails[] = [
  {
    protocol: "Aave V3",
    asset: "USDT",
    strategyType: "Lending",
    chain: "Polygon",
    infoURL: "https://docs.aave.com",
    allocationBps: 6000,
    allocationUsd: parseUnits("6000", USD_DECIMALS),
    netApyBps: 450,
    baseAprBps: 400,
    incentivesAprBps: 50,
    feeBps: 25,
    riskScore: 2,
    openedAt: BigInt(Math.floor(Date.now() / 1000) - 45 * 24 * 60 * 60), // 45 days ago
    lastRebalancedAt: BigInt(Math.floor(Date.now() / 1000) - 7 * 24 * 60 * 60), // 7 days ago
    nextHarvestAt: BigInt(Math.floor(Date.now() / 1000) + 5 * 24 * 60 * 60), // 5 days from now
    accruedYieldUsd: parseUnits("67.90", USD_DECIMALS),
  },
  {
    protocol: "Aave V3",
    asset: "DAI",
    strategyType: "Lending",
    chain: "Optimism",
    infoURL: "https://docs.aave.com",
    allocationBps: 4000,
    allocationUsd: parseUnits("4000", USD_DECIMALS),
    netApyBps: 550,
    baseAprBps: 450,
    incentivesAprBps: 100,
    feeBps: 35,
    riskScore: 2,
    openedAt: BigInt(Math.floor(Date.now() / 1000) - 60 * 24 * 60 * 60), // 60 days ago
    lastRebalancedAt: BigInt(Math.floor(Date.now() / 1000) - 6 * 24 * 60 * 60), // 6 days ago
    nextHarvestAt: BigInt(Math.floor(Date.now() / 1000) + 6 * 24 * 60 * 60), // 6 days from now
    accruedYieldUsd: parseUnits("88.40", USD_DECIMALS),
  },
];

describe("YieldBox Contract Comprehensive Tests", async function () {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const [owner, user1, user2, user3, protocol] = await viem.getWalletClients();

  // Contracts
  let openCrateNFT: any;
  let openCrateFactory: any;
  let strategyRegistry: any;
  let mockYieldProtocol: any;
  let mockYieldAdapter: any;
  let erc6551Registry: any;
  let erc6551Account: any;

  // Test data
  let defaultMintParams: MintParams;

  it("Should deploy all contracts with correct configurations", async function () {
    // Deploy ERC6551 Registry
    erc6551Registry = await viem.deployContract("ERC6551Registry");

    // Deploy ERC6551 Account Implementation
    erc6551Account = await viem.deployContract("ERC6551Account");

    // Deploy Strategy Registry
    strategyRegistry = await viem.deployContract("OpenCrateStrategyRegistry", [owner.account.address]);

    // Deploy Mock Yield Protocol
    mockYieldProtocol = await viem.deployContract("MockYieldProtocol", [owner.account.address]);

    // Deploy Mock Yield Adapter
    mockYieldAdapter = await viem.deployContract("MockYieldAdapter", [
      mockYieldProtocol.address,
      owner.account.address,
    ]);

    // Set adapter in protocol
    await mockYieldProtocol.write.setAdapter([mockYieldAdapter.address]);

    // Deploy OpenCrate NFT
    openCrateNFT = await viem.deployContract("OpenCrateNFT", [
      "OpenCrate",
      "CRATE",
      "https://metadata.opencrate.io/",
      owner.account.address,
      "0x0000000000000000000000000000000000000000",
    ]);

    // Deploy OpenCrate Factory
    openCrateFactory = await viem.deployContract("OpenCrateFactory", [
      openCrateNFT.address,
      erc6551Registry.address,
      erc6551Account.address,
      strategyRegistry.address,
      owner.account.address,
    ]);

    // Set factory in NFT contract
    await openCrateNFT.write.setFactory([openCrateFactory.address]);

    // Register strategies
    await strategyRegistry.write.registerStrategy([
      mockYieldAdapter.address,
      "0x",
      0, // RISK_HIGH
      true,
    ]);

    // Set default mint parameters
    defaultMintParams = {
      to: user1.account.address,
      riskLevel: 0, // RISK_HIGH
      strategyId: 1n,
      salt: BigInt(Math.floor(Math.random() * 1000000)),
      priceUsd: parseUnits("750.00", USD_DECIMALS),
      boostMultiplierBps: MIN_BOOST_BPS,
      lockDuration: 0n,
      creator: user1.account.address,
      revenueShareBps: 1000,
      platformFeeBps: 200,
      performanceFeeBps: 500,
      riskDisclosure: "This investment carries high risk and may result in loss of principal.",
      feeDisclosure: "Fees include platform, performance, and revenue sharing components.",
      lastRebalanceAt: 0n,
      nextHarvestAt: 0n,
      accruedYieldUsd: 0n,
      boostActive: false,
      accountInitData: "0x",
      adapterData: "0x",
    };

    // Verify deployments
    assert.equal(await openCrateNFT.read.name(), "OpenCrate");
    assert.equal(await openCrateNFT.read.symbol(), "CRATE");
    assert.equal(await openCrateNFT.read.nextTokenId(), 1n);
    assert.equal(await openCrateNFT.read.totalMinted(), 0n);
    assert.equal(await openCrateNFT.read.factory(), openCrateFactory.address);

    assert.equal(await strategyRegistry.read.strategyCount(), 1n);
    const strategy = await strategyRegistry.read.strategy([1n]);
    assert.equal(strategy.adapter, mockYieldAdapter.address);
    assert.equal(strategy.riskLevel, 0);
    assert.equal(strategy.active, true);
  });

  it("Should set correct constants", async function () {
    assert.equal(await openCrateNFT.read.MIN_PRICE_USD(), MIN_PRICE_USD);
    assert.equal(await openCrateNFT.read.MAX_PRICE_USD(), MAX_PRICE_USD);
    assert.equal(await openCrateNFT.read.MIN_BOOST_BPS(), MIN_BOOST_BPS);
    assert.equal(await openCrateNFT.read.MAX_BOOST_BPS(), MAX_BOOST_BPS);
    assert.equal(await openCrateNFT.read.MAX_LOCK_DURATION(), MAX_LOCK_DURATION);
  });

  it("Should allow owner to register new strategies", async function () {
    await viem.assertions.emitWithArgs(
      strategyRegistry.write.registerStrategy([mockYieldAdapter.address, "0x1234", 1, true], {
        account: owner.account.address,
      }),
      strategyRegistry,
      "StrategyRegistered",
      [2n, mockYieldAdapter.address, 1]
    );

    assert.equal(await strategyRegistry.read.strategyCount(), 2n);
    
    const newStrategy = await strategyRegistry.read.strategy([2n]);
    assert.equal(newStrategy.adapter, mockYieldAdapter.address);
    assert.equal(newStrategy.adapterData, "0x1234");
    assert.equal(newStrategy.riskLevel, 1);
    assert.equal(newStrategy.active, true);
  });

  it("Should reject invalid strategy parameters", async function () {
    // Zero address adapter
    await viem.assertions.revertWith(
      // @ts-ignore
      strategyRegistry.write.registerStrategy(["0x0000000000000000000000000000000000000000", "0x", 0, true], {
        account: owner.account.address,
      }),
      "StrategyAdapterRequired"
    );

    // Invalid risk level
    await viem.assertions.revertWith(
      // @ts-ignore
      strategyRegistry.write.registerStrategy([mockYieldAdapter.address, "0x", 5, true], {
        account: owner.account.address,
      }),
      "StrategyUnsupportedRisk"
    );
  });

  it("Should prevent non-owners from managing strategies", async function () {
    await viem.assertions.revertWith(
      // @ts-ignore
      strategyRegistry.write.registerStrategy([mockYieldAdapter.address, "0x", 0, true], {
        account: user1.account.address,
      }),
      "OwnableUnauthorizedAccount"
    );
  });

  it("Should successfully mint a crate with valid parameters", async function () {
    const positions = [UNISWAP_V4_POSITIONS[0]];
    
    await viem.assertions.emitWithArgs(
      openCrateFactory.write.mintCrate([defaultMintParams, positions], {
        account: user1.account.address,
      }),
      openCrateFactory,
      "CrateCreated",
      [1n, user1.account.address]
    );

    assert.equal(await openCrateNFT.read.ownerOf([1n]), user1.account.address);
    
    const crateInfo = await openCrateNFT.read.crateInfo([1n]);
    assert.equal(crateInfo.priceUsd, defaultMintParams.priceUsd);
    assert.equal(crateInfo.riskLevel, defaultMintParams.riskLevel);
    assert.equal(crateInfo.strategyId, defaultMintParams.strategyId);
  });

  it("Should create ERC6551 account for each minted crate", async function () {
    const positions = [MORPHO_POSITIONS[0]];
    
    const txHash = await openCrateFactory.write.mintCrate([defaultMintParams, positions], {
      account: user1.account.address,
    });
    
    const receipt = await publicClient.getTransactionReceipt({ hash: txHash });
    
    // Find the CrateCreated event
    const crateCreatedEvent = receipt.logs.find((log) => {
      try {
        const decoded = decodeEventLog({
          abi: openCrateFactory.abi,
          eventName: "CrateCreated",
          data: log.data,
          topics: log.topics,
        });
        return decoded.eventName === "CrateCreated";
      } catch {
        return false;
      }
    });
    
    assert.notEqual(crateCreatedEvent, undefined);
    
    const decodedEvent = decodeEventLog({
      abi: openCrateFactory.abi,
      eventName: "CrateCreated",
      data: crateCreatedEvent!.data,
      topics: crateCreatedEvent!.topics,
    }) as any;
    
    const accountAddress = decodedEvent.args.account;
    
    // Verify the account is correctly configured
    const accountContract = await viem.getContractAt("ERC6551Account", accountAddress);
    const [chainId, tokenContract, tokenId] = await accountContract.read.token();
    
    assert.equal(chainId, await publicClient.getChainId());
    assert.equal(tokenContract, openCrateNFT.address);
    assert.equal(tokenId, 1n);
    assert.equal(await accountContract.read.owner(), user1.account.address);
  });

  // it("Should correctly predict account addresses", async function () {
  //   const predictedAddress = await openCrateFactory.read.predictAccountForNext([defaultMintParams.salt]);
    
  //   await openCrateFactory.write.mintCrate([defaultMintParams, []], {
  //     account: user1.account.address,
  //   });
    
  //   const deployment = await openCrateFactory.read.crateDeployment([1n]);
  //   assert.equal(deployment.account, predictedAddress);
  // });

  // it("Should reject minting with inactive strategy", async function () {
  //   await strategyRegistry.write.setStrategyStatus([1n, false], {
  //     account: owner.account.address,
  //   });
    
  //   await viem.assertions.revertWith(
  //     // @ts-ignore
  //     openCrateFactory.write.mintCrate([defaultMintParams, []], {
  //       account: user1.account.address,
  //     }),
  //     "StrategyInactive"
  //   );
  // });

  // it("Should reject minting with risk level mismatch", async function () {
  //   const invalidParams = { ...defaultMintParams, riskLevel: 1 }; // RISK_MEDIUM
    
  //   await viem.assertions.revertWith(
  //     // @ts-ignore
  //     openCrateFactory.write.mintCrate([invalidParams, []], {
  //       account: user1.account.address,
  //     }),
  //     "StrategyRiskMismatch"
  //   );
  // });

  // it("Should reject minting with invalid price", async function () {
  //   // Below minimum
  //   const invalidParamsLow = { ...defaultMintParams, priceUsd: MIN_PRICE_USD - 1n };
    
  //   await viem.assertions.revertWith(
  //     // @ts-ignore
  //     openCrateFactory.write.mintCrate([invalidParamsLow, []], {
  //       account: user1.account.address,
  //     }),
  //     "InvalidPrice"
  //   );

  //   // Above maximum
  //   const invalidParamsHigh = { ...defaultMintParams, priceUsd: MAX_PRICE_USD + 1n };
    
  //   await viem.assertions.revertWith(
  //     // @ts-ignore
  //     openCrateFactory.write.mintCrate([invalidParamsHigh, []], {
  //       account: user1.account.address,
  //     }),
  //     "InvalidPrice"
  //   );
  // });

  // it("Should update positions with Uniswap V4 data", async function () {
  //   // Create a crate first
  //   await openCrateFactory.write.mintCrate([defaultMintParams, []], {
  //     account: user1.account.address,
  //   });
    
  //   await viem.assertions.emitWithArgs(
  //     openCrateNFT.write.updatePositions([1n, UNISWAP_V4_POSITIONS], {
  //       account: user1.account.address,
  //     }),
  //     openCrateNFT,
  //     "PositionsUpdated",
  //     [1n, BigInt(UNISWAP_V4_POSITIONS.length), user1.account.address]
  //   );

  //   const positions = await openCrateNFT.read.getPositions([1n]);
  //   assert.equal(positions.length, UNISWAP_V4_POSITIONS.length);
    
  //   for (let i = 0; i < UNISWAP_V4_POSITIONS.length; i++) {
  //     assert.equal(positions[i].protocol, UNISWAP_V4_POSITIONS[i].protocol);
  //     assert.equal(positions[i].asset, UNISWAP_V4_POSITIONS[i].asset);
  //     assert.equal(positions[i].strategyType, UNISWAP_V4_POSITIONS[i].strategyType);
  //     assert.equal(positions[i].allocationBps, UNISWAP_V4_POSITIONS[i].allocationBps);
  //     assert.equal(positions[i].allocationUsd, UNISWAP_V4_POSITIONS[i].allocationUsd);
  //     assert.equal(positions[i].netApyBps, UNISWAP_V4_POSITIONS[i].netApyBps);
  //     assert.equal(positions[i].riskScore, UNISWAP_V4_POSITIONS[i].riskScore);
  //   }
  // });

  // it("Should update positions with Morpho data", async function () {
  //   // Create a crate first
  //   await openCrateFactory.write.mintCrate([defaultMintParams, []], {
  //     account: user1.account.address,
  //   });
    
  //   await openCrateNFT.write.updatePositions([1n, MORPHO_POSITIONS], {
  //     account: user1.account.address,
  //   });

  //   const positions = await openCrateNFT.read.getPositions([1n]);
  //   assert.equal(positions.length, MORPHO_POSITIONS.length);
    
  //   for (let i = 0; i < MORPHO_POSITIONS.length; i++) {
  //     assert.equal(positions[i].protocol, MORPHO_POSITIONS[i].protocol);
  //     assert.equal(positions[i].asset, MORPHO_POSITIONS[i].asset);
  //     assert.equal(positions[i].strategyType, MORPHO_POSITIONS[i].strategyType);
  //     assert.equal(positions[i].chain, MORPHO_POSITIONS[i].chain);
  //     assert.equal(positions[i].allocationBps, MORPHO_POSITIONS[i].allocationBps);
  //     assert.equal(positions[i].riskScore, MORPHO_POSITIONS[i].riskScore);
  //   }
  // });

  // it("Should update positions with Aave data", async function () {
  //   // Create a crate first
  //   await openCrateFactory.write.mintCrate([defaultMintParams, []], {
  //     account: user1.account.address,
  //   });
    
  //   await openCrateNFT.write.updatePositions([1n, AAVE_POSITIONS], {
  //     account: user1.account.address,
  //   });

  //   const positions = await openCrateNFT.read.getPositions([1n]);
  //   assert.equal(positions.length, AAVE_POSITIONS.length);
    
  //   for (let i = 0; i < AAVE_POSITIONS.length; i++) {
  //     assert.equal(positions[i].protocol, AAVE_POSITIONS[i].protocol);
  //     assert.equal(positions[i].asset, AAVE_POSITIONS[i].asset);
  //     assert.equal(positions[i].strategyType, AAVE_POSITIONS[i].strategyType);
  //     assert.equal(positions[i].chain, AAVE_POSITIONS[i].chain);
  //     assert.equal(positions[i].allocationBps, AAVE_POSITIONS[i].allocationBps);
  //     assert.equal(positions[i].riskScore, AAVE_POSITIONS[i].riskScore);
  //   }
  // });

  // it("Should reject positions with allocation exceeding 100%", async function () {
  //   // Create a crate first
  //   await openCrateFactory.write.mintCrate([defaultMintParams, []], {
  //     account: user1.account.address,
  //   });
    
  //   const invalidPositions = [
  //     { ...UNISWAP_V4_POSITIONS[0], allocationBps: 11000 }, // 110%
  //   ];
    
  //   await viem.assertions.revertWith(
  //     // @ts-ignore
  //     openCrateNFT.write.updatePositions([1n, invalidPositions], {
  //       account: user1.account.address,
  //     }),
  //     "InvalidBps"
  //   );
  // });

  // it("Should reject position updates from unauthorized users", async function () {
  //   // Create a crate first
  //   await openCrateFactory.write.mintCrate([defaultMintParams, []], {
  //     account: user1.account.address,
  //   });
    
  //   await viem.assertions.revertWith(
  //     // @ts-ignore
  //     openCrateNFT.write.updatePositions([1n, UNISWAP_V4_POSITIONS], {
  //       account: user2.account.address,
  //     }),
  //     "NotApprovedOrOwner"
  //   );
  // });

  // it("Should correctly calculate position count", async function () {
  //   // Create a crate first
  //   await openCrateFactory.write.mintCrate([defaultMintParams, []], {
  //     account: user1.account.address,
  //   });
    
  //   assert.equal(await openCrateNFT.read.positionsCount([1n]), 0n);
    
  //   await openCrateNFT.write.updatePositions([1n, UNISWAP_V4_POSITIONS], {
  //     account: user1.account.address,
  //   });
  //   assert.equal(await openCrateNFT.read.positionsCount([1n]), BigInt(UNISWAP_V4_POSITIONS.length));
    
  //   await openCrateNFT.write.updatePositions([1n, MORPHO_POSITIONS], {
  //     account: user1.account.address,
  //   });
  //   assert.equal(await openCrateNFT.read.positionsCount([1n]), BigInt(MORPHO_POSITIONS.length));
  // });

  // it("Should update crate price", async function () {
  //   // Create a crate first
  //   await openCrateFactory.write.mintCrate([defaultMintParams, []], {
  //     account: user1.account.address,
  //   });
    
  //   const newPrice = parseUnits("850.00", USD_DECIMALS);
    
  //   await viem.assertions.emitWithArgs(
  //     openCrateNFT.write.updatePrice([1n, newPrice], {
  //       account: user1.account.address,
  //     }),
  //     openCrateNFT,
  //     "PriceUpdated",
  //     [1n, newPrice]
  //   );

  //   const crateInfo = await openCrateNFT.read.crateInfo([1n]);
  //   assert.equal(crateInfo.priceUsd, newPrice);
  // });

  // it("Should set boost multiplier", async function () {
  //   // Create a crate first
  //   await openCrateFactory.write.mintCrate([defaultMintParams, []], {
  //     account: user1.account.address,
  //   });
    
  //   const newBoost = 15000; // 1.5x
    
  //   await viem.assertions.emitWithArgs(
  //     openCrateNFT.write.setBoostMultiplier([1n, newBoost], {
  //       account: user1.account.address,
  //     }),
  //     openCrateNFT,
  //     "BoostUpdated",
  //     [1n, newBoost]
  //   );

  //   const crateInfo = await openCrateNFT.read.crateInfo([1n]);
  //   assert.equal(crateInfo.boostMultiplierBps, newBoost);
  //   assert.equal(crateInfo.boostActive, true);
  //   assert.ok(crateInfo.lastBoostAt > 0n);
  // });

  // it("Should set boost status", async function () {
  //   // Create a crate first
  //   await openCrateFactory.write.mintCrate([defaultMintParams, []], {
  //     account: user1.account.address,
  //   });
    
  //   const newBoost = 12000; // 1.2x
    
  //   await openCrateNFT.write.setBoostStatus([1n, true, newBoost], {
  //     account: user1.account.address,
  //   });

  //   const crateInfo = await openCrateNFT.read.crateInfo([1n]);
  //   assert.equal(crateInfo.boostActive, true);
  //   assert.equal(crateInfo.boostMultiplierBps, newBoost);
  //   assert.ok(crateInfo.lastBoostAt > 0n);
  // });

  // it("Should extend lock duration", async function () {
  //   // Create a crate first
  //   await openCrateFactory.write.mintCrate([defaultMintParams, []], {
  //     account: user1.account.address,
  //   });
    
  //   const additionalDuration = 30n * 24n * 60n * 60n; // 30 days
    
  //   await viem.assertions.emitWithArgs(
  //     openCrateNFT.write.extendLock([1n, additionalDuration], {
  //       account: user1.account.address,
  //     }),
  //     openCrateNFT,
  //     "LockExtended",
  //     [1n]
  //   );

  //   const crateInfo = await openCrateNFT.read.crateInfo([1n]);
  //   assert.ok(crateInfo.lockedUntil > 0n);
  //   assert.ok(crateInfo.lastLockAt > 0n);
  // });

  // it("Should update lifecycle information", async function () {
  //   // Create a crate first
  //   await openCrateFactory.write.mintCrate([defaultMintParams, []], {
  //     account: user1.account.address,
  //   });
    
  //   const lastRebalanceAt = BigInt(Math.floor(Date.now() / 1000));
  //   const nextHarvestAt = lastRebalanceAt + 7n * 24n * 60n * 60n; // 7 days later
  //   const accruedYieldUsd = parseUnits("123.45", USD_DECIMALS);
    
  //   await openCrateNFT.write.updateLifecycle(
  //     [1n, lastRebalanceAt, nextHarvestAt, accruedYieldUsd],
  //     {
  //       account: user1.account.address,
  //     }
  //   );

  //   const crateInfo = await openCrateNFT.read.crateInfo([1n]);
  //   assert.equal(crateInfo.lastRebalanceAt, lastRebalanceAt);
  //   assert.equal(crateInfo.nextHarvestAt, nextHarvestAt);
  //   assert.equal(crateInfo.accruedYieldUsd, accruedYieldUsd);
  // });

  // it("Should update revenue share parameters", async function () {
  //   // Create a crate first
  //   await openCrateFactory.write.mintCrate([defaultMintParams, []], {
  //     account: user1.account.address,
  //   });
    
  //   const revenueShareBps = 2000;
  //   const platformFeeBps = 300;
  //   const performanceFeeBps = 700;
    
  //   await openCrateNFT.write.updateRevenueShare(
  //     [1n, revenueShareBps, platformFeeBps, performanceFeeBps],
  //     {
  //       account: user1.account.address,
  //     }
  //   );

  //   const crateInfo = await openCrateNFT.read.crateInfo([1n]);
  //   assert.equal(crateInfo.revenueShareBps, revenueShareBps);
  //   assert.equal(crateInfo.platformFeeBps, platformFeeBps);
  //   assert.equal(crateInfo.performanceFeeBps, performanceFeeBps);
  // });

  // it("Should update disclosures", async function () {
  //   // Create a crate first
  //   await openCrateFactory.write.mintCrate([defaultMintParams, []], {
  //     account: user1.account.address,
  //   });
    
  //   const newRiskDisclosure = "Updated risk disclosure text";
  //   const newFeeDisclosure = "Updated fee disclosure text";
    
  //   await openCrateNFT.write.updateDisclosures(
  //     [1n, newRiskDisclosure, newFeeDisclosure],
  //     {
  //       account: user1.account.address,
  //     }
  //   );

  //   const crateInfo = await openCrateNFT.read.crateInfo([1n]);
  //   assert.equal(crateInfo.riskDisclosure, newRiskDisclosure);
  //   assert.equal(crateInfo.feeDisclosure, newFeeDisclosure);
  // });

  // it("Should prevent transfers of locked crates", async function () {
  //   // Create a crate with a lock
  //   const lockedParams = {
  //     ...defaultMintParams,
  //     lockDuration: 30n * 24n * 60n * 60n, // 30 days
  //   };
    
  //   const txHash = await openCrateFactory.write.mintCrate([lockedParams, []], {
  //     account: user2.account.address,
  //   });
    
  //   const receipt = await publicClient.getTransactionReceipt({ hash: txHash });
    
  //   // Find the CrateCreated event
  //   const crateCreatedEvent = receipt.logs.find((log) => {
  //     try {
  //       const decoded = decodeEventLog({
  //         abi: openCrateFactory.abi,
  //         eventName: "CrateCreated",
  //         data: log.data,
  //         topics: log.topics,
  //       });
  //       return decoded.eventName === "CrateCreated";
  //     } catch {
  //       return false;
  //     }
  //   });
    
  //   const decodedEvent = decodeEventLog({
  //     abi: openCrateFactory.abi,
  //     eventName: "CrateCreated",
  //     data: crateCreatedEvent!.data,
  //     topics: crateCreatedEvent!.topics,
  //   }) as any;
    
  //   const lockedTokenId = decodedEvent.args.tokenId;
    
  //   // Try to transfer the locked crate
  //   await viem.assertions.revertWith(
  //     // @ts-ignore
  //     openCrateNFT.write.transferFrom([
  //       user2.account.address,
  //       user3.account.address,
  //       lockedTokenId,
  //     ], {
  //       account: user2.account.address,
  //     }),
  //     "TokenLocked"
  //   );
  // });

  // it("Should allow deposits through ERC6551 account", async function () {
  //   // Create a crate first
  //   const txHash = await openCrateFactory.write.mintCrate([defaultMintParams, []], {
  //     account: user1.account.address,
  //   });
    
  //   const receipt = await publicClient.getTransactionReceipt({ hash: txHash });
    
  //   // Find the CrateCreated event
  //   const crateCreatedEvent = receipt.logs.find((log) => {
  //     try {
  //       const decoded = decodeEventLog({
  //         abi: openCrateFactory.abi,
  //         eventName: "CrateCreated",
  //         data: log.data,
  //         topics: log.topics,
  //       });
  //       return decoded.eventName === "CrateCreated";
  //     } catch {
  //       return false;
  //     }
  //   });
    
  //   const decodedEvent = decodeEventLog({
  //     abi: openCrateFactory.abi,
  //     eventName: "CrateCreated",
  //     data: crateCreatedEvent!.data,
  //     topics: crateCreatedEvent!.topics,
  //   }) as any;
    
  //   const accountAddress = decodedEvent.args.account;
  //   const depositAmount = parseUnits("1000", 18);
    
  //   // Get the ERC6551 account contract
  //   const accountContract = await viem.getContractAt("ERC6551Account", accountAddress);
    
  //   // Find the deposit function from ABI
  //   const depositFunction = mockYieldAdapter.abi.find((fn: any) => fn.name === "deposit");
    
  //   // Execute deposit through the account
  //   await accountContract.write.executeCall(
  //     [mockYieldAdapter.address, 0n, depositFunction 
  //       ? encodeFunctionData({
  //           abi: [depositFunction],
  //           functionName: "deposit",
  //           args: [accountAddress, depositAmount, "0x"],
  //         })
  //       : "0x"
  //     ],
  //     { account: user1.account.address }
  //   );

  //   // Check position in protocol
  //   const position = await mockYieldProtocol.read.position([accountAddress]);
  //   assert.equal(position.principal, depositAmount);
  //   assert.equal(position.pendingYield, 0n);
    
  //   // Check current value
  //   const currentValue = await mockYieldAdapter.read.currentValue([accountAddress]);
  //   assert.equal(currentValue, depositAmount);
  // });

  // it("Should handle random valid price values", async function () {
  //   for (let i = 0; i < 5; i++) {
  //     // Generate random price between min and max
  //     const randomPrice = MIN_PRICE_USD + BigInt(Math.floor(Math.random() * Number(MAX_PRICE_USD - MIN_PRICE_USD)));
      
  //     const params = { ...defaultMintParams, salt: BigInt(Math.floor(Math.random() * 1000000)), priceUsd: randomPrice };
      
  //     const txHash = await openCrateFactory.write.mintCrate([params, []], {
  //       account: user1.account.address,
  //     });
      
  //     const receipt = await publicClient.getTransactionReceipt({ hash: txHash });
      
  //     // Find the CrateCreated event
  //     const crateCreatedEvent = receipt.logs.find((log) => {
  //       try {
  //         const decoded = decodeEventLog({
  //           abi: openCrateFactory.abi,
  //           eventName: "CrateCreated",
  //           data: log.data,
  //           topics: log.topics,
  //         });
  //         return decoded.eventName === "CrateCreated";
  //       } catch {
  //         return false;
  //       }
  //     });
      
  //     const decodedEvent = decodeEventLog({
  //       abi: openCrateFactory.abi,
  //       eventName: "CrateCreated",
  //       data: crateCreatedEvent!.data,
  //       topics: crateCreatedEvent!.topics,
  //     }) as any;
      
  //     const tokenId = decodedEvent.args.tokenId;
      
  //     const crateInfo = await openCrateNFT.read.crateInfo([tokenId]);
  //     assert.equal(crateInfo.priceUsd, randomPrice);
  //   }
  // });

  // it("Should handle random valid boost multipliers", async function () {
  //   for (let i = 0; i < 5; i++) {
  //     // Generate random boost between min and max
  //     const randomBoost = MIN_BOOST_BPS + Math.floor(Math.random() * (MAX_BOOST_BPS - MIN_BOOST_BPS));
      
  //     const params = { ...defaultMintParams, salt: BigInt(Math.floor(Math.random() * 1000000)), boostMultiplierBps: randomBoost };
      
  //     const txHash = await openCrateFactory.write.mintCrate([params, []], {
  //       account: user1.account.address,
  //     });
      
  //     const receipt = await publicClient.getTransactionReceipt({ hash: txHash });
      
  //     // Find the CrateCreated event
  //     const crateCreatedEvent = receipt.logs.find((log) => {
  //       try {
  //         const decoded = decodeEventLog({
  //           abi: openCrateFactory.abi,
  //           eventName: "CrateCreated",
  //           data: log.data,
  //           topics: log.topics,
  //         });
  //         return decoded.eventName === "CrateCreated";
  //       } catch {
  //         return false;
  //       }
  //     });
      
  //     const decodedEvent = decodeEventLog({
  //       abi: openCrateFactory.abi,
  //       eventName: "CrateCreated",
  //       data: crateCreatedEvent!.data,
  //       topics: crateCreatedEvent!.topics,
  //     }) as any;
      
  //     const tokenId = decodedEvent.args.tokenId;
      
  //     const crateInfo = await openCrateNFT.read.crateInfo([tokenId]);
  //     assert.equal(crateInfo.boostMultiplierBps, randomBoost);
  //   }
  // });

  // it("Should maintain invariant: total allocation never exceeds 100%", async function () {
  //   // Create a crate first
  //   await openCrateFactory.write.mintCrate([defaultMintParams, []], {
  //     account: user1.account.address,
  //   });
    
  //   // Test multiple position updates
  //   for (let i = 0; i < 10; i++) {
  //     // Generate random positions
  //     const numPositions = Math.floor(Math.random() * 3) + 1;
  //     const positions = [];
  //     let totalAllocation = 0;
      
  //     for (let j = 0; j < numPositions; j++) {
  //       let allocation;
  //       if (j === numPositions - 1) {
  //         // Last position gets remaining allocation
  //         allocation = MAX_BPS - totalAllocation;
  //       } else {
  //         // Random allocation for other positions
  //         allocation = Math.floor(Math.random() * (MAX_BPS - totalAllocation));
  //       }
        
  //       totalAllocation += allocation;
        
  //       positions.push({
  //         ...UNISWAP_V4_POSITIONS[0],
  //         allocationBps: allocation,
  //         allocationUsd: parseUnits((allocation / 100).toString(), USD_DECIMALS),
  //       });
  //     }
      
  //     await openCrateNFT.write.updatePositions([1n, positions], {
  //       account: user1.account.address,
  //     });
      
  //     // Verify invariant
  //     const storedPositions = await openCrateNFT.read.getPositions([1n]);
  //     let storedTotal = 0;
  //     for (const pos of storedPositions) {
  //       storedTotal += pos.allocationBps;
  //     }
      
  //     assert.ok(storedTotal <= MAX_BPS);
  //   }
  // });

  // it("Should maintain invariant: crate info consistency", async function () {
  //   // Create multiple crates
  //   const tokenIds = [];
    
  //   for (let i = 0; i < 3; i++) {
  //     const params = {
  //       ...defaultMintParams,
  //       to: i % 2 === 0 ? user1.account.address : user2.account.address,
  //       salt: BigInt(Math.floor(Math.random() * 1000000)),
  //     };
      
  //     const txHash = await openCrateFactory.write.mintCrate([params, []], {
  //       account: params.to,
  //     });
      
  //     const receipt = await publicClient.getTransactionReceipt({ hash: txHash });
      
  //     // Find the CrateCreated event
  //     const crateCreatedEvent = receipt.logs.find((log) => {
  //       try {
  //         const decoded = decodeEventLog({
  //           abi: openCrateFactory.abi,
  //           eventName: "CrateCreated",
  //           data: log.data,
  //           topics: log.topics,
  //         });
  //         return decoded.eventName === "CrateCreated";
  //       } catch {
  //         return false;
  //       }
  //     });
      
  //     const decodedEvent = decodeEventLog({
  //       abi: openCrateFactory.abi,
  //       eventName: "CrateCreated",
  //       data: crateCreatedEvent!.data,
  //       topics: crateCreatedEvent!.topics,
  //     }) as any;
      
  //     tokenIds.push(decodedEvent.args.tokenId);
  //   }
    
  //   // Verify invariants for all crates
  //   for (const tokenId of tokenIds) {
  //     const crateInfo = await openCrateNFT.read.crateInfo([tokenId]);
  //     const owner = await openCrateNFT.read.ownerOf([tokenId]);
  //     const deployment = await openCrateFactory.read.crateDeployment([tokenId]);
      
  //     // Invariant: crate info should match deployment
  //     assert.equal(crateInfo.strategyId, deployment.strategyId);
  //     assert.equal(crateInfo.riskLevel, deployment.riskLevel);
      
  //     // Invariant: price should be within bounds
  //     assert.ok(crateInfo.priceUsd >= MIN_PRICE_USD);
  //     assert.ok(crateInfo.priceUsd <= MAX_PRICE_USD);
      
  //     // Invariant: boost should be within bounds
  //     assert.ok(crateInfo.boostMultiplierBps >= MIN_BOOST_BPS);
  //     assert.ok(crateInfo.boostMultiplierBps <= MAX_BOOST_BPS);
      
  //     // Invariant: fees should sum correctly
  //     const totalFees = crateInfo.revenueShareBps + crateInfo.platformFeeBps + crateInfo.performanceFeeBps;
  //     assert.ok(totalFees <= MAX_BPS);
  //   }
  // });

  // it("Should handle complete crate lifecycle with multiple protocols", async function () {
  //   // Create crate with Uniswap V4 positions
  //   const params = { ...defaultMintParams };
  //   const txHash = await openCrateFactory.write.mintCrate([params, UNISWAP_V4_POSITIONS], {
  //     account: user1.account.address,
  //   });
    
  //   const receipt = await publicClient.getTransactionReceipt({ hash: txHash });
    
  //   // Find the CrateCreated event
  //   const crateCreatedEvent = receipt.logs.find((log) => {
  //     try {
  //       const decoded = decodeEventLog({
  //         abi: openCrateFactory.abi,
  //         eventName: "CrateCreated",
  //         data: log.data,
  //         topics: log.topics,
  //       });
  //       return decoded.eventName === "CrateCreated";
  //     } catch {
  //       return false;
  //     }
  //   });
    
  //   const decodedEvent = decodeEventLog({
  //     abi: openCrateFactory.abi,
  //     eventName: "CrateCreated",
  //     data: crateCreatedEvent!.data,
  //     topics: crateCreatedEvent!.topics,
  //   }) as any;
    
  //   const tokenId = decodedEvent.args.tokenId;
  //   const accountAddress = decodedEvent.args.account;
    
  //   // Update positions to Morpho
  //   await openCrateNFT.write.updatePositions([tokenId, MORPHO_POSITIONS], {
  //     account: user1.account.address,
  //   });
    
  //   // Update lifecycle
  //   const currentTime = BigInt(Math.floor(Date.now() / 1000));
  //   await openCrateNFT.write.updateLifecycle(
  //     [tokenId, currentTime, currentTime + 7n * 24n * 60n * 60n, parseUnits("250.75", USD_DECIMALS)],
  //     {
  //       account: user1.account.address,
  //     }
  //   );
    
  //   // Set boost
  //   await openCrateNFT.write.setBoostMultiplier([tokenId, 15000], {
  //     account: user1.account.address,
  //   });
    
  //   // Extend lock
  //   await openCrateNFT.write.extendLock([tokenId, 30n * 24n * 60n * 60n], {
  //     account: user1.account.address,
  //   });
    
  //   // Verify final state
  //   const crateInfo = await openCrateNFT.read.crateInfo([tokenId]);
  //   assert.equal(crateInfo.boostActive, true);
  //   assert.equal(crateInfo.boostMultiplierBps, 15000);
  //   assert.ok(crateInfo.lockedUntil > 0n);
  //   assert.equal(crateInfo.accruedYieldUsd, parseUnits("250.75", USD_DECIMALS));
    
  //   const positions = await openCrateNFT.read.getPositions([tokenId]);
  //   assert.equal(positions.length, MORPHO_POSITIONS.length);
  //   assert.equal(positions[0].protocol, "Morpho");
    
  //   // Verify total minted count
  //   assert.equal(await openCrateNFT.read.totalMinted(), 1n);
  //   assert.equal(await openCrateNFT.read.nextTokenId(), 2n);
  // });
});