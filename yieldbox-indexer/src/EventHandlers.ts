/*
 * Please refer to https://docs.envio.dev for a thorough guide on all Envio indexer features
 */
import {
  MockPriceOracle,
  MockPriceOracle_OwnershipTransferred,
  MockPriceOracle_PriceUpdated,
  MockPriceOracle_TokenAdded,
  MockPriceOracle_TokenRemoved,
  MockUSDC,
  MockUSDC_Approval,
  MockUSDC_OwnershipTransferred,
  MockUSDC_Transfer,
  MockYieldAdapter,
  MockYieldAdapter_Deposited,
  MockYieldAdapter_OwnershipTransferred,
  MockYieldAdapter_Withdrawn,
  MockYieldAdapter_YieldClaimed,
  MockYieldProtocol,
  MockYieldProtocol_AdapterUpdated,
  MockYieldProtocol_Deposited,
  MockYieldProtocol_OwnershipTransferred,
  MockYieldProtocol_RewardRateUpdated,
  MockYieldProtocol_Withdrawn,
  MockYieldProtocol_YieldAccrued,
  MockYieldProtocol_YieldClaimed,
  OpenCrateFactory,
  OpenCrateFactory_CratePurchased,
  OpenCrateFactory_CrateTemplateCreated,
  OpenCrateFactory_CrateTemplateDisabled,
  OpenCrateFactory_CrateTemplateUpdated,
  OpenCrateFactory_EmergencyWithdraw,
  OpenCrateFactory_LockupOptionAdded,
  OpenCrateFactory_LockupOptionRemoved,
  OpenCrateFactory_LockupOptionUpdated,
  OpenCrateFactory_OwnershipTransferred,
  OpenCrateFactory_Paused,
  OpenCrateFactory_TreasuryUpdated,
  OpenCrateFactory_Unpaused,
  OpenCrateNFT,
  OpenCrateNFT_Approval,
  OpenCrateNFT_ApprovalForAll,
  OpenCrateNFT_BaseURIUpdated,
  OpenCrateNFT_BoostStatusUpdated,
  OpenCrateNFT_BoostUpdated,
  OpenCrateNFT_CrateMinted,
  OpenCrateNFT_EmergencyModeToggled,
  OpenCrateNFT_EmergencyUnlock,
  OpenCrateNFT_FactoryUpdated,
  OpenCrateNFT_FeeDisclosureUpdated,
  OpenCrateNFT_LifecycleUpdated,
  OpenCrateNFT_LockExtended,
  OpenCrateNFT_OwnershipTransferred,
  OpenCrateNFT_Paused,
  OpenCrateNFT_PositionMetricsUpdated,
  OpenCrateNFT_PositionsUpdated,
  OpenCrateNFT_PriceUpdated,
  OpenCrateNFT_RevenueShareUpdated,
  OpenCrateNFT_RiskDisclosureUpdated,
  OpenCrateNFT_TokenAdded,
  OpenCrateNFT_TokenPriceUpdated,
  OpenCrateNFT_TokenRemoved,
  OpenCrateNFT_Transfer,
  OpenCrateNFT_Unpaused,
  OpenCrateStrategyRegistry,
  OpenCrateStrategyRegistry_OwnershipTransferred,
  OpenCrateStrategyRegistry_StrategyRegistered,
  OpenCrateStrategyRegistry_StrategyStatusUpdated,
  OpenCrateStrategyRegistry_StrategyUpdated,
} from "generated";

MockPriceOracle.OwnershipTransferred.handler(async ({ event, context }) => {
  const entity: MockPriceOracle_OwnershipTransferred = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    previousOwner: event.params.previousOwner,
    newOwner: event.params.newOwner,
  };

  context.MockPriceOracle_OwnershipTransferred.set(entity);
});

MockPriceOracle.PriceUpdated.handler(async ({ event, context }) => {
  const entity: MockPriceOracle_PriceUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    token: event.params.token,
    priceUsd: event.params.priceUsd,
    timestamp: event.params.timestamp,
  };

  context.MockPriceOracle_PriceUpdated.set(entity);
});

MockPriceOracle.TokenAdded.handler(async ({ event, context }) => {
  const entity: MockPriceOracle_TokenAdded = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    token: event.params.token,
    priceUsd: event.params.priceUsd,
  };

  context.MockPriceOracle_TokenAdded.set(entity);
});

MockPriceOracle.TokenRemoved.handler(async ({ event, context }) => {
  const entity: MockPriceOracle_TokenRemoved = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    token: event.params.token,
  };

  context.MockPriceOracle_TokenRemoved.set(entity);
});

MockUSDC.Approval.handler(async ({ event, context }) => {
  const entity: MockUSDC_Approval = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    owner: event.params.owner,
    spender: event.params.spender,
    value: event.params.value,
  };

  context.MockUSDC_Approval.set(entity);
});

MockUSDC.OwnershipTransferred.handler(async ({ event, context }) => {
  const entity: MockUSDC_OwnershipTransferred = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    previousOwner: event.params.previousOwner,
    newOwner: event.params.newOwner,
  };

  context.MockUSDC_OwnershipTransferred.set(entity);
});

MockUSDC.Transfer.handler(async ({ event, context }) => {
  const entity: MockUSDC_Transfer = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    from: event.params.from,
    to: event.params.to,
    value: event.params.value,
  };

  context.MockUSDC_Transfer.set(entity);
});

MockYieldAdapter.Deposited.handler(async ({ event, context }) => {
  const entity: MockYieldAdapter_Deposited = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    account: event.params.account,
    receiver: event.params.receiver,
    amount: event.params.amount,
    data: event.params.data,
  };

  context.MockYieldAdapter_Deposited.set(entity);
});

MockYieldAdapter.OwnershipTransferred.handler(async ({ event, context }) => {
  const entity: MockYieldAdapter_OwnershipTransferred = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    previousOwner: event.params.previousOwner,
    newOwner: event.params.newOwner,
  };

  context.MockYieldAdapter_OwnershipTransferred.set(entity);
});

MockYieldAdapter.Withdrawn.handler(async ({ event, context }) => {
  const entity: MockYieldAdapter_Withdrawn = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    account: event.params.account,
    receiver: event.params.receiver,
    amount: event.params.amount,
    data: event.params.data,
  };

  context.MockYieldAdapter_Withdrawn.set(entity);
});

MockYieldAdapter.YieldClaimed.handler(async ({ event, context }) => {
  const entity: MockYieldAdapter_YieldClaimed = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    account: event.params.account,
    receiver: event.params.receiver,
    amount: event.params.amount,
    data: event.params.data,
  };

  context.MockYieldAdapter_YieldClaimed.set(entity);
});

MockYieldProtocol.AdapterUpdated.handler(async ({ event, context }) => {
  const entity: MockYieldProtocol_AdapterUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    adapter: event.params.adapter,
  };

  context.MockYieldProtocol_AdapterUpdated.set(entity);
});

MockYieldProtocol.Deposited.handler(async ({ event, context }) => {
  const entity: MockYieldProtocol_Deposited = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    account: event.params.account,
    receiver: event.params.receiver,
    amount: event.params.amount,
  };

  context.MockYieldProtocol_Deposited.set(entity);
});

MockYieldProtocol.OwnershipTransferred.handler(async ({ event, context }) => {
  const entity: MockYieldProtocol_OwnershipTransferred = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    previousOwner: event.params.previousOwner,
    newOwner: event.params.newOwner,
  };

  context.MockYieldProtocol_OwnershipTransferred.set(entity);
});

MockYieldProtocol.RewardRateUpdated.handler(async ({ event, context }) => {
  const entity: MockYieldProtocol_RewardRateUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    rewardRate: event.params.rewardRate,
  };

  context.MockYieldProtocol_RewardRateUpdated.set(entity);
});

MockYieldProtocol.Withdrawn.handler(async ({ event, context }) => {
  const entity: MockYieldProtocol_Withdrawn = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    account: event.params.account,
    receiver: event.params.receiver,
    amount: event.params.amount,
  };

  context.MockYieldProtocol_Withdrawn.set(entity);
});

MockYieldProtocol.YieldAccrued.handler(async ({ event, context }) => {
  const entity: MockYieldProtocol_YieldAccrued = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    account: event.params.account,
    amount: event.params.amount,
  };

  context.MockYieldProtocol_YieldAccrued.set(entity);
});

MockYieldProtocol.YieldClaimed.handler(async ({ event, context }) => {
  const entity: MockYieldProtocol_YieldClaimed = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    account: event.params.account,
    receiver: event.params.receiver,
    amount: event.params.amount,
  };

  context.MockYieldProtocol_YieldClaimed.set(entity);
});

OpenCrateFactory.CratePurchased.handler(async ({ event, context }) => {
  const entity: OpenCrateFactory_CratePurchased = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    templateId: event.params.templateId,
    tokenId: event.params.tokenId,
    purchaser: event.params.purchaser,
    paymentToken: event.params.paymentToken,
    paymentAmount: event.params.paymentAmount,
    lockupDuration: event.params.lockupDuration,
    multiplierBps: event.params.multiplierBps,
    timestamp: event.params.timestamp,
  };

  context.OpenCrateFactory_CratePurchased.set(entity);
});

OpenCrateFactory.CrateTemplateCreated.handler(async ({ event, context }) => {
  const entity: OpenCrateFactory_CrateTemplateCreated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    templateId: event.params.templateId,
    name: event.params.name,
    basePriceUsd: event.params.basePriceUsd,
    version: event.params.version,
  };

  context.OpenCrateFactory_CrateTemplateCreated.set(entity);
});

OpenCrateFactory.CrateTemplateDisabled.handler(async ({ event, context }) => {
  const entity: OpenCrateFactory_CrateTemplateDisabled = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    templateId: event.params.templateId,
  };

  context.OpenCrateFactory_CrateTemplateDisabled.set(entity);
});

OpenCrateFactory.CrateTemplateUpdated.handler(async ({ event, context }) => {
  const entity: OpenCrateFactory_CrateTemplateUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    templateId: event.params.templateId,
    newVersion: event.params.newVersion,
  };

  context.OpenCrateFactory_CrateTemplateUpdated.set(entity);
});

OpenCrateFactory.EmergencyWithdraw.handler(async ({ event, context }) => {
  const entity: OpenCrateFactory_EmergencyWithdraw = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    token: event.params.token,
    amount: event.params.amount,
    recipient: event.params.recipient,
  };

  context.OpenCrateFactory_EmergencyWithdraw.set(entity);
});

OpenCrateFactory.LockupOptionAdded.handler(async ({ event, context }) => {
  const entity: OpenCrateFactory_LockupOptionAdded = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    templateId: event.params.templateId,
    duration: event.params.duration,
    multiplierBps: event.params.multiplierBps,
  };

  context.OpenCrateFactory_LockupOptionAdded.set(entity);
});

OpenCrateFactory.LockupOptionRemoved.handler(async ({ event, context }) => {
  const entity: OpenCrateFactory_LockupOptionRemoved = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    templateId: event.params.templateId,
    duration: event.params.duration,
    multiplierBps: event.params.multiplierBps,
  };

  context.OpenCrateFactory_LockupOptionRemoved.set(entity);
});

OpenCrateFactory.LockupOptionUpdated.handler(async ({ event, context }) => {
  const entity: OpenCrateFactory_LockupOptionUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    templateId: event.params.templateId,
    duration: event.params.duration,
    multiplierBps: event.params.multiplierBps,
  };

  context.OpenCrateFactory_LockupOptionUpdated.set(entity);
});

OpenCrateFactory.OwnershipTransferred.handler(async ({ event, context }) => {
  const entity: OpenCrateFactory_OwnershipTransferred = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    previousOwner: event.params.previousOwner,
    newOwner: event.params.newOwner,
  };

  context.OpenCrateFactory_OwnershipTransferred.set(entity);
});

OpenCrateFactory.Paused.handler(async ({ event, context }) => {
  const entity: OpenCrateFactory_Paused = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    account: event.params.account,
  };

  context.OpenCrateFactory_Paused.set(entity);
});

OpenCrateFactory.TreasuryUpdated.handler(async ({ event, context }) => {
  const entity: OpenCrateFactory_TreasuryUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    oldTreasury: event.params.oldTreasury,
    newTreasury: event.params.newTreasury,
  };

  context.OpenCrateFactory_TreasuryUpdated.set(entity);
});

OpenCrateFactory.Unpaused.handler(async ({ event, context }) => {
  const entity: OpenCrateFactory_Unpaused = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    account: event.params.account,
  };

  context.OpenCrateFactory_Unpaused.set(entity);
});

OpenCrateNFT.Approval.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_Approval = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    owner: event.params.owner,
    approved: event.params.approved,
    tokenId: event.params.tokenId,
  };

  context.OpenCrateNFT_Approval.set(entity);
});

OpenCrateNFT.ApprovalForAll.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_ApprovalForAll = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    owner: event.params.owner,
    operator: event.params.operator,
    approved: event.params.approved,
  };

  context.OpenCrateNFT_ApprovalForAll.set(entity);
});

OpenCrateNFT.BaseURIUpdated.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_BaseURIUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    baseURI: event.params.baseURI,
  };

  context.OpenCrateNFT_BaseURIUpdated.set(entity);
});

OpenCrateNFT.BoostStatusUpdated.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_BoostStatusUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    tokenId: event.params.tokenId,
    active: event.params.active,
    boostMultiplierBps: event.params.boostMultiplierBps,
  };

  context.OpenCrateNFT_BoostStatusUpdated.set(entity);
});

OpenCrateNFT.BoostUpdated.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_BoostUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    tokenId: event.params.tokenId,
    boostMultiplierBps: event.params.boostMultiplierBps,
  };

  context.OpenCrateNFT_BoostUpdated.set(entity);
});

OpenCrateNFT.CrateMinted.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_CrateMinted = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    tokenId: event.params.tokenId,
    to: event.params.to,
    riskLevel: event.params.riskLevel,
    strategyId: event.params.strategyId,
    account: event.params.account,
    priceUsd: event.params.priceUsd,
    boostMultiplierBps: event.params.boostMultiplierBps,
    lockedUntil: event.params.lockedUntil,
    paymentToken: event.params.paymentToken,
    paymentAmount: event.params.paymentAmount,
  };

  context.OpenCrateNFT_CrateMinted.set(entity);
});

OpenCrateNFT.EmergencyModeToggled.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_EmergencyModeToggled = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    active: event.params.active,
  };

  context.OpenCrateNFT_EmergencyModeToggled.set(entity);
});

OpenCrateNFT.EmergencyUnlock.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_EmergencyUnlock = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    tokenId: event.params.tokenId,
    owner: event.params.owner,
  };

  context.OpenCrateNFT_EmergencyUnlock.set(entity);
});

OpenCrateNFT.FactoryUpdated.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_FactoryUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    newFactory: event.params.newFactory,
  };

  context.OpenCrateNFT_FactoryUpdated.set(entity);
});

OpenCrateNFT.FeeDisclosureUpdated.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_FeeDisclosureUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    tokenId: event.params.tokenId,
    feeDisclosure: event.params.feeDisclosure,
  };

  context.OpenCrateNFT_FeeDisclosureUpdated.set(entity);
});

OpenCrateNFT.LifecycleUpdated.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_LifecycleUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    tokenId: event.params.tokenId,
    lastRebalanceAt: event.params.lastRebalanceAt,
    nextHarvestAt: event.params.nextHarvestAt,
    accruedYieldUsd: event.params.accruedYieldUsd,
  };

  context.OpenCrateNFT_LifecycleUpdated.set(entity);
});

OpenCrateNFT.LockExtended.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_LockExtended = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    tokenId: event.params.tokenId,
    lockedUntil: event.params.lockedUntil,
  };

  context.OpenCrateNFT_LockExtended.set(entity);
});

OpenCrateNFT.OwnershipTransferred.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_OwnershipTransferred = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    previousOwner: event.params.previousOwner,
    newOwner: event.params.newOwner,
  };

  context.OpenCrateNFT_OwnershipTransferred.set(entity);
});

OpenCrateNFT.Paused.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_Paused = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    account: event.params.account,
  };

  context.OpenCrateNFT_Paused.set(entity);
});

OpenCrateNFT.PositionMetricsUpdated.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_PositionMetricsUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    tokenId: event.params.tokenId,
    positionIndex: event.params.positionIndex,
    details_0: event.params.details
        [0]
    ,
    details_1: event.params.details
        [1]
    ,
    details_2: event.params.details
        [2]
    ,
    details_3: event.params.details
        [3]
    ,
    details_4: event.params.details
        [4]
    ,
    details_5: event.params.details
        [5]
    ,
    details_6: event.params.details
        [6]
    ,
    details_7: event.params.details
        [7]
    ,
    details_8: event.params.details
        [8]
    ,
    details_9: event.params.details
        [9]
    ,
    details_10: event.params.details
        [10]
    ,
    details_11: event.params.details
        [11]
    ,
    details_12: event.params.details
        [12]
    ,
    details_13: event.params.details
        [13]
    ,
    details_14: event.params.details
        [14]
    ,
    details_15: event.params.details
        [15]
    ,
  };

  context.OpenCrateNFT_PositionMetricsUpdated.set(entity);
});

OpenCrateNFT.PositionsUpdated.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_PositionsUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    tokenId: event.params.tokenId,
    positionCount: event.params.positionCount,
    updater: event.params.updater,
  };

  context.OpenCrateNFT_PositionsUpdated.set(entity);
});

OpenCrateNFT.PriceUpdated.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_PriceUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    tokenId: event.params.tokenId,
    priceUsd: event.params.priceUsd,
  };

  context.OpenCrateNFT_PriceUpdated.set(entity);
});

OpenCrateNFT.RevenueShareUpdated.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_RevenueShareUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    tokenId: event.params.tokenId,
    revenueShareBps: event.params.revenueShareBps,
    platformFeeBps: event.params.platformFeeBps,
    performanceFeeBps: event.params.performanceFeeBps,
  };

  context.OpenCrateNFT_RevenueShareUpdated.set(entity);
});

OpenCrateNFT.RiskDisclosureUpdated.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_RiskDisclosureUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    tokenId: event.params.tokenId,
    riskDisclosure: event.params.riskDisclosure,
  };

  context.OpenCrateNFT_RiskDisclosureUpdated.set(entity);
});

OpenCrateNFT.TokenAdded.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_TokenAdded = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    token: event.params.token,
    priceUsd: event.params.priceUsd,
    decimals: event.params.decimals,
  };

  context.OpenCrateNFT_TokenAdded.set(entity);
});

OpenCrateNFT.TokenPriceUpdated.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_TokenPriceUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    token: event.params.token,
    priceUsd: event.params.priceUsd,
  };

  context.OpenCrateNFT_TokenPriceUpdated.set(entity);
});

OpenCrateNFT.TokenRemoved.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_TokenRemoved = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    token: event.params.token,
  };

  context.OpenCrateNFT_TokenRemoved.set(entity);
});

OpenCrateNFT.Transfer.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_Transfer = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    from: event.params.from,
    to: event.params.to,
    tokenId: event.params.tokenId,
  };

  context.OpenCrateNFT_Transfer.set(entity);
});

OpenCrateNFT.Unpaused.handler(async ({ event, context }) => {
  const entity: OpenCrateNFT_Unpaused = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    account: event.params.account,
  };

  context.OpenCrateNFT_Unpaused.set(entity);
});

OpenCrateStrategyRegistry.OwnershipTransferred.handler(async ({ event, context }) => {
  const entity: OpenCrateStrategyRegistry_OwnershipTransferred = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    previousOwner: event.params.previousOwner,
    newOwner: event.params.newOwner,
  };

  context.OpenCrateStrategyRegistry_OwnershipTransferred.set(entity);
});

OpenCrateStrategyRegistry.StrategyRegistered.handler(async ({ event, context }) => {
  const entity: OpenCrateStrategyRegistry_StrategyRegistered = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    strategyId: event.params.strategyId,
    adapter: event.params.adapter,
    riskLevel: event.params.riskLevel,
  };

  context.OpenCrateStrategyRegistry_StrategyRegistered.set(entity);
});

OpenCrateStrategyRegistry.StrategyStatusUpdated.handler(async ({ event, context }) => {
  const entity: OpenCrateStrategyRegistry_StrategyStatusUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    strategyId: event.params.strategyId,
    active: event.params.active,
  };

  context.OpenCrateStrategyRegistry_StrategyStatusUpdated.set(entity);
});

OpenCrateStrategyRegistry.StrategyUpdated.handler(async ({ event, context }) => {
  const entity: OpenCrateStrategyRegistry_StrategyUpdated = {
    id: `${event.chainId}_${event.block.number}_${event.logIndex}`,
    strategyId: event.params.strategyId,
    adapter: event.params.adapter,
    riskLevel: event.params.riskLevel,
    adapterData: event.params.adapterData,
  };

  context.OpenCrateStrategyRegistry_StrategyUpdated.set(entity);
});
