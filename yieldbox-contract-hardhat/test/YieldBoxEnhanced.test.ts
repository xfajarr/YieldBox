import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";
import { parseUnits, formatUnits, keccak256, toHex, decodeEventLog, encodeFunctionData, zeroAddress } from "viem";

describe("YieldBox Enhanced - Token Support", async function () {
  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const [owner, user1, user2, user3] = await viem.getWalletClients();

  // Contracts
  let mockUSDC: any;
  let mockIDRX: any;
  let crateNFT: any;
  let crateFactory: any;
  let strategyRegistry: any;
  let mockYieldProtocol: any;
  let mockYieldAdapter: any;
  let erc6551Registry: any;
  let erc6551Account: any;

  it("Should deploy all enhanced contracts with token support", async function () {
    // Deploy mock tokens
    mockUSDC = await viem.deployContract("MockUSDC");
    await mockUSDC.write.mint([owner.account.address, parseUnits("1000000", 6)]); // 1M USDC
    
    mockIDRX = await viem.deployContract("MockIDRX", [
      owner.account.address,
      parseUnits("1000000", 2), // 10M IDRX = Rp 165,000,000,000
      2 // 2 decimals
    ]);
    await mockIDRX.write.mint([owner.account.address, parseUnits("1000000", 2)]); // 10M IDRX
    
    // Deploy core contracts
    erc6551Registry = await viem.deployContract("ERC6551Registry");
    erc6551Account = await viem.deployContract("ERC6551Account");
    strategyRegistry = await viem.deployContract("OpenCrateStrategyRegistry");
    mockYieldProtocol = await viem.deployContract("MockYieldProtocol");
    mockYieldAdapter = await viem.deployContract("MockYieldAdapter");
    
    // Set adapter in protocol
    await mockYieldProtocol.write.setAdapter([mockYieldAdapter.address]);
    
    // Deploy enhanced NFT and Factory
    crateNFT = await viem.deployContract("OpenCrateNFTEnhanced");
    crateFactory = await viem.deployContract("OpenCrateFactoryEnhanced");
    
    // Set factory in NFT
    await crateNFT.write.setFactory([crateFactory.address]);
    
    // Register strategy
    await strategyRegistry.write.registerStrategy([
      mockYieldAdapter.address,
      "0x",
      0, // RISK_LOW
      true
    ]);
    
    // Add supported tokens to NFT
    await crateNFT.write.addSupportedToken([
      mockUSDC.address,
      parseUnits("1", 2), // $1.00 USD
      6
    ]);
    
    await crateNFT.write.addSupportedToken([
      mockIDRX.address,
      parseUnits("16500", 2), // Rp 16,500 = $1.00 USD
      2
    ]);
    
    // Transfer tokens to users
    await mockUSDC.write.transfer([user1.account.address, parseUnits("1000", 6)]);
    await mockUSDC.write.transfer([user2.account.address, parseUnits("1000", 6)]);
    await mockIDRX.write.transfer([user1.account.address, parseUnits("10000", 2)]);
    await mockIDRX.write.transfer([user2.account.address, parseUnits("10000", 2)]);
    
    // Verify deployments
    assert.equal(await crateNFT.read.name(), "OpenCrate");
    assert.equal(await crateNFT.read.symbol(), "CRATE");
    assert.equal(await crateNFT.read.nextTokenId(), 1n);
    assert.equal((await crateNFT.read.factory()).toLowerCase(), (crateFactory.address as string).toLowerCase());
  });

  it("Should allow owner to add supported tokens", async function () {
    const newToken = await viem.deployContract("MockUSDC");
    await newToken.write.mint([owner.account.address, parseUnits("1000000", 6)]);
    
    const txHash = await crateNFT.write.addSupportedToken([
      newToken.address,
      parseUnits("1", 2),
      6
    ], { account: owner.account.address });
    
    const receipt = await publicClient.getTransactionReceipt({ hash: txHash });
    const event = receipt.logs.find((log) => {
      try {
        const decoded = decodeEventLog({
          abi: crateNFT.abi,
          eventName: "TokenAdded",
          data: log.data,
          topics: log.topics,
        });
        return decoded.eventName === "TokenAdded";
      } catch {
        return false;
      }
    });
    
    assert.notEqual(event, undefined);
    
    const decodedEvent = decodeEventLog({
      abi: crateNFT.abi,
      eventName: "TokenAdded",
      data: event!.data,
      topics: event!.topics,
    }) as any;
    
    assert.equal((decodedEvent.args.token as string).toLowerCase(), newToken.address.toLowerCase());
    assert.equal(decodedEvent.args.priceUsd, parseUnits("1", 2));
    assert.equal(decodedEvent.args.decimals, 6);
    
    const tokenInfo = await crateNFT.read.getSupportedToken([newToken.address]);
    assert.equal(tokenInfo.enabled, true);
    assert.equal(tokenInfo.priceUsd, parseUnits("1", 2));
    assert.equal(tokenInfo.decimals, 6);
  });
  
  it("Should return whitelisted tokens", async function () {
    const whitelistedTokens = await crateNFT.read.getWhitelistedTokens();
    assert.equal(whitelistedTokens.length, 2);
    assert.ok(whitelistedTokens.some((token: string) => token.toLowerCase() === mockUSDC.address.toLowerCase()));
    assert.ok(whitelistedTokens.some((token: string) => token.toLowerCase() === mockIDRX.address.toLowerCase()));
  });

  it("Should allow minting with USDC payment", async function () {
    // Create a crate template first
    await crateFactory.write.createCrateTemplate([
      "Test Crate",
      "A test crate for USDC payments",
      0, // riskLevel
      1, // strategyId
      parseUnits("100", 2), // $100.00 USD base price
      [], // positions
      500, // revenueShareBps
      200, // platformFeeBps
      300, // performanceFeeBps
      "Low risk strategy",
      "Standard fees apply",
      [
        {
          duration: 30n * 86400n, // 30 days
          multiplierBps: 10000n, // 1.0x
          enabled: true
        },
        {
          duration: 90n * 86400n, // 90 days
          multiplierBps: 15000n, // 1.5x
          enabled: true
        }
      ],
      [mockUSDC.address]
    ], { account: owner.account.address });
    
    const templateId = await crateFactory.read.nextTemplateId() - 1n;
    
    // Purchase crate with USDC
    const txHash = await crateFactory.write.purchaseCrate([
      templateId,
      30n * 86400n, // 30 days
      mockUSDC.address,
      parseUnits("100", 6) // $100.00 USDC
    ], { account: user1.account.address });
    
    const receipt = await publicClient.getTransactionReceipt({ hash: txHash });
    const event = receipt.logs.find((log) => {
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
    
    assert.notEqual(event, undefined);
    
    // Check crate was minted
    const tokenId = await crateNFT.read.nextTokenId() - 1n;
    assert.equal((await crateNFT.read.ownerOf([tokenId])).toLowerCase(), user1.account.address.toLowerCase());
    
    const crateInfo = await crateNFT.read.crateInfo([tokenId]);
    assert.equal(crateInfo.paymentToken.toLowerCase(), mockUSDC.address.toLowerCase());
    assert.equal(crateInfo.paymentAmount, parseUnits("100", 6));
    assert.equal(crateInfo.priceUsd, parseUnits("100", 2)); // 1.0x multiplier
  });
  
  it("Should allow minting with IDRX payment", async function () {
    // Create a crate template first
    await crateFactory.write.createCrateTemplate([
      "IDRX Crate",
      "A test crate for IDRX payments",
      0, // riskLevel
      1, // strategyId
      parseUnits("50", 2), // $50.00 USD base price
      [], // positions
      500, // revenueShareBps
      200, // platformFeeBps
      300, // performanceFeeBps
      "Low risk strategy",
      "Standard fees apply",
      [
        {
          duration: 90n * 86400n, // 90 days
          multiplierBps: 12000n, // 1.2x
          enabled: true
        }
      ],
      [mockIDRX.address]
    ], { account: owner.account.address });
    
    const templateId = await crateFactory.read.nextTemplateId() - 1n;
    
    // Purchase crate with IDRX
    const txHash = await crateFactory.write.purchaseCrate([
      templateId,
      90n * 86400n, // 90 days
      mockIDRX.address,
      parseUnits("60", 18) // $60 IDRX (with 1.2x multiplier)
    ], { account: user1.account.address });
    
    const receipt = await publicClient.getTransactionReceipt({ hash: txHash });
    const event = receipt.logs.find((log) => {
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
    
    assert.notEqual(event, undefined);
    
    // Check crate was minted
    const tokenId = await crateNFT.read.nextTokenId() - 1n;
    assert.equal((await crateNFT.read.ownerOf([tokenId])).toLowerCase(), user1.account.address.toLowerCase());
    
    const crateInfo = await crateNFT.read.crateInfo([tokenId]);
    assert.equal(crateInfo.paymentToken.toLowerCase(), mockIDRX.address.toLowerCase());
    assert.equal(crateInfo.paymentAmount, parseUnits("60", 18));
    assert.equal(crateInfo.priceUsd, parseUnits("60", 2)); // $50 * 1.2x
  });
  
  it("Should reject unsupported token payments", async function () {
    const templateId = await crateFactory.read.nextTemplateId() - 1n;
    
    // Try to purchase with unsupported token
    await viem.assertions.revert(
      crateFactory.write.purchaseCrate([
        templateId,
        30n * 86400n,
        user1.account.address, // Not a Token Contract
        parseUnits("100", 6)
      ], { account: user1.account.address })
    );
  });
  
  it("Should reject insufficient token payments", async function () {
    const templateId = await crateFactory.read.nextTemplateId() - 1n;
    
    // Try to purchase with insufficient USDC
    await viem.assertions.revert(
      crateFactory.write.purchaseCrate([
        templateId,
        30n * 86400n,
        mockUSDC.address,
        parseUnits("50", 6) // Only $50, but need $100
      ], { account: user1.account.address })
    );
  });

  it("Should create templates with multiple lockup options", async function () {
    await crateFactory.write.createCrateTemplate([
      "Multi-Option Crate",
      "Crate with multiple lockup durations",
      0, // riskLevel
      1, // strategyId
      parseUnits("100", 2), // $100.00 USD base price
      [], // positions
      500, // revenueShareBps
      200, // platformFeeBps
      300, // performanceFeeBps
      "Low risk strategy",
      "Standard fees apply",
      [
        {
          duration: 30n * 86400n, // 30 days
          multiplierBps: 10000n, // 1.0x
          enabled: true
        },
        {
          duration: 90n * 86400n, // 90 days
          multiplierBps: 12000n, // 1.2x
          enabled: true
        }
      ],
      [zeroAddress] // No specific payment tokens
    ], { account: owner.account.address });
    
    const templateId = await crateFactory.read.nextTemplateId() - 1n;
    const template = await crateFactory.read.getCrateTemplate([templateId]);
    
    assert.equal(template.name, "Multi-Option Crate");
    assert.equal(template.lockupOptions.length, 2);
  });
  
  it("Should calculate correct prices with multipliers", async function () {
    await crateFactory.write.createCrateTemplate([
      "Price Test Crate",
      "Crate for testing price calculations",
      0, // riskLevel
      1, // strategyId
      parseUnits("100", 2), // $100.00 USD base price
      [], // positions
      500, // revenueShareBps
      200, // platformFeeBps
      300, // performanceFeeBps
      "Low risk strategy",
      "Standard fees apply",
      [
        {
          duration: 60n * 86400n, // 60 days
          multiplierBps: 20000n, // 2.0x
          enabled: true
        }
      ],
      [zeroAddress] // No specific payment tokens
    ], { account: owner.account.address });
    
    const templateId = await crateFactory.read.nextTemplateId() - 1n;
    
    // Calculate price for 60-day lockup with 2.0x multiplier
    const [priceUsd, multiplierBps] = await crateFactory.read.calculatePurchasePrice([templateId, 60n * 86400n]);
    
    assert.equal(priceUsd, parseUnits("200", 2)); // $100 * 2.0 = $200
    assert.equal(multiplierBps, 20000n); // 2.0x
  });

  it("Should create and retrieve crate templates", async function () {
    await crateFactory.write.createCrateTemplate([
      "Template Test",
      "A test template",
      0, // riskLevel
      1, // strategyId
      parseUnits("100", 2), // $100.00 USD base price
      [], // positions
      500, // revenueShareBps
      200, // platformFeeBps
      300, // performanceFeeBps
      "Low risk strategy",
      "Standard fees apply",
      [
        {
          duration: 30n * 86400n, // 30 days
          multiplierBps: 10000n, // 1.0x
          enabled: true
        }
      ],
      [zeroAddress] // No specific payment tokens
    ], { account: owner.account.address });
    
    const templateId = await crateFactory.read.nextTemplateId() - 1n;
    const template = await crateFactory.read.getCrateTemplate([templateId]);
    
    assert.equal(template.name, "Template Test");
    assert.equal(template.basePriceUsd, parseUnits("100", 2));
    assert.equal(template.lockupOptions.length, 1);
    assert.equal(template.lockupOptions[0].duration, 30n * 86400n);
    assert.equal(template.lockupOptions[0].multiplierBps, 10000n);
  });
  
  it("Should return active template IDs", async function () {
    // Create multiple templates
    await crateFactory.write.createCrateTemplate([
      "Active Template 1",
      "First active template",
      0, // riskLevel
      1, // strategyId
      parseUnits("100", 2), // $100.00 USD base price
      [], // positions
      500, // revenueShareBps
      200, // platformFeeBps
      300, // performanceFeeBps
      "Low risk strategy",
      "Standard fees apply",
      [
        {
          duration: 30n * 86400n,
          multiplierBps: 10000n,
          enabled: true
        }
      ],
      [zeroAddress]
    ], { account: owner.account.address });
    
    await crateFactory.write.createCrateTemplate([
      "Active Template 2",
      "Second active template",
      0, // riskLevel
      1, // strategyId
      parseUnits("200", 2), // $200.00 USD base price
      [], // positions
      500, // revenueShareBps
      200, // platformFeeBps
      300, // performanceFeeBps
      "Low risk strategy",
      "Standard fees apply",
      [
        {
          duration: 30n * 86400n,
          multiplierBps: 10000n,
          enabled: true
        }
      ],
      [zeroAddress]
    ], { account: owner.account.address });
    
    // Create a disabled template
    await crateFactory.write.createCrateTemplate([
      "Disabled Template",
      "This template will be disabled",
      0, // riskLevel
      1, // strategyId
      parseUnits("300", 2), // $300.00 USD base price
      [], // positions
      500, // revenueShareBps
      200, // platformFeeBps
      300, // performanceFeeBps
      "Low risk strategy",
      "Standard fees apply",
      [
        {
          duration: 30n * 86400n,
          multiplierBps: 10000n,
          enabled: true
        }
      ],
      [zeroAddress]
    ], { account: owner.account.address });
    
    const activeIds = await crateFactory.read.getActiveTemplateIds();
    assert.equal(activeIds.length, 2);
  });

  it("Should handle complete user flow: browse -> select -> purchase", async function () {
    // Step 1: Create multiple crate templates (simulating available crates)
    await crateFactory.write.createCrateTemplate([
      "Stable Crate",
      "Low risk, stable returns",
      0, // riskLevel
      1, // strategyId
      parseUnits("50", 2), // $50.00 USD base price
      [], // positions
      500, // revenueShareBps
      200, // platformFeeBps
      300, // performanceFeeBps
      "Low risk strategy",
      "Standard fees apply",
      [
        {
          duration: 30n * 86400n, // 30 days
          multiplierBps: 10000n, // 1.0x
          enabled: true
        },
        {
          duration: 90n * 86400n, // 90 days
          multiplierBps: 12000n, // 1.2x
          enabled: true
        }
      ],
      [mockUSDC.address, mockIDRX.address]
    ], { account: owner.account.address });
    
    // Step 2: Browse available crates (get active templates)
    const activeTemplateIds = await crateFactory.read.getActiveTemplateIds();
    assert.equal(activeTemplateIds.length, 1);
    
    // Step 3: Select a crate and view details
    const stableTemplateId = activeTemplateIds[0];
    const stableTemplate = await crateFactory.read.getCrateTemplate([stableTemplateId]);
    assert.equal(stableTemplate.name, "Stable Crate");
    
    // Step 4: Purchase crate with USDC
    const purchaseTx = await crateFactory.write.purchaseCrate([
      stableTemplateId,
      90n * 86400n, // 90 days
      mockUSDC.address,
      parseUnits("60", 6) // $60 USDC
    ], { account: user1.account.address });
    
    // Verify purchase
    const receipt = await publicClient.getTransactionReceipt({ hash: purchaseTx });
    const event = receipt.logs.find((log) => {
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
    
    assert.notEqual(event, undefined);
    
    const tokenId = await crateNFT.read.nextTokenId() - 1n;
    assert.equal((await crateNFT.read.ownerOf([tokenId])).toLowerCase(), user1.account.address.toLowerCase());
    
    const crateInfo = await crateNFT.read.crateInfo([tokenId]);
    assert.equal(crateInfo.paymentToken.toLowerCase(), mockUSDC.address.toLowerCase());
    assert.equal(crateInfo.paymentAmount, parseUnits("60", 6));
    assert.equal(crateInfo.priceUsd, parseUnits("60", 2)); // $50 * 1.2x
  });
});