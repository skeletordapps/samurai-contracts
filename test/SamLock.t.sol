// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/console.sol";
import {SamLock} from "../src/SamLock.sol";
import {DeployLock} from "../script/DeployLock.s.sol";
import {ISamLock} from "../src/interfaces/ISamLock.sol";
import {UD60x18, ud} from "@prb/math/src/UD60x18.sol";

contract SamLockTest is Test {
    uint256 fork;
    string public RPC_URL;

    DeployLock deployer;
    SamLock lock;
    address token;

    address owner;
    address bob;
    address mary;

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

        (lock, token) = deployer.run();

        owner = lock.owner();
        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");

        minAmount = lock.minToLock();

        threeMonths = lock.THREE_MONTHS();
        sixMonths = lock.SIX_MONTHS();
        nineMonths = lock.NINE_MONTHS();
        twelveMonths = lock.TWELVE_MONTHS();
    }

    // CONSTRUCTOR

    function testConstructor() public {
        assertEq(lock.owner(), owner);
        assertEq(address(lock.sam()), token);

        assertEq(lock.multipliers(threeMonths), 1e18);
        assertEq(lock.multipliers(sixMonths), 3e18);
        assertEq(lock.multipliers(nineMonths), 5e18);
        assertEq(lock.multipliers(twelveMonths), 7e18);

        assertEq(lock.minToLock(), 30_000 ether);
    }

    function testRevertLockWhenUnderMinAmount() external {
        uint256 period = lock.SIX_MONTHS();

        vm.startPrank(bob);
        vm.expectRevert(ISamLock.SamLock__InsufficientAmount.selector);
        lock.lock(minAmount - 10 ether, period);
        vm.stopPrank();
    }

    function testRevertLockWithInvalidPeriod() external {
        uint256 amount = 30_0000 ether;
        uint256 period = 30 days * 24; // => invalid period
        deal(token, bob, amount);

        vm.startPrank(bob);
        vm.expectRevert(ISamLock.SamLock__Invalid_Period.selector);
        lock.lock(amount, period);
        vm.stopPrank();
    }

    modifier locked(address wallet, uint256 amount) {
        vm.startPrank(wallet);

        deal(token, wallet, amount);
        ERC20(token).approve(address(lock), amount);

        vm.expectEmit(true, true, true, true);
        emit ISamLock.Locked(wallet, amount, lock.nextLockIndex());
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

        assertEq(lock.getLockInfos(bob).length, 2);
    }

    function testRevertWithdrawWithZeroAmount() external {
        vm.startPrank(bob);
        vm.expectRevert(ISamLock.SamLock__InsufficientAmount.selector);
        lock.withdraw(0, 0);
        vm.stopPrank();
    }

    function testRevertWithdrawWithGreaterAmount() external locked(bob, 30_000 ether) {
        ISamLock.LockInfo[] memory lockings = lock.getLockInfos(bob); // Using the getter function

        vm.warp(lockings[0].unlockTime);

        vm.startPrank(bob);
        vm.expectRevert(ISamLock.SamLock__InsufficientAmount.selector);
        lock.withdraw(lockings[0].lockedAmount * 2, 0);
        vm.stopPrank();
    }

    function testRevertWithdrawWhenBeforeUnlockDate() external locked(mary, 210_000 ether) {
        ISamLock.LockInfo[] memory lockings = lock.getLockInfos(mary); // Using the getter function

        vm.warp(lockings[0].unlockTime - 1 days);

        vm.startPrank(mary);
        vm.expectRevert(ISamLock.SamLock__Cannot_Unlock_Before_Period.selector);
        lock.withdraw(lockings[0].lockedAmount, 0);
        vm.stopPrank();
    }

    function testCanWithdraw() external locked(bob, 100_000 ether) {
        ISamLock.LockInfo[] memory lockings = lock.getLockInfos(bob);

        uint256 lockIndex = lockings[0].lockIndex;
        uint256 lockedAmount = lockings[0].lockedAmount;
        uint256 unlockTime = lockings[0].unlockTime;
        uint256 lockPeriod = lockings[0].lockPeriod;

        uint256 initialPoints = lock.pointsByLock(bob, lockIndex);

        assertEq(initialPoints, 0);

        vm.warp(unlockTime);
        vm.startPrank(bob);

        vm.expectEmit(true, true, true, true);
        emit ISamLock.Withdrawn(bob, lockedAmount, 0);
        lock.withdraw(lockedAmount, 0);

        vm.stopPrank();

        ISamLock.LockInfo[] memory latestLocks = lock.getLockInfos(bob);
        assertEq(latestLocks[0].withdrawnAmount, latestLocks[0].lockedAmount);

        uint256 currentPoints = lock.pointsByLock(bob, lockIndex);
        assertTrue(currentPoints > initialPoints);
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

        ISamLock.LockInfo[] memory lockings = lock.getLockInfos(bob);
        uint256 lockIndex = lockings[0].lockIndex;
        uint256 lockedAmount = lockings[0].lockedAmount;
        uint256 unlockTime = lockings[0].unlockTime;
        uint256 lockPeriod = lockings[0].lockPeriod;
        uint256 initialPoints = lock.pointsByLock(bob, lockIndex);

        assertEq(initialPoints, 0);
        assertEq(unlockTime, block.timestamp + threeMonths);
        assertEq(lockedAmount, amount);

        // Withdraw
        vm.warp(unlockTime);
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit ISamLock.Withdrawn(bob, amount, 0);
        lock.withdraw(amount, 0);
        vm.stopPrank();

        ISamLock.LockInfo[] memory latestLocks = lock.getLockInfos(bob);
        uint256 currentPoints = lock.pointsByLock(bob, lockIndex);
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

        ISamLock.LockInfo[] memory lockings = lock.getLockInfos(bob);
        uint256 lockIndex = lockings[0].lockIndex;
        uint256 lockedAmount = lockings[0].lockedAmount;
        uint256 unlockTime = lockings[0].unlockTime;
        uint256 lockPeriod = lockings[0].lockPeriod;

        uint256 initialPoints = lock.pointsByLock(bob, lockIndex);

        assertEq(initialPoints, 0);
        assertEq(unlockTime, block.timestamp + sixMonths);
        assertEq(lockedAmount, amount);

        // Withdraw
        vm.warp(unlockTime);
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit ISamLock.Withdrawn(bob, amount, 0);
        lock.withdraw(amount, 0);
        vm.stopPrank();

        ISamLock.LockInfo[] memory latestLocks = lock.getLockInfos(bob);
        uint256 currentPoints = lock.pointsByLock(bob, lockIndex);
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

        ISamLock.LockInfo[] memory lockings = lock.getLockInfos(bob);
        uint256 lockIndex = lockings[0].lockIndex;
        uint256 lockedAmount = lockings[0].lockedAmount;
        uint256 unlockTime = lockings[0].unlockTime;
        uint256 lockPeriod = lockings[0].lockPeriod;

        uint256 initialPoints = lock.pointsByLock(bob, lockIndex);

        assertEq(initialPoints, 0);
        assertEq(unlockTime, block.timestamp + nineMonths);
        assertEq(lockedAmount, amount);

        // Withdraw
        vm.warp(unlockTime);
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit ISamLock.Withdrawn(bob, amount, 0);
        lock.withdraw(amount, 0);
        vm.stopPrank();

        ISamLock.LockInfo[] memory latestLocks = lock.getLockInfos(bob);
        uint256 currentPoints = lock.pointsByLock(bob, lockIndex);
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

        ISamLock.LockInfo[] memory lockings = lock.getLockInfos(bob);
        uint256 lockIndex = lockings[0].lockIndex;
        uint256 lockedAmount = lockings[0].lockedAmount;
        uint256 unlockTime = lockings[0].unlockTime;
        uint256 lockPeriod = lockings[0].lockPeriod;
        uint256 initialPoints = lock.pointsByLock(bob, lockIndex);

        assertEq(initialPoints, 0);
        assertEq(unlockTime, block.timestamp + twelveMonths);
        assertEq(lockedAmount, amount);

        // Withdraw
        vm.warp(unlockTime);
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit ISamLock.Withdrawn(bob, amount, 0);
        lock.withdraw(amount, 0);
        vm.stopPrank();

        ISamLock.LockInfo[] memory latestLocks = lock.getLockInfos(bob);
        uint256 currentPoints = lock.pointsByLock(bob, lockIndex);
        assertEq(latestLocks[0].withdrawnAmount, latestLocks[0].lockedAmount);
        assertEq(currentPoints, ud(lockedAmount).mul(ud(lock.multipliers(lockPeriod))).intoUint256());
    }

    function testRevertUpdateMultipliersWithZeroValues() external {
        vm.startPrank(owner);
        vm.expectRevert(ISamLock.SamLock__InvalidMultiplier.selector);
        lock.updateMultipliers(0, 2e18, 3e18, 4e18);

        vm.expectRevert(ISamLock.SamLock__InvalidMultiplier.selector);
        lock.updateMultipliers(1e18, 0, 3e18, 4e18);

        vm.expectRevert(ISamLock.SamLock__InvalidMultiplier.selector);
        lock.updateMultipliers(1e18, 2e18, 0, 4e18);

        vm.expectRevert(ISamLock.SamLock__InvalidMultiplier.selector);
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
        emit ISamLock.MultipliersUpdated(
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
        ISamLock.LockInfo[] memory latestLocks = lock.getLockInfos(bob);

        vm.warp(latestLocks[0].unlockTime);
        uint256 points = lock.pointsByLock(bob, 0);

        vm.startPrank(bob);

        deal(token, bob, newMinAmount);
        ERC20(token).approve(address(lock), newMinAmount);

        lock.lock(newMinAmount, lock.THREE_MONTHS());
        vm.stopPrank();

        uint256 multiplier = lock.multipliers(latestLocks[0].lockPeriod);

        assertEq(points, ud(latestLocks[0].lockedAmount).mul(ud(multiplier)).intoUint256());
    }

    function testRevertPointsByLockWithWrongIndex() external locked(bob, 30_000 ether) {
        vm.expectRevert(ISamLock.SamLock__InvalidLockIndex.selector);
        lock.pointsByLock(bob, 1);
    }

    function testCanCheckTotalPoints() external locked(bob, 30_000 ether) {
        uint256 initialPoints = lock.pointsByLock(bob, 0);

        vm.warp(block.timestamp + 2 days);
        uint256 pointsIn2Days = lock.pointsByLock(bob, 0);

        vm.warp(block.timestamp + 5 days); //7 days
        uint256 pointsIn7Days = lock.pointsByLock(bob, 0);

        vm.warp(block.timestamp + 20 days); // 27 days
        uint256 pointsIn27Days = lock.pointsByLock(bob, 0);

        vm.warp(block.timestamp + 30 days); // 57 days
        uint256 pointsIn57Days = lock.pointsByLock(bob, 0);

        vm.warp(block.timestamp + 23 days); // 80 days
        uint256 pointsIn80Days = lock.pointsByLock(bob, 0);

        vm.warp(block.timestamp + 10 days); // 90 days
        uint256 pointsIn90Days = lock.pointsByLock(bob, 0);

        vm.warp(block.timestamp + 10 days); // 100 days
        uint256 pointsIn100Days = lock.pointsByLock(bob, 0);

        assertTrue(pointsIn2Days > initialPoints);
        assertTrue(pointsIn7Days > pointsIn2Days);
        assertTrue(pointsIn27Days > pointsIn7Days);
        assertTrue(pointsIn57Days > pointsIn27Days);
        assertTrue(pointsIn80Days > pointsIn57Days);
        assertTrue(pointsIn90Days > pointsIn80Days);
        assertTrue(pointsIn100Days == pointsIn90Days);
    }

    function testRevertGetLockInfosWhithoutAny() external {
        vm.startPrank(bob);
        ISamLock.LockInfo[] memory lockInfos = lock.getLockInfos(bob);
        vm.stopPrank();

        assertEq(lockInfos.length, 0);
    }

    function testShouldReturnEmptyLockInfosWhenHasNoLock() external {
        vm.startPrank(bob);
        ISamLock.LockInfo[] memory lockInfos = lock.getLockInfos(bob);
        vm.stopPrank();

        assertEq(lockInfos.length, 0);
    }
}
