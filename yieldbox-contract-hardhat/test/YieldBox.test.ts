import assert from "node:assert/strict";
import { describe, it } from "node:test";

import { network } from "hardhat";
import { parseUnits, zeroAddress, decodeEventLog } from "viem";

interface TestEnvironment {
  owner: any;
  user: any;
  other: any;
  mockUSDC: any;
  mockIDRX: any;
  strategyRegistry: any;
  mockYieldAdapter: any;
  mockYieldProtocol: any;
  crateNFT: any;
  crateFactory: any;
  publicClient: any;
}

async function setupEnvironment(options: { registerStrategy?: boolean } = {}): Promise<TestEnvironment> {
  const registerStrategy = options.registerStrategy ?? true;

  const { viem } = await network.connect();
  const publicClient = await viem.getPublicClient();
  const [owner, user, other] = await viem.getWalletClients();

  const mockUSDC = await viem.deployContract("MockUSDC", [
    owner.account.address,
    parseUnits("1000000", 6),
    6,
  ]);

  const mockIDRX = await viem.deployContract("MockIDRX", [
    owner.account.address,
    parseUnits("1000000", 2),
    2,
  ]);

  const erc6551Registry = await viem.deployContract("ERC6551Registry");
  const erc6551Account = await viem.deployContract("ERC6551Account");

  const strategyRegistry = await viem.deployContract("OpenCrateStrategyRegistry", [owner.account.address]);
  const mockYieldProtocol = await viem.deployContract("MockYieldProtocol", [owner.account.address]);
  const mockYieldAdapter = await viem.deployContract("MockYieldAdapter", [
    mockYieldProtocol.address,
    owner.account.address,
  ]);

  await mockYieldProtocol.write.setAdapter([mockYieldAdapter.address], { account: owner.account.address });

  const crateNFT = await viem.deployContract("OpenCrateNFT", [
    "OpenCrate",
    "CRATE",
    "https://metadata.opencrate.io/",
    owner.account.address,
    zeroAddress,
  ]);

  const crateFactory = await viem.deployContract("OpenCrateFactory", [
    crateNFT.address,
    erc6551Registry.address,
    erc6551Account.address,
    strategyRegistry.address,
    owner.account.address,
  ]);

  await crateNFT.write.setFactory([crateFactory.address], { account: owner.account.address });

  if (registerStrategy) {
    await strategyRegistry.write.registerStrategy(
      [mockYieldAdapter.address, "0x", 0, true],
      { account: owner.account.address },
    );
  }

  await crateNFT.write.addSupportedToken(
    [mockUSDC.address, parseUnits("1", 2), 6],
    { account: owner.account.address },
  );

  await crateNFT.write.addSupportedToken(
    [mockIDRX.address, parseUnits("16500", 2), 2],
    { account: owner.account.address },
  );

  // Distribute tokens to test participants
  await mockUSDC.write.transfer(
    [user.account.address, parseUnits("1000", 6)],
    { account: owner.account.address },
  );

  await mockIDRX.write.transfer(
    [user.account.address, parseUnits("1000", 2)],
    { account: owner.account.address },
  );

  return {
    owner,
    user,
    other,
    mockUSDC,
    mockIDRX,
    strategyRegistry,
    mockYieldAdapter,
    mockYieldProtocol,
    crateNFT,
    crateFactory,
    publicClient,
  };
}

async function createTemplate(
  env: TestEnvironment,
  overrides?: Partial<{
    name: string;
    description: string;
    riskLevel: number;
    strategyId: bigint;
    basePriceUsd: bigint;
    revenueShareBps: number;
    platformFeeBps: number;
    performanceFeeBps: number;
    riskDisclosure: string;
    feeDisclosure: string;
    lockups: { duration: bigint; multiplierBps: bigint; enabled: boolean }[];
    paymentTokens: `0x${string}`[];
  }>,
) {
  const templateId = await env.crateFactory.read.nextTemplateId();
  const lockups =
    overrides?.lockups ??
    [
      { duration: 30n * 86400n, multiplierBps: 11000n, enabled: true },
      { duration: 90n * 86400n, multiplierBps: 12000n, enabled: true },
    ];

  await env.crateFactory.write.createCrateTemplate(
    [
      overrides?.name ?? "Balanced Yield Crate",
      overrides?.description ?? "Diversified positions with moderate risk.",
      overrides?.riskLevel ?? 0,
      overrides?.strategyId ?? 0n,
      overrides?.basePriceUsd ?? parseUnits("100", 2),
      [],
      overrides?.revenueShareBps ?? 500,
      overrides?.platformFeeBps ?? 200,
      overrides?.performanceFeeBps ?? 300,
      overrides?.riskDisclosure ?? "Risk disclosure text",
      overrides?.feeDisclosure ?? "Fee disclosure text",
      lockups.map((option) => ({
        duration: option.duration,
        multiplierBps: option.multiplierBps,
        enabled: option.enabled,
      })),
      overrides?.paymentTokens ?? [env.mockUSDC.address],
    ],
    { account: env.owner.account.address },
  );

  return templateId;
}

describe("OpenCrate core flow", () => {
  it("prevents non-owners from managing strategies", async () => {
    const env = await setupEnvironment({ registerStrategy: false });

    await assert.rejects(
      env.strategyRegistry.write.registerStrategy(
        [env.mockYieldAdapter.address, "0x", 0, true],
        { account: env.user.account.address },
      ),
      (error: any) => {
        assert.match(error.message, /OwnableUnauthorizedAccount/);
        return true;
      },
    );
  });

  it("enforces template validation rules", async () => {
    const env = await setupEnvironment();

    await assert.rejects(
      env.crateFactory.write.createCrateTemplate(
        [
          "",
          "Missing name should revert",
          0,
          1n,
          parseUnits("100", 2),
          [],
          500,
          200,
          300,
          "Risk disclosure",
          "Fee disclosure",
          [{ duration: 30n * 86400n, multiplierBps: 11000n, enabled: true }],
          [env.mockUSDC.address],
        ],
        { account: env.owner.account.address },
      ),
      (error: any) => {
        assert.match(error.message, /TemplateNameRequired/);
        return true;
      },
    );

    await assert.rejects(
      env.crateFactory.write.createCrateTemplate(
        [
          "Valid Name",
          "Missing payment token should revert",
          0,
          1n,
          parseUnits("100", 2),
          [],
          500,
          200,
          300,
          "Risk disclosure",
          "Fee disclosure",
          [{ duration: 30n * 86400n, multiplierBps: 11000n, enabled: true }],
          [],
        ],
        { account: env.owner.account.address },
      ),
      (error: any) => {
        assert.match(error.message, /TemplatePaymentTokenRequired/);
        return true;
      },
    );
  });

  it("creates crate templates and exposes lockup metadata", async () => {
    const env = await setupEnvironment();
    const templateId = await createTemplate(env);

    const lockups = await env.crateFactory.read.getLockupOptions([templateId]);
    assert.equal(lockups.length, 2);

    const [priceUsd, multiplier] = await env.crateFactory.read.calculatePurchasePrice([
      templateId,
      90n * 86400n,
    ]);
    assert.equal(priceUsd, parseUnits("120", 2));
    assert.equal(Number(multiplier), 12000);
  });

  it("allows purchasing a crate and records payment details", async () => {
    const env = await setupEnvironment();
    const templateId = await createTemplate(env);

    await env.mockUSDC.write.approve(
      [env.crateNFT.address, parseUnits("1000", 6)],
      { account: env.user.account.address },
    );

    const purchaseHash = await env.crateFactory.write.purchaseCrate(
      [
        templateId,
        90n * 86400n,
        env.mockUSDC.address,
        parseUnits("120", 6),
      ],
      { account: env.user.account.address },
    );

    const receipt = await env.publicClient.getTransactionReceipt({ hash: purchaseHash });
    const decodedEvent = receipt.logs
      .map((log) => {
        try {
          return decodeEventLog({
            abi: env.crateFactory.abi,
            data: log.data,
            topics: log.topics,
          });
        } catch {
          return null;
        }
      })
      .find((entry) => entry?.eventName === "CratePurchased");

    assert.notEqual(decodedEvent, null);

    const tokenId = (await env.crateNFT.read.nextTokenId()) - 1n;
    const crateInfo = await env.crateNFT.read.crateInfo([tokenId]);

    assert.equal(crateInfo.paymentToken.toLowerCase(), env.mockUSDC.address.toLowerCase());
    assert.equal(crateInfo.paymentAmount, parseUnits("120", 6));
    assert.equal(crateInfo.priceUsd, parseUnits("120", 2));
    assert.equal((await env.crateNFT.read.ownerOf([tokenId])).toLowerCase(), env.user.account.address.toLowerCase());
  });

  it("rejects purchases with unsupported payment tokens", async () => {
    const env = await setupEnvironment();
    const templateId = await createTemplate(env);

    await assert.rejects(
      env.crateFactory.write.purchaseCrate(
        [
          templateId,
          30n * 86400n,
          zeroAddress,
          parseUnits("100", 6),
        ],
        { account: env.user.account.address },
      ),
      (error: any) => {
        assert.match(error.message, /TokenNotSupported/);
        return true;
      },
    );
  });

  it("disables and re-enables template lockup options", async () => {
    const env = await setupEnvironment();
    const templateId = await createTemplate(env);

    await env.crateFactory.write.disableCrateTemplate([templateId], { account: env.owner.account.address });

    let lockups = await env.crateFactory.read.getLockupOptions([templateId]);
    assert.ok(lockups.every((option: any) => option.enabled === false));

    await env.crateFactory.write.emergencyUnpauseTemplate([templateId], { account: env.owner.account.address });

    lockups = await env.crateFactory.read.getLockupOptions([templateId]);
    assert.ok(lockups.every((option: any) => option.enabled === true));
  });
});
