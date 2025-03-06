// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {SamuraiTiers} from "../src/SamuraiTiers.sol";
import {DeploySamuraiTiers} from "../script/DeploySamuraiTiers.s.sol";
import {
    ISamuraiTiers,
    MockSamNftsLock,
    MockSamLocks,
    MockSamLocksV2,
    MockSamLocksV3,
    MockSamGaugeLP
} from "../src/interfaces/ISamuraiTiers.sol";
import {ISamLock} from "../src/interfaces/ISamLock.sol";
import {ILock} from "../src/interfaces/ILock.sol";

contract SamuraiTiersTest is Test {
    uint256 fork;
    string public RPC_URL;

    DeploySamuraiTiers deployer;
    SamuraiTiers samuraiTiers;

    address owner;
    address bob;
    address mary;

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeploySamuraiTiers();
        samuraiTiers = deployer.runForTests();

        owner = samuraiTiers.owner();
        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");
    }

    // CONSTRUCTOR

    function testConstructor() public view {
        assertEq(samuraiTiers.owner(), owner);
        assertEq(samuraiTiers.counter(), 0);
    }

    function testCanAddNewTier() external {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit ISamuraiTiers.Added(1);
        samuraiTiers.addTier("Shogun", 1, 200_000, 399_000, 900, 1800);
        vm.stopPrank();

        uint256 index = samuraiTiers.counter();
        (
            string memory name,
            uint256 numberOfSumNfts,
            uint256 minStaking,
            uint256 maxStaking,
            uint256 minLPStaking,
            uint256 maxLPStaking
        ) = samuraiTiers.tiers(index);

        assertEq(index, 1);
        assertEq(name, "Shogun");
        assertEq(numberOfSumNfts, 1);
        assertEq(minStaking, 200_000);
        assertEq(maxStaking, 399_000);
        assertEq(minLPStaking, 900);
        assertEq(maxLPStaking, 1800);
    }

    modifier tierAdded(
        string memory name,
        uint256 numberOfSumNfts,
        uint256 minStaking,
        uint256 maxStaking,
        uint256 minLPStaking,
        uint256 maxLPStaking
    ) {
        vm.startPrank(owner);
        samuraiTiers.addTier(name, numberOfSumNfts, minStaking, maxStaking, minLPStaking, maxLPStaking);
        vm.stopPrank();
        _;
    }

    function testCanRemoveTier() external tierAdded("Shogun", 1, 200_000, 399_000, 900, 1800) {
        uint256 index = samuraiTiers.counter();

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit ISamuraiTiers.Removed(ISamuraiTiers.Tier("Shogun", 1, 200_000, 399_000, 900, 1800));
        samuraiTiers.removeTier(index);
        vm.stopPrank();

        assertEq(samuraiTiers.counter(), 0);
    }

    function testCanUpdateTier() external tierAdded("Shogun", 1, 200_000, 399_000, 900, 1800) {
        uint256 index = samuraiTiers.counter();

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit ISamuraiTiers.Updated(1);
        samuraiTiers.updateTier(index, "Hatamoto", 5, 100_000, 199_000, 450, 900);
        vm.stopPrank();

        (
            string memory name,
            uint256 numberOfSamNfts,
            uint256 minStaking,
            uint256 maxStaking,
            uint256 minLPStaking,
            uint256 maxLPStaking
        ) = samuraiTiers.tiers(index);

        assertEq(index, 1);
        assertEq(name, "Hatamoto");
        assertEq(numberOfSamNfts, 5);
        assertEq(minStaking, 100_000);
        assertEq(maxStaking, 199_000);
        assertEq(minLPStaking, 450);
        assertEq(maxLPStaking, 900);
    }

    function testCanUpdateSources() external {
        address nftLock = samuraiTiers.nftLock();
        address lock = samuraiTiers.lock();
        address lockV2 = samuraiTiers.lockV2();
        address lockV3 = samuraiTiers.lockV3();
        address lpGauge = samuraiTiers.lpGauge();

        vm.startPrank(owner);

        vm.expectRevert("Invalid address");
        samuraiTiers.setSources(address(0), lock, lockV2, lockV3, lpGauge);

        vm.expectRevert("Invalid address");
        samuraiTiers.setSources(nftLock, address(0), lockV2, lockV3, lpGauge);

        vm.expectRevert("Invalid address");
        samuraiTiers.setSources(nftLock, lock, lockV2, lockV3, address(0));

        vm.expectEmit(true, true, true, true);
        emit ISamuraiTiers.SourcesUpdated(nftLock, lock, lockV2, lockV3, lpGauge);
        samuraiTiers.setSources(nftLock, lock, lockV2, lockV3, lpGauge);

        vm.stopPrank();
    }

    modifier setTiers() {
        ISamuraiTiers.Tier memory Ronin = ISamuraiTiers.Tier("Ronin", 0, 15_000 ether, 29_999 ether, 20 ether, 44 ether);
        ISamuraiTiers.Tier memory Gokenin =
            ISamuraiTiers.Tier("Gokenin", 0, 30_000 ether, 59_999 ether, 45 ether, 90 ether);
        ISamuraiTiers.Tier memory Goshi =
            ISamuraiTiers.Tier("Goshi", 0, 60_000 ether, 99_999 ether, 91 ether, 150 ether);
        ISamuraiTiers.Tier memory Hatamoto =
            ISamuraiTiers.Tier("Hatamoto", 0, 100_000 ether, 199_999 ether, 151 ether, 300 ether);
        ISamuraiTiers.Tier memory Shogun =
            ISamuraiTiers.Tier("Shogun", 1, 200_000 ether, 999_999_999 ether, 301 ether, 999_999_999 ether);

        vm.startPrank(owner);
        samuraiTiers.addTier(
            Ronin.name, Ronin.numOfSamNfts, Ronin.minLocking, Ronin.maxLocking, Ronin.minLPStaking, Ronin.maxLPStaking
        );
        samuraiTiers.addTier(
            Gokenin.name,
            Gokenin.numOfSamNfts,
            Gokenin.minLocking,
            Gokenin.maxLocking,
            Gokenin.minLPStaking,
            Gokenin.maxLPStaking
        );

        samuraiTiers.addTier(
            Goshi.name, Goshi.numOfSamNfts, Goshi.minLocking, Goshi.maxLocking, Goshi.minLPStaking, Goshi.maxLPStaking
        );

        samuraiTiers.addTier(
            Hatamoto.name,
            Hatamoto.numOfSamNfts,
            Hatamoto.minLocking,
            Hatamoto.maxLocking,
            Hatamoto.minLPStaking,
            Hatamoto.maxLPStaking
        );

        samuraiTiers.addTier(
            Shogun.name,
            Shogun.numOfSamNfts,
            Shogun.minLocking,
            Shogun.maxLocking,
            Shogun.minLPStaking,
            Shogun.maxLPStaking
        );
        vm.stopPrank();
        _;
    }

    modifier mockExternalInfos(
        address wallet,
        uint256 nftsLocked,
        uint256 lockedAmount,
        uint256 withdrawnAmount,
        uint256 lpAmount
    ) {
        MockSamNftsLock nftLocksMock = MockSamNftsLock(address(samuraiTiers.nftLock()));
        MockSamLocks locksMock = MockSamLocks(address(samuraiTiers.lock()));
        MockSamLocks locksMockV2 = MockSamLocks(address(samuraiTiers.lockV2()));
        MockSamLocks locksMockV3 = MockSamLocks(address(samuraiTiers.lockV3()));
        MockSamGaugeLP lpGaugeMock = MockSamGaugeLP(address(samuraiTiers.lpGauge()));

        // Mock nft balance for the test case
        vm.mockCall(
            address(samuraiTiers.nftLock()),
            abi.encodeWithSelector(nftLocksMock.locksCounter.selector, wallet),
            abi.encode(nftsLocked)
        );

        // Mock lock information for the test case
        ISamLock.LockInfo[] memory lockInfos = new ISamLock.LockInfo[](1); // Define lock info structure

        lockInfos[0] =
            ISamLock.LockInfo(0, lockedAmount, withdrawnAmount, block.timestamp, block.timestamp, 0 days, 7000000000); // Set desired locked/withdrawn amounts
        vm.mockCall(
            address(samuraiTiers.lock()),
            abi.encodeWithSelector(locksMock.getLockInfos.selector, wallet),
            abi.encode(lockInfos)
        );

        // Mock lock v2 information for the test case
        ILock.LockInfo[] memory lockInfosV2 = new ILock.LockInfo[](1); // Define lock info structure

        lockInfosV2[0] = ILock.LockInfo(0, lockedAmount, withdrawnAmount, block.timestamp, block.timestamp, 0 days); // Set desired locked/withdrawn amounts
        vm.mockCall(
            address(samuraiTiers.lockV2()),
            abi.encodeWithSelector(locksMockV2.getLockInfos.selector, wallet),
            abi.encode(lockInfosV2)
        );

        // Mock lock v3 information for the test case
        ILock.LockInfo[] memory lockInfosV3 = new ILock.LockInfo[](1); // Define lock info structure

        lockInfosV3[0] = ILock.LockInfo(0, lockedAmount, withdrawnAmount, block.timestamp, block.timestamp, 0 days); // Set desired locked/withdrawn amounts
        vm.mockCall(
            address(samuraiTiers.lockV3()),
            abi.encodeWithSelector(locksMockV3.getLockInfos.selector, wallet),
            abi.encode(lockInfosV3)
        );

        // Mock gauge WETH/SAM balance
        vm.mockCall(
            address(samuraiTiers.lpGauge()),
            abi.encodeWithSelector(lpGaugeMock.balanceOf.selector, wallet),
            abi.encode(lpAmount)
        );

        _;
    }

    function testCanGetTierForRonin() public setTiers mockExternalInfos(bob, 0, 15_000 ether, 0, 20 ether) {
        assertEq(samuraiTiers.counter(), 5);

        ISamuraiTiers.Tier memory userTier = samuraiTiers.getTier(bob);
        assertEq(userTier.name, "Ronin");
    }

    function testCanGetTierForGokenin() public setTiers mockExternalInfos(bob, 0, 30_000 ether, 0, 55 ether) {
        assertEq(samuraiTiers.counter(), 5);

        ISamuraiTiers.Tier memory userTier = samuraiTiers.getTier(bob);
        assertEq(userTier.name, "Gokenin");
    }

    function testCanGetTierForGoshi() public setTiers mockExternalInfos(bob, 0, 60_000 ether, 0, 91 ether) {
        assertEq(samuraiTiers.counter(), 5);

        ISamuraiTiers.Tier memory userTier = samuraiTiers.getTier(bob);
        assertEq(userTier.name, "Goshi");
    }

    function testCanGetTierForHatamoto() public setTiers mockExternalInfos(bob, 0, 100_000 ether, 0, 151 ether) {
        assertEq(samuraiTiers.counter(), 5);

        ISamuraiTiers.Tier memory userTier = samuraiTiers.getTier(bob);
        assertEq(userTier.name, "Hatamoto");
    }

    function testCanGetTierForShogun() public setTiers mockExternalInfos(bob, 1, 200_000 ether, 0, 301 ether) {
        assertEq(samuraiTiers.counter(), 5);

        ISamuraiTiers.Tier memory userTier = samuraiTiers.getTier(bob);
        assertEq(userTier.name, "Shogun");
    }

    function testCanGetTierForEmptyTier() public setTiers mockExternalInfos(bob, 0, 0, 0, 0) {
        assertEq(samuraiTiers.counter(), 5);

        ISamuraiTiers.Tier memory userTier = samuraiTiers.getTier(bob);
        assertEq(userTier.name, "");
    }

    function testCanGetTierFromRealUsers() public setTiers {
        address user1 = 0xB1686bF52BF8A58d88fDCf7e9624A23C732bA4bb;

        vm.startPrank(user1);
        ISamuraiTiers.Tier memory user1Tier = samuraiTiers.getTier(user1);
        vm.stopPrank();

        assertEq(user1Tier.name, "Shogun");
    }
}
