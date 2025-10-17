// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import "../src/OpenCrateNFT.sol";
import "../src/OpenCrateFactory.sol";
import "../src/strategies/OpenCrateStrategyRegistry.sol";
import "../src/adapters/MockYieldAdapter.sol";
import "../src/mock/MockYieldProtocol.sol";
import "../src/interfaces/IDeFiAdapter.sol";
import "../src/ERC6551Registry.sol";
import "../src/ERC6551Account.sol";

contract OpenCrateTest is Test {
    address internal owner = makeAddr("owner");
    address internal user = makeAddr("user");
    address internal other = makeAddr("other");

    OpenCrateNFT internal crateNFT;
    OpenCrateFactory internal factory;
    OpenCrateStrategyRegistry internal strategyRegistry;
    MockYieldProtocol internal yieldProtocol;
    MockYieldAdapter internal yieldAdapter;
    ERC6551Registry internal accountRegistry;
    ERC6551Account internal accountImplementation;

    uint8 internal constant RISK_HIGH = 0;
    uint256 internal constant DEFAULT_PRICE_USD = 750; // $7.50 with 2 decimals
    uint16 internal constant DEFAULT_BOOST_BPS = 10_000;
    uint64 internal constant DEFAULT_LOCK_DURATION = 0;

    function setUp() public {
        vm.startPrank(owner);

        accountRegistry = new ERC6551Registry();
        accountImplementation = new ERC6551Account();

        strategyRegistry = new OpenCrateStrategyRegistry(owner);

        yieldProtocol = new MockYieldProtocol(owner);
        yieldAdapter = new MockYieldAdapter(yieldProtocol, owner);
        yieldProtocol.setAdapter(address(yieldAdapter));

        crateNFT = new OpenCrateNFT("OpenCrate", "CRATE", "https://metadata/", owner, address(0));

        factory = new OpenCrateFactory(
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

    function _mintDefaultCrate(address recipient, uint256 salt, bytes memory adapterData)
        internal
        returns (uint256 tokenId, address account)
    {
        return _mintCrateWithParams(
            recipient,
            salt,
            DEFAULT_PRICE_USD,
            DEFAULT_BOOST_BPS,
            DEFAULT_LOCK_DURATION,
            adapterData
        );
    }

    function _mintCrateWithParams(
        address recipient,
        uint256 salt,
        uint256 priceUsd,
        uint16 boostMultiplierBps,
        uint64 lockDuration,
        bytes memory adapterData
    ) internal returns (uint256 tokenId, address account) {
        OpenCrateFactory.MintParams memory params = OpenCrateFactory.MintParams({
            to: recipient,
            riskLevel: RISK_HIGH,
            strategyId: 1,
            salt: salt,
            priceUsd: priceUsd,
            boostMultiplierBps: boostMultiplierBps,
            lockDuration: lockDuration,
            accountInitData: bytes(""),
            adapterData: adapterData
        });

        vm.prank(recipient);
        (tokenId, account) = factory.mintCrate(params);
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
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                user
            )
        );
        vm.prank(user);
        strategyRegistry.registerStrategy(address(yieldAdapter), bytes(""), RISK_HIGH, true);
    }

    function testOpenCrateNFTFactoryMinting() public {
        (uint256 tokenId, address account) = _mintDefaultCrate(user, 777, abi.encode(user));
        assertEq(tokenId, 1);
        assertEq(crateNFT.ownerOf(tokenId), user);

        OpenCrateNFT.CrateInfo memory info = crateNFT.crateInfo(tokenId);
        assertEq(info.riskLevel, RISK_HIGH);
        assertEq(info.strategyId, 1);
        assertEq(info.account, account);
        assertGt(info.mintedAt, 0);
        assertEq(info.priceUsd, DEFAULT_PRICE_USD);
        assertEq(info.boostMultiplierBps, DEFAULT_BOOST_BPS);
        assertEq(info.lockedUntil, 0);

        assertEq(crateNFT.nextTokenId(), 2);
        assertEq(crateNFT.totalMinted(), 1);

        (address adapter, bytes memory adapterData) = factory.crateAdapter(tokenId);
        assertEq(adapter, address(yieldAdapter));
        assertEq(adapterData, abi.encode(user));

        OpenCrateFactory.CrateDeployment memory deployment = factory.crateDeployment(tokenId);
        assertEq(deployment.strategyId, 1);
        assertEq(deployment.riskLevel, RISK_HIGH);
        assertEq(deployment.salt, 777);
        assertEq(deployment.account, account);
        assertEq(deployment.priceUsd, DEFAULT_PRICE_USD);
        assertEq(deployment.boostMultiplierBps, DEFAULT_BOOST_BPS);
        assertEq(deployment.lockedUntil, 0);
    }

    function testOpenCrateNFTOnlyFactoryCanMint() public {
        vm.expectRevert(OpenCrateNFT.Unauthorized.selector);
        vm.prank(user);
        crateNFT.mintCrate(
            user,
            RISK_HIGH,
            1,
            address(0x1234),
            DEFAULT_PRICE_USD,
            DEFAULT_BOOST_BPS,
            DEFAULT_LOCK_DURATION
        );
    }

    function testFactoryPredictAccountMatchesDeployment() public {
        OpenCrateFactory.MintParams memory params = OpenCrateFactory.MintParams({
            to: user,
            riskLevel: RISK_HIGH,
            strategyId: 1,
            salt: 42,
            priceUsd: DEFAULT_PRICE_USD,
            boostMultiplierBps: DEFAULT_BOOST_BPS,
            lockDuration: DEFAULT_LOCK_DURATION,
            accountInitData: bytes(""),
            adapterData: bytes("")
        });

        address predicted = factory.predictAccountForNext(params.salt);
        (uint256 tokenId, address account) = factory.mintCrate(params);
        assertEq(tokenId, 1);
        assertEq(account, predicted);

        address predictedById = factory.predictAccount(tokenId, params.salt);
        assertEq(predictedById, account);
        assertEq(crateNFT.ownerOf(tokenId), user);
    }

    function testFactoryRejectsInactiveStrategy() public {
        vm.prank(owner);
        strategyRegistry.setStrategyStatus(1, false);

        OpenCrateFactory.MintParams memory params = OpenCrateFactory.MintParams({
            to: user,
            riskLevel: RISK_HIGH,
            strategyId: 1,
            salt: 1,
            priceUsd: DEFAULT_PRICE_USD,
            boostMultiplierBps: DEFAULT_BOOST_BPS,
            lockDuration: DEFAULT_LOCK_DURATION,
            accountInitData: bytes(""),
            adapterData: bytes("")
        });

        vm.expectRevert(abi.encodeWithSelector(OpenCrateFactory.StrategyInactive.selector, params.strategyId));
        vm.prank(user);
        factory.mintCrate(params);
    }

    function testFactoryRejectsRiskMismatch() public {
        OpenCrateFactory.MintParams memory params = OpenCrateFactory.MintParams({
            to: user,
            riskLevel: 1,
            strategyId: 1,
            salt: 1,
            priceUsd: DEFAULT_PRICE_USD,
            boostMultiplierBps: DEFAULT_BOOST_BPS,
            lockDuration: DEFAULT_LOCK_DURATION,
            accountInitData: bytes(""),
            adapterData: bytes("")
        });

        vm.expectRevert(abi.encodeWithSelector(OpenCrateFactory.StrategyRiskMismatch.selector, RISK_HIGH, params.riskLevel));
        vm.prank(user);
        factory.mintCrate(params);
    }

    function testMintCrateRejectsPriceBelowMin() public {
        uint256 belowMin = crateNFT.MIN_PRICE_USD() - 1;
        OpenCrateFactory.MintParams memory params = OpenCrateFactory.MintParams({
            to: user,
            riskLevel: RISK_HIGH,
            strategyId: 1,
            salt: 99,
            priceUsd: belowMin,
            boostMultiplierBps: DEFAULT_BOOST_BPS,
            lockDuration: DEFAULT_LOCK_DURATION,
            accountInitData: bytes(""),
            adapterData: bytes("")
        });

        vm.expectRevert(OpenCrateNFT.InvalidPrice.selector);
        vm.prank(user);
        factory.mintCrate(params);
    }

    function testMintCrateRejectsPriceAboveMax() public {
        uint256 aboveMax = crateNFT.MAX_PRICE_USD() + 1;
        OpenCrateFactory.MintParams memory params = OpenCrateFactory.MintParams({
            to: user,
            riskLevel: RISK_HIGH,
            strategyId: 1,
            salt: 98,
            priceUsd: aboveMax,
            boostMultiplierBps: DEFAULT_BOOST_BPS,
            lockDuration: DEFAULT_LOCK_DURATION,
            accountInitData: bytes(""),
            adapterData: bytes("")
        });

        vm.expectRevert(OpenCrateNFT.InvalidPrice.selector);
        vm.prank(user);
        factory.mintCrate(params);
    }

    function testMintCrateRejectsBoostOutsideRange() public {
        OpenCrateFactory.MintParams memory params = OpenCrateFactory.MintParams({
            to: user,
            riskLevel: RISK_HIGH,
            strategyId: 1,
            salt: 97,
            priceUsd: DEFAULT_PRICE_USD,
            boostMultiplierBps: DEFAULT_BOOST_BPS - 1,
            lockDuration: DEFAULT_LOCK_DURATION,
            accountInitData: bytes(""),
            adapterData: bytes("")
        });

        vm.expectRevert(OpenCrateNFT.InvalidBoost.selector);
        vm.prank(user);
        factory.mintCrate(params);
    }

    function testMintCrateRejectsLockDurationAboveMax() public {
        uint64 lockDuration = uint64(uint256(crateNFT.MAX_LOCK_DURATION()) + 1);
        OpenCrateFactory.MintParams memory params = OpenCrateFactory.MintParams({
            to: user,
            riskLevel: RISK_HIGH,
            strategyId: 1,
            salt: 96,
            priceUsd: DEFAULT_PRICE_USD,
            boostMultiplierBps: DEFAULT_BOOST_BPS,
            lockDuration: lockDuration,
            accountInitData: bytes(""),
            adapterData: bytes("")
        });

        vm.expectRevert(OpenCrateNFT.InvalidLockDuration.selector);
        vm.prank(user);
        factory.mintCrate(params);
    }

    function testUpdatePrice() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 12, bytes(""));
        uint256 newPrice = DEFAULT_PRICE_USD + 100;

        vm.prank(user);
        crateNFT.updatePrice(tokenId, newPrice);

        OpenCrateNFT.CrateInfo memory info = crateNFT.crateInfo(tokenId);
        assertEq(info.priceUsd, newPrice);
    }

    function testUpdatePriceRequiresAuthorization() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 13, bytes(""));

        vm.expectRevert(OpenCrateNFT.NotApprovedOrOwner.selector);
        vm.prank(other);
        crateNFT.updatePrice(tokenId, DEFAULT_PRICE_USD + 50);
    }

    function testUpdatePriceRejectsOutOfRange() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 14, bytes(""));
        uint256 belowMin = crateNFT.MIN_PRICE_USD() - 1;

        vm.expectRevert(OpenCrateNFT.InvalidPrice.selector);
        vm.prank(user);
        crateNFT.updatePrice(tokenId, belowMin);
    }

    function testSetBoostMultiplier() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 15, bytes(""));
        uint16 newBoost = DEFAULT_BOOST_BPS + 2_000;

        vm.prank(user);
        crateNFT.setBoostMultiplier(tokenId, newBoost);

        OpenCrateNFT.CrateInfo memory info = crateNFT.crateInfo(tokenId);
        assertEq(info.boostMultiplierBps, newBoost);
    }

    function testSetBoostRequiresAuthorization() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 16, bytes(""));

        vm.expectRevert(OpenCrateNFT.NotApprovedOrOwner.selector);
        vm.prank(other);
        crateNFT.setBoostMultiplier(tokenId, DEFAULT_BOOST_BPS + 100);
    }

    function testSetBoostRejectsOutOfRange() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 17, bytes(""));

        vm.expectRevert(OpenCrateNFT.InvalidBoost.selector);
        vm.prank(user);
        crateNFT.setBoostMultiplier(tokenId, DEFAULT_BOOST_BPS - 1);
    }

    function testExtendLock() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 18, bytes(""));
        uint64 duration = 30 days;

        vm.prank(user);
        crateNFT.extendLock(tokenId, duration);

        OpenCrateNFT.CrateInfo memory info = crateNFT.crateInfo(tokenId);
        assertEq(info.lockedUntil, uint64(block.timestamp) + duration);
    }

    function testExtendLockRejectsOutOfRange() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 19, bytes(""));
        uint64 duration = uint64(uint256(crateNFT.MAX_LOCK_DURATION()) + 1);

        vm.expectRevert(OpenCrateNFT.InvalidLockDuration.selector);
        vm.prank(user);
        crateNFT.extendLock(tokenId, duration);
    }

    function testMintCrateStoresCustomPriceBoostLock() public {
        uint256 priceUsd = 12_34; // $12.34
        uint16 boost = DEFAULT_BOOST_BPS + 5_000;
        uint64 lockDuration = 14 days;

        (uint256 tokenId, ) = _mintCrateWithParams(user, 95, priceUsd, boost, lockDuration, bytes(""));

        OpenCrateNFT.CrateInfo memory info = crateNFT.crateInfo(tokenId);
        assertEq(info.priceUsd, priceUsd);
        assertEq(info.boostMultiplierBps, boost);
        assertEq(info.lockedUntil, uint64(block.timestamp) + lockDuration);

        OpenCrateFactory.CrateDeployment memory deployment = factory.crateDeployment(tokenId);
        assertEq(deployment.priceUsd, priceUsd);
        assertEq(deployment.boostMultiplierBps, boost);
        assertEq(deployment.lockedUntil, info.lockedUntil);
    }

    function testLockPreventsTransferUntilExpiry() public {
        (uint256 tokenId,) = _mintDefaultCrate(user, 20, bytes(""));
        uint64 duration = 7 days;

        vm.prank(user);
        crateNFT.extendLock(tokenId, duration);

        OpenCrateNFT.CrateInfo memory info = crateNFT.crateInfo(tokenId);
        vm.expectRevert(abi.encodeWithSelector(OpenCrateNFT.TokenLocked.selector, info.lockedUntil));
        vm.prank(user);
        crateNFT.transferFrom(user, other, tokenId);

        vm.warp(info.lockedUntil + 1);
        vm.prank(user);
        crateNFT.transferFrom(user, other, tokenId);
        assertEq(crateNFT.ownerOf(tokenId), other);
    }

    function testERC6551AccountExecuteCallOnlyOwner() public {
        (, address account) = _mintDefaultCrate(user, 1, bytes(""));

        bytes memory callData = abi.encodeWithSelector(MockYieldAdapter.deposit.selector, account, 1, bytes(""));

        vm.expectRevert("Not Token Owner");
        vm.prank(other);
        ERC6551Account(payable(account)).executeCall(address(yieldAdapter), 0, callData);
    }

    function testMockYieldAdapterDepositWithdrawClaimFlow() public {
        (uint256 tokenId, address account) = _mintDefaultCrate(user, 5, bytes(""));
        assertEq(tokenId, 1);

        // Deposit
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

        // Credit yield and claim
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

        // Withdraw
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

    function testMockYieldAdapterCustomReceiverEncoding() public {
        (, address account) = _mintDefaultCrate(user, 6, bytes(""));
        address receiver = makeAddr("receiver");

        _executeFromAccount(
            user,
            account,
            address(yieldAdapter),
            abi.encodeWithSelector(MockYieldAdapter.deposit.selector, account, 50, abi.encode(receiver))
        );

        vm.prank(owner);
        yieldProtocol.creditYield(account, 20);

        vm.expectEmit(true, true, false, true);
        emit MockYieldProtocol.YieldClaimed(account, receiver, 20);

        _executeFromAccount(
            user,
            account,
            address(yieldAdapter),
            abi.encodeWithSelector(MockYieldAdapter.claim.selector, account, abi.encode(receiver))
        );
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
            abi.encodeWithSelector(
                IDeFiAdapter.AdapterUnauthorized.selector,
                other,
                account
            )
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
            abi.encodeWithSelector(MockYieldAdapter.deposit.selector, account, 100 ether, bytes(""))
        );

        vm.prank(owner);
        yieldProtocol.setRewardRate(1 ether);

        (uint256 beforeIndex,,) = yieldProtocol.rewardState();
        vm.warp(block.timestamp + 10);

        vm.prank(owner);
        yieldProtocol.accrue();

        (uint256 afterIndex,,) = yieldProtocol.rewardState();
        assertGt(afterIndex, beforeIndex);
    }
}
