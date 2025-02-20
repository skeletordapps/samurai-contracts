// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/console.sol";
import {SamLock} from "src/SamLock.sol";
import {DeployLock} from "script/DeployLock.s.sol";
import {ILock, IPastLock} from "src/interfaces/ILock.sol";
import {IPoints} from "src/interfaces/IPoints.sol";
import {UD60x18, ud} from "@prb/math/src/UD60x18.sol";

contract SamLockTest is Test {
    uint256 fork;
    string public RPC_URL;

    DeployLock deployer;
    SamLock lock;
    IPastLock iPastLock;
    IPoints iPoints;
    address pastLock;
    address token;
    address points;

    address owner;
    address bob;
    address mary;
    address realPastLockAddr;

    uint256 minAmount;

    uint256 threeMonths;
    uint256 sixMonths;
    uint256 nineMonths;
    uint256 twelveMonths;

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployLock();

        (lock, pastLock, token, points) = deployer.runForTests();

        iPastLock = IPastLock(pastLock);
        iPoints = IPoints(points);

        owner = lock.owner();

        vm.startPrank(owner);
        iPoints.grantRole(IPoints.Roles.MINTER, address(lock));
        vm.stopPrank();

        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");

        realPastLockAddr = address(0xE4FeDe2f45E7257d9c269a752c89f6bB1Aa1E5c8);
        vm.label(realPastLockAddr, "realPastLockAddr");

        minAmount = lock.minToLock();

        threeMonths = lock.THREE_MONTHS();
        sixMonths = lock.SIX_MONTHS();
        nineMonths = lock.NINE_MONTHS();
        twelveMonths = lock.TWELVE_MONTHS();
    }

    // CONSTRUCTOR

    function testConstructor() public view {
        assertEq(lock.owner(), owner);
        assertEq(address(lock.sam()), token);

        assertEq(lock.multipliers(threeMonths), 1e18);
        assertEq(lock.multipliers(sixMonths), 3e18);
        assertEq(lock.multipliers(nineMonths), 5e18);
        assertEq(lock.multipliers(twelveMonths), 7e18);

        assertEq(lock.minToLock(), 30_000 ether);

        assertEq(lock.totalLocked(), 0);
        assertEq(lock.totalWithdrawn(), 0);
        assertEq(lock.totalClaimed(), 0);
    }

    function testRevertLockWhenUnderMinAmount() external {
        uint256 period = lock.SIX_MONTHS();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILock.ILock__Error.selector, "Insufficient amount"));
        lock.lock(minAmount - 10 ether, period);
        vm.stopPrank();
    }

    function testRevertLockWithInvalidPeriod() external {
        uint256 amount = 30_0000 ether;
        uint256 period = 30 days * 24; // => invalid period
        deal(token, bob, amount);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILock.ILock__Error.selector, "Invalid period"));
        lock.lock(amount, period);
        vm.stopPrank();
    }

    modifier locked(address wallet, uint256 amount) {
        vm.startPrank(wallet);

        deal(token, wallet, amount);
        ERC20(token).approve(address(lock), amount);

        vm.expectEmit(true, true, true, true);
        emit ILock.Locked(wallet, amount);
        lock.lock(amount, lock.THREE_MONTHS());
        vm.stopPrank();
        _;
    }

    function testCanCountLocksOfAWallet() external {
        vm.startPrank(bob);

        deal(token, bob, 30_000 ether);
        ERC20(token).approve(address(lock), 30_000 ether);

        lock.lock(30_000 ether, lock.THREE_MONTHS());
        vm.stopPrank();

        vm.warp(block.timestamp + 3 days);

        vm.startPrank(bob);

        deal(token, bob, 60_000 ether);
        ERC20(token).approve(address(lock), 60_000 ether);

        lock.lock(60_000 ether, lock.SIX_MONTHS());
        vm.stopPrank();

        assertEq(lock.locksOf(bob).length, 2);
    }

    function testRevertWithdrawWithZeroAmount() external {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILock.ILock__Error.selector, "Insufficient amount"));
        lock.withdraw(0, 0);
        vm.stopPrank();
    }

    function testRevertClaimPointsWithNoPoints() external locked(bob, 30_000 ether) {
        vm.startPrank(mary);
        vm.expectRevert(abi.encodeWithSelector(ILock.ILock__Error.selector, "Insufficient points to claim"));
        lock.claimPoints();
        vm.stopPrank();
    }

    function testCanClaimPoints() external locked(bob, 30_000 ether) {
        vm.warp(block.timestamp + 90 days);
        uint256 expectedPoints = lock.previewClaimablePoints(bob, 0);

        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit ILock.PointsClaimed(bob, expectedPoints);
        lock.claimPoints();
        vm.stopPrank();

        ILock.LockInfo[] memory locks = lock.locksOf(bob);
        assertEq(locks[0].claimedPoints, expectedPoints);
        assertEq(lock.totalClaimed(), expectedPoints);
    }

    modifier claimedPoints() {
        vm.warp(block.timestamp + 90 days);
        vm.startPrank(bob);
        lock.claimPoints();
        vm.stopPrank();
        _;
    }

    function testCannotClaimBeforeDelay() external locked(bob, 30_000 ether) claimedPoints {
        vm.startPrank(bob);
        vm.warp(block.timestamp + lock.CLAIM_DELAY_PERIOD() - 1 minutes);
        vm.expectRevert(abi.encodeWithSelector(ILock.ILock__Error.selector, "Claiming too soon"));
        lock.claimPoints();
        vm.stopPrank();
    }

    function testRevertWithdrawWithGreaterAmount() external locked(bob, 30_000 ether) {
        ILock.LockInfo[] memory lockings = lock.locksOf(bob); // Using the getter function

        vm.warp(lockings[0].unlockTime);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILock.ILock__Error.selector, "Insufficient amount"));
        lock.withdraw(lockings[0].lockedAmount * 2, 0);
        vm.stopPrank();
    }

    function testRevertWithdrawWhenBeforeUnlockDate() external locked(mary, 210_000 ether) {
        ILock.LockInfo[] memory lockings = lock.locksOf(mary); // Using the getter function

        vm.warp(lockings[0].unlockTime - 1 days);

        vm.startPrank(mary);
        vm.expectRevert(abi.encodeWithSelector(ILock.ILock__Error.selector, "Cannot unlock before period"));
        lock.withdraw(lockings[0].lockedAmount, 0);
        vm.stopPrank();
    }

    function testCanWithdraw() external locked(bob, 100_000 ether) {
        ILock.LockInfo[] memory lockings = lock.locksOf(bob);

        uint256 lockedAmount = lockings[0].lockedAmount;
        uint256 unlockTime = lockings[0].unlockTime;
        uint256 lockPeriod = lockings[0].lockPeriod;

        // uint256 initialPoints = lock.previewClaimablePoints(bob, lockIndex);

        // assertEq(initialPoints, 0);

        vm.warp(unlockTime);
        vm.startPrank(bob);

        vm.expectEmit(true, true, true, true);
        emit ILock.Withdrawn(bob, lockedAmount, 0);
        lock.withdraw(lockedAmount, 0);

        vm.stopPrank();

        ILock.LockInfo[] memory latestLocks = lock.locksOf(bob);
        assertEq(latestLocks[0].withdrawnAmount, latestLocks[0].lockedAmount);

        uint256 currentPoints = lock.previewClaimablePoints(bob, 0);
        assertEq(currentPoints, ud(lockedAmount).mul(ud(lock.multipliers(lockPeriod))).intoUint256());
    }

    function testFuzzLockProcessWith3Months(uint256 amount) external {
        vm.assume(amount >= minAmount && amount < 300_000 ether);

        // Lock
        vm.startPrank(bob);
        deal(token, bob, amount);
        ERC20(token).approve(address(lock), amount);
        lock.lock(amount, threeMonths);
        vm.stopPrank();

        ILock.LockInfo[] memory lockings = lock.locksOf(bob);
        uint256 lockedAmount = lockings[0].lockedAmount;
        uint256 unlockTime = lockings[0].unlockTime;
        uint256 lockPeriod = lockings[0].lockPeriod;

        assertEq(unlockTime, block.timestamp + threeMonths);
        assertEq(lockedAmount, amount);

        // Withdraw
        vm.warp(unlockTime);
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit ILock.Withdrawn(bob, amount, 0);
        lock.withdraw(amount, 0);
        vm.stopPrank();

        ILock.LockInfo[] memory latestLocks = lock.locksOf(bob);
        uint256 currentPoints = lock.previewClaimablePoints(bob, 0);
        assertEq(latestLocks[0].withdrawnAmount, latestLocks[0].lockedAmount);
        assertEq(currentPoints, ud(lockedAmount).mul(ud(lock.multipliers(lockPeriod))).intoUint256());
    }

    function testFuzzLockProcessWith6Months(uint256 amount) external {
        vm.assume(amount >= minAmount && amount < 300_000 ether);

        // Lock
        vm.startPrank(bob);
        deal(token, bob, amount);
        ERC20(token).approve(address(lock), amount);
        lock.lock(amount, sixMonths);
        vm.stopPrank();

        ILock.LockInfo[] memory lockings = lock.locksOf(bob);
        uint256 lockedAmount = lockings[0].lockedAmount;
        uint256 unlockTime = lockings[0].unlockTime;
        uint256 lockPeriod = lockings[0].lockPeriod;

        assertEq(unlockTime, block.timestamp + sixMonths);
        assertEq(lockedAmount, amount);

        // Withdraw
        vm.warp(unlockTime);
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit ILock.Withdrawn(bob, amount, 0);
        lock.withdraw(amount, 0);
        vm.stopPrank();

        ILock.LockInfo[] memory latestLocks = lock.locksOf(bob);
        uint256 currentPoints = lock.previewClaimablePoints(bob, 0);
        assertEq(latestLocks[0].withdrawnAmount, latestLocks[0].lockedAmount);
        assertEq(currentPoints, ud(lockedAmount).mul(ud(lock.multipliers(lockPeriod))).intoUint256());
    }

    function testFuzzLockProcessWith9Months(uint256 amount) external {
        vm.assume(amount >= minAmount && amount < 300_000 ether);

        // Lock
        vm.startPrank(bob);
        deal(token, bob, amount);
        ERC20(token).approve(address(lock), amount);
        lock.lock(amount, nineMonths);
        vm.stopPrank();

        ILock.LockInfo[] memory lockings = lock.locksOf(bob);
        uint256 lockedAmount = lockings[0].lockedAmount;
        uint256 unlockTime = lockings[0].unlockTime;
        uint256 lockPeriod = lockings[0].lockPeriod;

        assertEq(unlockTime, block.timestamp + nineMonths);
        assertEq(lockedAmount, amount);

        // Withdraw
        vm.warp(unlockTime);
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit ILock.Withdrawn(bob, amount, 0);
        lock.withdraw(amount, 0);
        vm.stopPrank();

        ILock.LockInfo[] memory latestLocks = lock.locksOf(bob);
        uint256 currentPoints = lock.previewClaimablePoints(bob, 0);
        assertEq(latestLocks[0].withdrawnAmount, latestLocks[0].lockedAmount);
        assertEq(currentPoints, ud(lockedAmount).mul(ud(lock.multipliers(lockPeriod))).intoUint256());
    }

    function testFuzzLockProcessWith12Months(uint256 amount) external {
        vm.assume(amount >= minAmount && amount < 300_000 ether);

        // Lock
        vm.startPrank(bob);
        deal(token, bob, amount);
        ERC20(token).approve(address(lock), amount);
        lock.lock(amount, twelveMonths);
        vm.stopPrank();

        ILock.LockInfo[] memory lockings = lock.locksOf(bob);
        uint256 lockedAmount = lockings[0].lockedAmount;
        uint256 unlockTime = lockings[0].unlockTime;
        uint256 lockPeriod = lockings[0].lockPeriod;

        assertEq(unlockTime, block.timestamp + twelveMonths);
        assertEq(lockedAmount, amount);

        // Withdraw
        vm.warp(unlockTime);
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit ILock.Withdrawn(bob, amount, 0);
        lock.withdraw(amount, 0);
        vm.stopPrank();

        ILock.LockInfo[] memory latestLocks = lock.locksOf(bob);
        uint256 currentPoints = lock.previewClaimablePoints(bob, 0);
        assertEq(latestLocks[0].withdrawnAmount, latestLocks[0].lockedAmount);
        assertEq(currentPoints, ud(lockedAmount).mul(ud(lock.multipliers(lockPeriod))).intoUint256());
    }

    function testRevertUpdateMultipliersWithZeroValues() external {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(ILock.ILock__Error.selector, "Invalid multiplier"));
        lock.updateMultipliers(0, 2e18, 3e18, 4e18);

        vm.expectRevert(abi.encodeWithSelector(ILock.ILock__Error.selector, "Invalid multiplier"));
        lock.updateMultipliers(1e18, 0, 3e18, 4e18);

        vm.expectRevert(abi.encodeWithSelector(ILock.ILock__Error.selector, "Invalid multiplier"));
        lock.updateMultipliers(1e18, 2e18, 0, 4e18);

        vm.expectRevert(abi.encodeWithSelector(ILock.ILock__Error.selector, "Invalid multiplier"));
        lock.updateMultipliers(1e18, 2e18, 3e18, 0);
        vm.stopPrank();
    }

    function testCanUpdateMultipliers() external {
        uint256 expectedMultiplier1 = 10e18;
        uint256 expectedMultiplier2 = 20e18;
        uint256 expectedMultiplier3 = 30e18;
        uint256 expectedMultiplier4 = 40e18;

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit ILock.MultipliersUpdated(
            expectedMultiplier1, expectedMultiplier2, expectedMultiplier3, expectedMultiplier4
        );
        lock.updateMultipliers(expectedMultiplier1, expectedMultiplier2, expectedMultiplier3, expectedMultiplier4);
        vm.stopPrank();

        assertEq(lock.multipliers(threeMonths), expectedMultiplier1);
        assertEq(lock.multipliers(sixMonths), expectedMultiplier2);
        assertEq(lock.multipliers(nineMonths), expectedMultiplier3);
        assertEq(lock.multipliers(twelveMonths), expectedMultiplier4);
    }

    modifier multipliersUpdated() {
        uint256 expectedMultiplier1 = 10e18;
        uint256 expectedMultiplier2 = 20e18;
        uint256 expectedMultiplier3 = 30e18;
        uint256 expectedMultiplier4 = 40e18;

        vm.startPrank(owner);
        lock.updateMultipliers(expectedMultiplier1, expectedMultiplier2, expectedMultiplier3, expectedMultiplier4);
        vm.stopPrank();
        _;
    }

    function testWalletKeepPointsAfterUpdateMultipliers() external locked(bob, 30_000 ether) multipliersUpdated {
        uint256 newMinAmount = lock.minToLock();
        ILock.LockInfo[] memory latestLocks = lock.locksOf(bob);

        vm.warp(latestLocks[0].unlockTime);
        uint256 lockPoints = lock.previewClaimablePoints(bob, 0);

        vm.startPrank(bob);

        deal(token, bob, newMinAmount);
        ERC20(token).approve(address(lock), newMinAmount);

        lock.lock(newMinAmount, lock.THREE_MONTHS());
        vm.stopPrank();

        uint256 multiplier = lock.multipliers(latestLocks[0].lockPeriod);

        assertEq(lockPoints, ud(latestLocks[0].lockedAmount).mul(ud(multiplier)).intoUint256());
    }

    function testRevertPointsByLockWithWrongIndex() external locked(bob, 30_000 ether) {
        uint256 claimablePoints = lock.previewClaimablePoints(bob, 1);
        assertEq(claimablePoints, 0);
    }

    function testRevertGetLockInfosWhithoutAny() external {
        vm.startPrank(bob);
        ILock.LockInfo[] memory lockInfos = lock.locksOf(bob);
        vm.stopPrank();

        assertEq(lockInfos.length, 0);
    }

    function testShouldReturnEmptyLockInfosWhenHasNoLock() external {
        vm.startPrank(bob);
        ILock.LockInfo[] memory lockInfos = lock.locksOf(bob);
        vm.stopPrank();

        assertEq(lockInfos.length, 0);
    }

    function testRevertMigrationWhenHasNoPoints() external {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILock.ILock__Error.selector, "Insufficient points to migrate"));
        lock.migrateVirtualPointsToTokens();
        vm.stopPrank();

        uint256 initialPoints = iPoints.balanceOf(realPastLockAddr);

        vm.startPrank(realPastLockAddr);
        lock.migrateVirtualPointsToTokens();
        vm.stopPrank();

        uint256 migratedPoints = iPoints.balanceOf(realPastLockAddr);
        assertTrue(migratedPoints > initialPoints);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILock.ILock__Error.selector, "Insufficient points to migrate"));
        lock.migrateVirtualPointsToTokens();
        vm.stopPrank();

        vm.warp(block.timestamp + 90 days);
        vm.startPrank(realPastLockAddr);
        lock.migrateVirtualPointsToTokens();
        vm.stopPrank();

        uint256 finalPoints = iPoints.balanceOf(realPastLockAddr);
        assertTrue(finalPoints > migratedPoints);
    }

    function testCanMigratePoints() external {
        vm.startPrank(realPastLockAddr);
        IPastLock.LockInfo[] memory pastLocks = iPastLock.getLockInfos(realPastLockAddr);

        uint256 virtualPoints;

        for (uint256 i = 0; i < pastLocks.length; i++) {
            uint256 lockPoints = iPastLock.pointsByLock(realPastLockAddr, i);
            virtualPoints += lockPoints;
        }

        uint256 initialPoints = iPoints.balanceOf(realPastLockAddr);

        vm.expectEmit(true, true, true, true);
        emit ILock.PointsMigrated(realPastLockAddr, virtualPoints);
        lock.migrateVirtualPointsToTokens();
        vm.stopPrank();

        uint256 migratedPoints = iPoints.balanceOf(realPastLockAddr);

        assertEq(migratedPoints, virtualPoints);
        assertEq(migratedPoints, initialPoints + virtualPoints);
    }

    modifier migrated() {
        vm.startPrank(realPastLockAddr);
        lock.migrateVirtualPointsToTokens();
        vm.stopPrank();
        _;
    }
}
