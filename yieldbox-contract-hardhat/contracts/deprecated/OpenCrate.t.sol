// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Test.sol";

import { OpenCrateNFTLegacy } from "./OpenCrateNFTLegacy.sol";
import { OpenCrateFactoryLegacy } from "./OpenCrateFactoryLegacy.sol";
import "../strategies/OpenCrateStrategyRegistry.sol";
import "../adapters/MockYieldAdapter.sol";
import "../mock/MockYieldProtocol.sol";
import "../interfaces/IDeFiAdapter.sol";
import "../ERC6551Registry.sol";
import "../ERC6551Account.sol";

contract OpenCrateTest is Test {
    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");
    address internal other = makeAddr("other");

    OpenCrateNFTLegacy internal crateNFT;
    OpenCrateFactoryLegacy internal factory;
    OpenCrateStrategyRegistry internal strategyRegistry;
    MockYieldProtocol internal yieldProtocol;
    MockYieldAdapter internal yieldAdapter;
    ERC6551Registry internal accountRegistry;
    ERC6551Account internal accountImplementation;

    uint8 internal constant RISK_HIGH = 0;
    uint256 internal constant DEFAULT_PRICE_USD = 750; // $7.50 with 2 decimals
    uint16 internal constant DEFAULT_BOOST_BPS = 10_000;
    uint64 internal constant DEFAULT_LOCK_DURATION = 0;
    uint16 internal constant DEFAULT_REVENUE_SHARE_BPS = 1_000;
    uint16 internal constant DEFAULT_PLATFORM_FEE_BPS = 200;
    uint16 internal constant DEFAULT_PERFORMANCE_FEE_BPS = 500;
    string internal constant DEFAULT_RISK_DISCLOSURE = "Risk disclosure";
    string internal constant DEFAULT_FEE_DISCLOSURE = "Fee disclosure";
    uint64 internal constant DEFAULT_LAST_REBALANCE_AT = 0;
    uint64 internal constant DEFAULT_NEXT_HARVEST_AT = 0;
    uint256 internal constant DEFAULT_ACCRUED_YIELD_USD = 0;
    bool internal constant DEFAULT_BOOST_ACTIVE = false;

    function setUp() public {
        vm.startPrank(owner);

        accountRegistry = new ERC6551Registry();
        accountImplementation = new ERC6551Account();

        strategyRegistry = new OpenCrateStrategyRegistry(owner);

        yieldProtocol = new MockYieldProtocol(owner);
        yieldAdapter = new MockYieldAdapter(yieldProtocol, owner);
        yieldProtocol.setAdapter(address(yieldAdapter));

        crateNFT = new OpenCrateNFTLegacy("OpenCrate", "CRATE", "https://metadata/", owner, address(0));

        factory = new OpenCrateFactoryLegacy(
            crateNFT,
            accountRegistry,
            address(accountImplementation),
            strategyRegistry,
            owner
        );
        crateNFT.setFactory(address(factory));

        strategyRegistry.registerStrategy(address(yieldAdapter), bytes(""), RISK_HIGH, true);

        vm.stopPrank();
    }

    function _emptyPositions() internal pure returns (OpenCrateNFTLegacy.PositionPayload[] memory positions) {
        positions = new OpenCrateNFTLegacy.PositionPayload[](0);
    }

    function _buildMintParams(address to, uint256 salt) internal pure returns (OpenCrateFactoryLegacy.MintParams memory params) {
        params.to = to;
        params.riskLevel = RISK_HIGH;
        params.strategyId = 1;
        params.salt = salt;
        params.priceUsd = DEFAULT_PRICE_USD;
        params.boostMultiplierBps = DEFAULT_BOOST_BPS;
        params.lockDuration = DEFAULT_LOCK_DURATION;
        params.creator = to;
        params.revenueShareBps = DEFAULT_REVENUE_SHARE_BPS;
        params.platformFeeBps = DEFAULT_PLATFORM_FEE_BPS;
        params.performanceFeeBps = DEFAULT_PERFORMANCE_FEE_BPS;
        params.riskDisclosure = DEFAULT_RISK_DISCLOSURE;
        params.feeDisclosure = DEFAULT_FEE_DISCLOSURE;
        params.lastRebalanceAt = DEFAULT_LAST_REBALANCE_AT;
        params.nextHarvestAt = DEFAULT_NEXT_HARVEST_AT;
        params.accruedYieldUsd = DEFAULT_ACCRUED_YIELD_USD;
        params.boostActive = DEFAULT_BOOST_ACTIVE;
        params.accountInitData = bytes("");
        params.adapterData = bytes("");
    }

    function _mintDefaultCrate(address recipient, uint256 salt, bytes memory adapterData)
        internal
        returns (uint256 tokenId, address account)
    {
        OpenCrateFactoryLegacy.MintParams memory params = _buildMintParams(recipient, salt);
        params.adapterData = adapterData;

        vm.prank(recipient);
        (tokenId, account) = factory.mintCrate(params, _emptyPositions());
    }

    function _mintCustomCrate(
        address recipient,
        uint256 salt,
        OpenCrateFactoryLegacy.MintParams memory params,
        OpenCrateNFTLegacy.PositionPayload[] memory positions
    ) internal returns (uint256 tokenId, address account) {
        vm.prank(recipient);
        (tokenId, account) = factory.mintCrate(params, positions);
    }

    function _executeFromAccount(address crateOwner, address account, address target, bytes memory data) internal {
        vm.prank(crateOwner);
        ERC6551Account(payable(account)).executeCall(target, 0, data);
    }

    function testStrategyRegistryLifecycle() public {
        vm.startPrank(owner);

        uint256 newStrategyId = strategyRegistry.registerStrategy(address(yieldAdapter), hex"00", RISK_HIGH, true);
        assertEq(newStrategyId, 2);

        OpenCrateStrategyRegistry.StrategyConfig memory config = strategyRegistry.strategy(newStrategyId);
        assertEq(config.adapter, address(yieldAdapter));
        assertEq(config.riskLevel, RISK_HIGH);
        assertTrue(config.active);
        assertEq(config.adapterData.length, 1);

        strategyRegistry.updateStrategy(newStrategyId, address(yieldAdapter), hex"1234", RISK_HIGH);
        config = strategyRegistry.strategy(newStrategyId);
        assertEq(config.adapterData, hex"1234");

        strategyRegistry.setStrategyStatus(newStrategyId, false);
        config = strategyRegistry.strategy(newStrategyId);
        assertFalse(config.active);

        vm.stopPrank();
    }

    function testStrategyRegistryAccessControl() public {
        vm.expectRevert(OpenCrateStrategyRegistry.StrategyAdapterRequired.selector);
        vm.prank(owner);
        strategyRegistry.registerStrategy(address(0), bytes(""), RISK_HIGH, true);

        vm.expectRevert(
            abi.encodeWithSelector(OpenCrateStrategyRegistry.StrategyUnsupportedRisk.selector, uint8(10))
        );
        vm.prank(owner);
        strategyRegistry.registerStrategy(address(yieldAdapter), bytes(""), 10, true);

        vm.expectRevert(
            abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, user)
        );
        vm.prank(user);
        strategyRegistry.registerStrategy(address(yieldAdapter), bytes(""), RISK_HIGH, true);
    }

    function _assertDefaultCrateInfo(OpenCrateNFTLegacy.CrateInfo memory info, address expectedOwner) internal view {
        assertEq(info.riskLevel, RISK_HIGH);
        assertEq(info.strategyId, 1);
        assertEq(info.creator, expectedOwner);
        assertEq(info.priceUsd, DEFAULT_PRICE_USD);
        assertEq(info.boostMultiplierBps, DEFAULT_BOOST_BPS);
        assertEq(info.boostActive, DEFAULT_BOOST_ACTIVE);
        assertEq(info.revenueShareBps, DEFAULT_REVENUE_SHARE_BPS);
        assertEq(info.platformFeeBps, DEFAULT_PLATFORM_FEE_BPS);
        assertEq(info.performanceFeeBps, DEFAULT_PERFORMANCE_FEE_BPS);
        assertEq(info.riskDisclosure, DEFAULT_RISK_DISCLOSURE);
        assertEq(info.feeDisclosure, DEFAULT_FEE_DISCLOSURE);
        assertEq(info.accruedYieldUsd, DEFAULT_ACCRUED_YIELD_USD);
        assertEq(info.lockedUntil, 0);
        assertEq(info.lastLockAt, 0);
        assertEq(info.lastBoostAt, 0);
    }

    function testOpenCrateNFTLegacyFactoryMinting() public {
        (uint256 tokenId, address account) = _mintDefaultCrate(user, 777, abi.encode(user));
        assertEq(tokenId, 1);
        assertEq(crateNFT.ownerOf(tokenId), user);

        OpenCrateNFTLegacy.CrateInfo memory info = crateNFT.crateInfo(tokenId);
        assertEq(info.account, account);
        assertGt(info.mintedAt, 0);
        _assertDefaultCrateInfo(info, user);

        assertEq(crateNFT.nextTokenId(), 2);
        assertEq(crateNFT.totalMinted(), 1);

        (address adapter, bytes memory adapterData) = factory.crateAdapter(tokenId);
        assertEq(adapter, address(yieldAdapter));
        assertEq(adapterData, abi.encode(user));

        OpenCrateFactoryLegacy.CrateDeployment memory deployment = factory.crateDeployment(tokenId);
        assertEq(deployment.strategyId, 1);
        assertEq(deployment.riskLevel, RISK_HIGH);
        assertEq(deployment.salt, 777);
        assertEq(deployment.account, account);
        assertEq(deployment.positionCount, 0);
    }

    function testOpenCrateNFTLegacyOnlyFactoryCanMint() public {
        vm.expectRevert(OpenCrateNFTLegacy.Unauthorized.selector);
        vm.prank(user);
        crateNFT.mintCrate(
            user,
            RISK_HIGH,
            1,
            address(0x1234),
            DEFAULT_PRICE_USD,
            DEFAULT_BOOST_BPS,
            DEFAULT_LOCK_DURATION,
            user,
            DEFAULT_REVENUE_SHARE_BPS,
            DEFAULT_PLATFORM_FEE_BPS,
            DEFAULT_PERFORMANCE_FEE_BPS,
            DEFAULT_RISK_DISCLOSURE,
            DEFAULT_FEE_DISCLOSURE,
            DEFAULT_LAST_REBALANCE_AT,
            DEFAULT_NEXT_HARVEST_AT,
            DEFAULT_ACCRUED_YIELD_USD,
            DEFAULT_BOOST_ACTIVE,
            _emptyPositions()
        );
    }

    function testFactoryPredictAccountMatchesDeployment() public {
        OpenCrateFactoryLegacy.MintParams memory params = _buildMintParams(user, 42);
        OpenCrateNFTLegacy.PositionPayload[] memory positions = _emptyPositions();

        address predicted = factory.predictAccountForNext(params.salt);
        vm.prank(user);
        (uint256 tokenId, address account) = factory.mintCrate(params, positions);
        assertEq(tokenId, 1);
        assertEq(account, predicted);

        address predictedById = factory.predictAccount(tokenId, params.salt);
        assertEq(predictedById, account);
        assertEq(crateNFT.ownerOf(tokenId), user);
    }

    function testFactoryRejectsInactiveStrategy() public {
        vm.prank(owner);
        strategyRegistry.setStrategyStatus(1, false);

        OpenCrateFactoryLegacy.MintParams memory params = _buildMintParams(user, 1);
        OpenCrateNFTLegacy.PositionPayload[] memory positions = _emptyPositions();

        vm.expectRevert(abi.encodeWithSelector(OpenCrateFactoryLegacy.StrategyInactive.selector, params.strategyId));
        vm.prank(user);
        factory.mintCrate(params, positions);
    }

    function testFactoryRejectsRiskMismatch() public {
        OpenCrateFactoryLegacy.MintParams memory params = _buildMintParams(user, 1);
        params.riskLevel = 1;
        OpenCrateNFTLegacy.PositionPayload[] memory positions = _emptyPositions();

        vm.expectRevert(abi.encodeWithSelector(OpenCrateFactoryLegacy.StrategyRiskMismatch.selector, RISK_HIGH, params.riskLevel));
        vm.prank(user);
        factory.mintCrate(params, positions);
    }

    function testMintCrateRejectsPriceBelowMin() public {
        OpenCrateFactoryLegacy.MintParams memory params = _buildMintParams(user, 99);
        params.priceUsd = crateNFT.MIN_PRICE_USD() - 1;
        OpenCrateNFTLegacy.PositionPayload[] memory positions = _emptyPositions();

        vm.expectRevert(OpenCrateNFTLegacy.InvalidPrice.selector);
        vm.prank(user);
        factory.mintCrate(params, positions);
    }

    function testMintCrateRejectsPriceAboveMax() public {
        OpenCrateFactoryLegacy.MintParams memory params = _buildMintParams(user, 98);
        params.priceUsd = crateNFT.MAX_PRICE_USD() + 1;
        OpenCrateNFTLegacy.PositionPayload[] memory positions = _emptyPositions();

        vm.expectRevert(OpenCrateNFTLegacy.InvalidPrice.selector);
        vm.prank(user);
        factory.mintCrate(params, positions);
    }

    function testMintCrateRejectsBoostOutsideRange() public {
        OpenCrateFactoryLegacy.MintParams memory params = _buildMintParams(user, 97);
        params.boostMultiplierBps = DEFAULT_BOOST_BPS - 1;
        OpenCrateNFTLegacy.PositionPayload[] memory positions = _emptyPositions();

        vm.expectRevert(OpenCrateNFTLegacy.InvalidBoost.selector);
        vm.prank(user);
        factory.mintCrate(params, positions);
    }

    function testMintCrateRejectsLockDurationAboveMax() public {
        OpenCrateFactoryLegacy.MintParams memory params = _buildMintParams(user, 96);
        params.lockDuration = uint64(uint256(crateNFT.MAX_LOCK_DURATION()) + 1);
        OpenCrateNFTLegacy.PositionPayload[] memory positions = _emptyPositions();

        vm.expectRevert(OpenCrateNFTLegacy.InvalidLockDuration.selector);
        vm.prank(user);
        factory.mintCrate(params, positions);
    }

    function testUpdatePrice() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 12, bytes(""));
        uint256 newPrice = DEFAULT_PRICE_USD + 100;

        vm.prank(user);
        crateNFT.updatePrice(tokenId, newPrice);

        OpenCrateNFTLegacy.CrateInfo memory info = crateNFT.crateInfo(tokenId);
        assertEq(info.priceUsd, newPrice);
    }

    function testUpdatePriceRequiresAuthorization() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 13, bytes(""));

        vm.expectRevert(OpenCrateNFTLegacy.NotApprovedOrOwner.selector);
        vm.prank(other);
        crateNFT.updatePrice(tokenId, DEFAULT_PRICE_USD + 50);
    }

    function testSetBoostMultiplier() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 15, bytes(""));
        uint16 newBoost = DEFAULT_BOOST_BPS + 2_000;

        vm.prank(user);
        crateNFT.setBoostMultiplier(tokenId, newBoost);

        OpenCrateNFTLegacy.CrateInfo memory info = crateNFT.crateInfo(tokenId);
        assertEq(info.boostMultiplierBps, newBoost);
        assertTrue(info.boostActive);
        assertGt(info.lastBoostAt, 0);
    }

    function testSetBoostStatus() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 21, bytes(""));

        vm.prank(user);
        crateNFT.setBoostStatus(tokenId, true, DEFAULT_BOOST_BPS + 1000);

        OpenCrateNFTLegacy.CrateInfo memory info = crateNFT.crateInfo(tokenId);
        assertTrue(info.boostActive);
        assertEq(info.boostMultiplierBps, DEFAULT_BOOST_BPS + 1000);
        assertGt(info.lastBoostAt, 0);
    }

    function testExtendLock() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 18, bytes(""));
        uint64 duration = 30 days;

        vm.prank(user);
        crateNFT.extendLock(tokenId, duration);

        OpenCrateNFTLegacy.CrateInfo memory info = crateNFT.crateInfo(tokenId);
        assertEq(info.lockedUntil, uint64(block.timestamp) + duration);
        assertGt(info.lastLockAt, 0);
    }

    function testExtendLockRejectsOutOfRange() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 19, bytes(""));
        uint64 duration = uint64(uint256(crateNFT.MAX_LOCK_DURATION()) + 1);

        vm.expectRevert(OpenCrateNFTLegacy.InvalidLockDuration.selector);
        vm.prank(user);
        crateNFT.extendLock(tokenId, duration);
    }

    function testUpdatePositions() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 22, bytes(""));

        uint256 currentTime = block.timestamp;
        OpenCrateNFTLegacy.PositionPayload[] memory positions = new OpenCrateNFTLegacy.PositionPayload[](2);
        positions[0] = OpenCrateNFTLegacy.PositionPayload({
            protocol: "Aave",
            asset: "USDC",
            strategyType: "Lending",
            chain: "Ethereum",
            infoURL: "https://aave.com",
            allocationBps: 6_000,
            allocationUsd: 6000,
            netApyBps: 500,
            baseAprBps: 400,
            incentivesAprBps: 150,
            feeBps: 50,
            riskScore: 2,
            openedAt: uint64(currentTime > 1 days ? currentTime - 1 days : 0),
            lastRebalancedAt: uint64(currentTime > 12 hours ? currentTime - 12 hours : 0),
            nextHarvestAt: uint64(currentTime + 1 days),
            accruedYieldUsd: 1234
        });
        positions[1] = OpenCrateNFTLegacy.PositionPayload({
            protocol: "Uniswap",
            asset: "ETH/USDC",
            strategyType: "LP",
            chain: "Arbitrum",
            infoURL: "https://uniswap.org",
            allocationBps: 4_000,
            allocationUsd: 4000,
            netApyBps: 800,
            baseAprBps: 600,
            incentivesAprBps: 300,
            feeBps: 100,
            riskScore: 3,
            openedAt: uint64(currentTime > 2 days ? currentTime - 2 days : 0),
            lastRebalancedAt: uint64(currentTime > 6 hours ? currentTime - 6 hours : 0),
            nextHarvestAt: uint64(currentTime + 2 days),
            accruedYieldUsd: 5678
        });

        vm.prank(user);
        crateNFT.updatePositions(tokenId, positions);

        OpenCrateNFTLegacy.PositionDetails[] memory stored = crateNFT.getPositions(tokenId);
        assertEq(stored.length, 2);
        assertEq(stored[0].protocol, "Aave");
        assertEq(crateNFT.positionsCount(tokenId), 2);
        assertEq(factory.crateDeployment(tokenId).positionCount, 0); // factory storage unaffected
    }

    function testUpdatePositionsRevertsOnAllocationOverflow() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 23, bytes(""));

        uint256 currentTime = block.timestamp;
        OpenCrateNFTLegacy.PositionPayload[] memory positions = new OpenCrateNFTLegacy.PositionPayload[](1);
        positions[0] = OpenCrateNFTLegacy.PositionPayload({
            protocol: "Balancer",
            asset: "ETH",
            strategyType: "Staking",
            chain: "Ethereum",
            infoURL: "https://balancer.fi",
            allocationBps: 11_000,
            allocationUsd: 10000,
            netApyBps: 700,
            baseAprBps: 500,
            incentivesAprBps: 200,
            feeBps: 100,
            riskScore: 4,
            openedAt: uint64(currentTime > 1 days ? currentTime - 1 days : 0),
            lastRebalancedAt: uint64(currentTime > 1 hours ? currentTime - 1 hours : 0),
            nextHarvestAt: uint64(currentTime + 1 days),
            accruedYieldUsd: 100
        });

        vm.expectRevert(OpenCrateNFTLegacy.InvalidBps.selector);
        vm.prank(user);
        crateNFT.updatePositions(tokenId, positions);
    }

    function testUpdateLifecycle() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 24, bytes(""));
        vm.prank(user);
        crateNFT.updateLifecycle(tokenId, uint64(block.timestamp), uint64(block.timestamp + 1 days), 12345);
        OpenCrateNFTLegacy.CrateInfo memory info = crateNFT.crateInfo(tokenId);
        assertEq(info.lastRebalanceAt, uint64(block.timestamp));
        assertEq(info.nextHarvestAt, uint64(block.timestamp + 1 days));
        assertEq(info.accruedYieldUsd, 12345);
    }

    function testUpdateRevenueShare() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 25, bytes(""));
        vm.prank(user);
        crateNFT.updateRevenueShare(tokenId, 2_000, 500, 300);
        OpenCrateNFTLegacy.CrateInfo memory info = crateNFT.crateInfo(tokenId);
        assertEq(info.revenueShareBps, 2_000);
        assertEq(info.platformFeeBps, 500);
        assertEq(info.performanceFeeBps, 300);
    }

    function testUpdateRevenueShareRejectsInvalid() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 26, bytes(""));
        vm.expectRevert(OpenCrateNFTLegacy.InvalidBps.selector);
        vm.prank(user);
        crateNFT.updateRevenueShare(tokenId, 9_000, 2_000, 100);
    }

    function testUpdateDisclosures() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 27, bytes(""));
        vm.prank(user);
        crateNFT.updateDisclosures(tokenId, "New risk", "New fee");
        OpenCrateNFTLegacy.CrateInfo memory info = crateNFT.crateInfo(tokenId);
        assertEq(info.riskDisclosure, "New risk");
        assertEq(info.feeDisclosure, "New fee");
    }

    function testMintCrateStoresCustomPriceBoostLock() public {
        OpenCrateFactoryLegacy.MintParams memory params = _buildMintParams(user, 50);
        params.priceUsd = 99900;
        params.boostMultiplierBps = 15_000;
        params.lockDuration = 10 days;
        params.boostActive = true;
        params.lastRebalanceAt = 123;
        params.nextHarvestAt = 456;
        params.accruedYieldUsd = 789;

        vm.prank(user);
        (uint256 tokenId, address account) = factory.mintCrate(params, _emptyPositions());

        OpenCrateNFTLegacy.CrateInfo memory info = crateNFT.crateInfo(tokenId);
        assertEq(info.account, account);
        assertEq(info.priceUsd, 99900);
        assertEq(info.lockedUntil, uint64(block.timestamp + 10 days));
        assertEq(info.lastLockAt, uint64(block.timestamp));
        assertTrue(info.boostActive);
        assertGt(info.lastBoostAt, 0);
        assertEq(info.lastRebalanceAt, 123);
        assertEq(info.nextHarvestAt, 456);
        assertEq(info.accruedYieldUsd, 789);
    }

    function testMockYieldAdapterDepositWithdrawClaimFlow() public {
        (uint256 tokenId, address account) = _mintDefaultCrate(user, 5, bytes(""));
        assertEq(tokenId, 1);

        _executeFromAccount(
            user,
            account,
            address(yieldAdapter),
            abi.encodeWithSelector(MockYieldAdapter.deposit.selector, account, 100, bytes(""))
        );

        MockYieldProtocol.Position memory pos = yieldProtocol.position(account);
        assertEq(pos.principal, 100);
        assertEq(pos.pendingYield, 0);
        assertEq(yieldAdapter.currentValue(account), 100);

        IDeFiAdapter.Position memory adapterPos = yieldAdapter.position(account);
        assertEq(adapterPos.principal, 100);
        assertEq(adapterPos.pendingYield, 0);

        vm.prank(owner);
        yieldProtocol.creditYield(account, 40);

        _executeFromAccount(
            user,
            account,
            address(yieldAdapter),
            abi.encodeWithSelector(MockYieldAdapter.claim.selector, account, bytes(""))
        );

        pos = yieldProtocol.position(account);
        assertEq(pos.pendingYield, 0);
        assertEq(yieldAdapter.currentValue(account), 100);

        _executeFromAccount(
            user,
            account,
            address(yieldAdapter),
            abi.encodeWithSelector(MockYieldAdapter.withdraw.selector, account, 60, bytes(""))
        );

        pos = yieldProtocol.position(account);
        assertEq(pos.principal, 40);
        assertEq(yieldAdapter.currentValue(account), 40);
    }

    function testMockYieldAdapterInvalidDataLengthReverts() public {
        (, address account) = _mintDefaultCrate(user, 7, bytes(""));

        vm.expectRevert(IDeFiAdapter.AdapterInvalidData.selector);
        _executeFromAccount(
            user,
            account,
            address(yieldAdapter),
            abi.encodeWithSelector(MockYieldAdapter.deposit.selector, account, 10, abi.encodePacked(uint48(1)))
        );
    }

    function testMockYieldAdapterAuthorization() public {
        (, address account) = _mintDefaultCrate(user, 8, bytes(""));

        vm.expectRevert(
            abi.encodeWithSelector(IDeFiAdapter.AdapterUnauthorized.selector, other, account)
        );
        vm.prank(other);
        yieldAdapter.deposit(account, 10, bytes(""));
    }

    function testMockYieldAdapterZeroAmountReverts() public {
        (, address account) = _mintDefaultCrate(user, 9, bytes(""));

        vm.expectRevert(IDeFiAdapter.AdapterZeroAmount.selector);
        _executeFromAccount(
            user,
            account,
            address(yieldAdapter),
            abi.encodeWithSelector(MockYieldAdapter.deposit.selector, account, 0, bytes(""))
        );
    }

    function testMockYieldProtocolGuards() public {
        MockYieldProtocol freshProtocol = new MockYieldProtocol(owner);
        vm.expectRevert(MockYieldProtocol.AdapterNotInitialized.selector);
        freshProtocol.depositFor(address(0x1234), 1, address(0x1234));

        vm.startPrank(owner);
        freshProtocol.setAdapter(address(yieldAdapter));
        vm.expectRevert(abi.encodeWithSelector(MockYieldProtocol.InvalidAdapter.selector, address(0)));
        freshProtocol.setAdapter(address(0));

        vm.expectRevert(abi.encodeWithSelector(MockYieldProtocol.InvalidAmount.selector, uint256(0)));
        freshProtocol.creditYield(address(0x1234), 0);

        vm.stopPrank();
    }

    function testMockYieldProtocolInsufficientPrincipalReverts() public {
        (, address account) = _mintDefaultCrate(user, 10, bytes(""));

        _executeFromAccount(
            user,
            account,
            address(yieldAdapter),
            abi.encodeWithSelector(MockYieldAdapter.deposit.selector, account, 25, bytes(""))
        );

        vm.expectRevert(abi.encodeWithSelector(MockYieldProtocol.InsufficientPrincipal.selector, uint256(30), uint256(25)));
        _executeFromAccount(
            user,
            account,
            address(yieldAdapter),
            abi.encodeWithSelector(MockYieldAdapter.withdraw.selector, account, 30, bytes(""))
        );
    }

    function testAccrualIncreasesIndex() public {
        (, address account) = _mintDefaultCrate(user, 11, bytes(""));

        _executeFromAccount(
            user,
            account,
            address(yieldAdapter),
            abi.encodeWithSelector(MockYieldAdapter.deposit.selector, account, 100e18, bytes(""))
        );

        vm.prank(owner);
        yieldProtocol.setRewardRate(1e18);

        (uint256 beforeIndex,,) = yieldProtocol.rewardState();
        vm.warp(block.timestamp + 10);

        vm.prank(owner);
        yieldProtocol.accrue();

        (uint256 afterIndex,,) = yieldProtocol.rewardState();
        assertGt(afterIndex, beforeIndex);
    }
}

