// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/console.sol";
import {SamLockVS} from "src/SamLockVS.sol";
import {DeployLockVS} from "script/DeployLockVS.s.sol";
import {ILockS} from "src/interfaces/ILockS.sol";
import {UD60x18, ud} from "@prb/math/src/UD60x18.sol";

contract SamLockVSTest is Test {
    uint256 fork;
    string public RPC_URL;

    DeployLockVS deployer;
    SamLockVS lock;
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
        RPC_URL = vm.envString("SONIC_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployLockVS();

        (lock, token) = deployer.runForTests();

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

    function testConstructor() public view {
        assertEq(lock.owner(), owner);
        assertEq(lock.maxRequestsPerBatch(), 2);
        assertEq(address(lock.sam()), token);

        assertEq(lock.multipliers(threeMonths), 1e18);
        assertEq(lock.multipliers(sixMonths), 3e18);
        assertEq(lock.multipliers(nineMonths), 5e18);
        assertEq(lock.multipliers(twelveMonths), 7e18);

        assertEq(lock.minToLock(), 30_000 ether);

        assertEq(lock.totalLocked(), 0);
        assertEq(lock.totalWithdrawn(), 0);
        assertEq(lock.totalPointsFulfilled(), 0);
    }

    function testRevertLockWhenUnderMinAmount() external {
        uint256 period = lock.SIX_MONTHS();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILockS.ILock__Error.selector, "Insufficient amount"));
        lock.lock(minAmount - 10 ether, period);
        vm.stopPrank();
    }

    function testRevertLockWithInvalidPeriod() external {
        uint256 amount = 30_0000 ether;
        uint256 period = 30 days * 24; // => invalid period
        deal(token, bob, amount);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILockS.ILock__Error.selector, "Invalid period"));
        lock.lock(amount, period);
        vm.stopPrank();
    }

    modifier locked(address wallet, uint256 amount) {
        vm.startPrank(wallet);

        deal(token, wallet, amount);
        ERC20(token).approve(address(lock), amount);

        vm.expectEmit(true, true, true, true);
        emit ILockS.Locked(wallet, amount);
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
        vm.expectRevert(abi.encodeWithSelector(ILockS.ILock__Error.selector, "Insufficient amount"));
        lock.withdraw(0, 0);
        vm.stopPrank();
    }

    function testRevertWithdrawWithGreaterAmount() external locked(bob, 30_000 ether) {
        ILockS.LockInfo[] memory lockings = lock.locksOf(bob); // Using the getter function

        vm.warp(lockings[0].unlockTime);

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILockS.ILock__Error.selector, "Insufficient amount"));
        lock.withdraw(lockings[0].lockedAmount * 2, 0);
        vm.stopPrank();
    }

    function testRevertWithdrawWhenBeforeUnlockDate() external locked(mary, 210_000 ether) {
        ILockS.LockInfo[] memory lockings = lock.locksOf(mary); // Using the getter function

        vm.warp(lockings[0].unlockTime - 1 days);

        vm.startPrank(mary);
        vm.expectRevert(abi.encodeWithSelector(ILockS.ILock__Error.selector, "Cannot unlock before period"));
        lock.withdraw(lockings[0].lockedAmount, 0);
        vm.stopPrank();
    }

    function testCanWithdraw() external locked(bob, 100_000 ether) {
        ILockS.LockInfo[] memory lockings = lock.locksOf(bob);

        uint256 lockedAmount = lockings[0].lockedAmount;
        uint256 unlockTime = lockings[0].unlockTime;
        uint256 lockPeriod = lockings[0].lockPeriod;

        vm.warp(unlockTime);
        vm.startPrank(bob);

        vm.expectEmit(true, true, true, true);
        emit ILockS.Withdrawn(bob, lockedAmount, 0);
        lock.withdraw(lockedAmount, 0);

        vm.stopPrank();

        ILockS.LockInfo[] memory latestLocks = lock.locksOf(bob);
        assertEq(latestLocks[0].withdrawnAmount, latestLocks[0].lockedAmount);

        uint256 currentPoints = lock.previewClaimablePoints(bob, 0);
        assertEq(currentPoints, ud(lockedAmount).mul(ud(lock.multipliers(lockPeriod))).intoUint256());
    }

    function testRevertRequests() external {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILockS.ILock__Error.selector, "You have no locks"));
        lock.request(0);
        vm.stopPrank();
    }

    function testRevertRequestPointsWithInvalidIndex() external locked(bob, 30_000 ether) {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILockS.ILock__Error.selector, "Invalid lock index"));
        lock.request(1);
        vm.stopPrank();
    }

    function testRevertRequestWhenFulfilled() external locked(bob, 30_000 ether) {
        vm.startPrank(bob);
        lock.request(0);
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(owner);
        ILockS.Request[] memory requests = new ILockS.Request[](1);
        (address wallet, uint256 amount, uint256 lockIndex, uint256 batchId, bool isFulfilled) = lock.requests(bob, 0);
        requests[0] = ILockS.Request(wallet, amount, lockIndex, batchId, isFulfilled);
        lock.fulfill(0);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILockS.ILock__Error.selector, "Request already fulfilled"));
        lock.request(0);
        vm.stopPrank();
    }

    function testRevertRequestWhenAlreadyRequested() external locked(bob, 30_000 ether) {
        vm.startPrank(bob);
        lock.request(0);
        vm.warp(block.timestamp + 1 days);
        vm.expectRevert(abi.encodeWithSelector(ILockS.ILock__Error.selector, "Already requested"));
        lock.request(0);
        vm.stopPrank();
    }

    function testRequestPoints() external locked(bob, 30_000 ether) {
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, false);
        emit ILockS.PointsRequested(bob, 30_000 ether);
        lock.request(0);

        vm.warp(block.timestamp + 1 days);

        deal(token, bob, 60_000 ether);
        ERC20(token).approve(address(lock), 60_000 ether);
        lock.lock(60_000 ether, lock.SIX_MONTHS());
        lock.request(1);

        assertEq(lock.locksOf(bob).length, 2);
        assertEq(lock.totalPointsPending(), 210_000 ether);
        assertEq(lock.requestsOf(0).length, 2);
        assertEq(lock.batchIsFulfilled(0), false);
        vm.stopPrank();
    }

    function testBatchesManagement()
        external
        locked(bob, 30_000 ether)
        locked(mary, 60_000 ether)
        locked(bob, 30_000 ether)
    {
        assertEq(lock.totalPointsPending(), 0);
        assertEq(lock.totalPointsFulfilled(), 0);

        // Wallet request points
        vm.startPrank(bob);
        lock.request(0);
        vm.stopPrank();

        assertEq(lock.totalPointsPending(), 30_000 ether);
        assertEq(lock.totalPointsFulfilled(), 0);

        vm.warp(block.timestamp + 1 days);
        vm.startPrank(mary);
        lock.request(0);
        vm.stopPrank();

        assertEq(lock.totalPointsPending(), 90_000 ether);
        assertEq(lock.totalPointsFulfilled(), 0);

        vm.warp(block.timestamp + 1 days);
        vm.startPrank(bob);
        lock.request(1);
        vm.stopPrank();

        assertEq(lock.totalPointsPending(), 120_000 ether);
        assertEq(lock.lastBatchId(), 1);
        assertEq(lock.batchIsFulfilled(0), false);
        assertEq(lock.batchIsFulfilled(1), false);

        // Owner fulfill points
        vm.startPrank(owner);
        lock.fulfill(0);
        vm.stopPrank();

        assertEq(lock.batchIsFulfilled(0), true);
        assertEq(lock.totalPointsFulfilled(), 90_000 ether); // fulfilled request 1 and 2 on batch 0
        assertEq(lock.totalPointsPending(), 30_000 ether);
        assertEq(lock.batchIsFulfilled(1), false);

        vm.startPrank(owner);
        lock.fulfill(1);
        vm.stopPrank();

        assertEq(lock.batchIsFulfilled(1), true);
        assertEq(lock.totalPointsPending(), 0);
        assertEq(lock.totalPointsFulfilled(), 120_000 ether);
    }

    function testFulfillRequests() external locked(bob, 30_000 ether) locked(mary, 60_000 ether) {
        assertEq(lock.totalPointsPending(), 0);
        assertEq(lock.totalPointsFulfilled(), 0);

        // Wallet request points
        vm.startPrank(bob);
        lock.request(0);
        vm.stopPrank();

        assertEq(lock.totalPointsPending(), 30_000 ether);
        assertEq(lock.totalPointsFulfilled(), 0);

        // Owner fulfill points
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, false);
        emit ILockS.RequestFulfilled(0);
        lock.fulfill(0);
        vm.stopPrank();

        assertEq(lock.totalPointsPending(), 0);
        assertEq(lock.totalPointsFulfilled(), 30_000 ether);
        assertEq(lock.batchIsFulfilled(0), true);

        vm.warp(block.timestamp + 1 days);
        vm.startPrank(mary);
        lock.request(0);
        vm.stopPrank();

        assertEq(lock.totalPointsPending(), 60_000 ether);

        // Owner fulfill points
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, false);
        emit ILockS.RequestFulfilled(1);
        lock.fulfill(1);
        vm.stopPrank();

        assertEq(lock.totalPointsPending(), 0);
        assertEq(lock.totalPointsFulfilled(), 90_000 ether);
        assertEq(lock.batchIsFulfilled(1), true);
    }

    function testFuzzLockProcessWith3Months(uint256 amount) external {
        vm.assume(amount >= minAmount && amount < 300_000 ether);

        // Lock
        vm.startPrank(bob);
        deal(token, bob, amount);
        ERC20(token).approve(address(lock), amount);
        lock.lock(amount, threeMonths);
        vm.stopPrank();

        ILockS.LockInfo[] memory lockings = lock.locksOf(bob);
        uint256 lockedAmount = lockings[0].lockedAmount;
        uint256 unlockTime = lockings[0].unlockTime;
        uint256 lockPeriod = lockings[0].lockPeriod;

        assertEq(unlockTime, block.timestamp + threeMonths);
        assertEq(lockedAmount, amount);

        // Withdraw
        vm.warp(unlockTime);
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit ILockS.Withdrawn(bob, amount, 0);
        lock.withdraw(amount, 0);
        vm.stopPrank();

        ILockS.LockInfo[] memory latestLocks = lock.locksOf(bob);
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

        ILockS.LockInfo[] memory lockings = lock.locksOf(bob);
        uint256 lockedAmount = lockings[0].lockedAmount;
        uint256 unlockTime = lockings[0].unlockTime;
        uint256 lockPeriod = lockings[0].lockPeriod;

        assertEq(unlockTime, block.timestamp + sixMonths);
        assertEq(lockedAmount, amount);

        // Withdraw
        vm.warp(unlockTime);
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit ILockS.Withdrawn(bob, amount, 0);
        lock.withdraw(amount, 0);
        vm.stopPrank();

        ILockS.LockInfo[] memory latestLocks = lock.locksOf(bob);
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

        ILockS.LockInfo[] memory lockings = lock.locksOf(bob);
        uint256 lockedAmount = lockings[0].lockedAmount;
        uint256 unlockTime = lockings[0].unlockTime;
        uint256 lockPeriod = lockings[0].lockPeriod;

        assertEq(unlockTime, block.timestamp + nineMonths);
        assertEq(lockedAmount, amount);

        // Withdraw
        vm.warp(unlockTime);
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit ILockS.Withdrawn(bob, amount, 0);
        lock.withdraw(amount, 0);
        vm.stopPrank();

        ILockS.LockInfo[] memory latestLocks = lock.locksOf(bob);
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

        ILockS.LockInfo[] memory lockings = lock.locksOf(bob);
        uint256 lockedAmount = lockings[0].lockedAmount;
        uint256 unlockTime = lockings[0].unlockTime;
        uint256 lockPeriod = lockings[0].lockPeriod;

        assertEq(unlockTime, block.timestamp + twelveMonths);
        assertEq(lockedAmount, amount);

        // Withdraw
        vm.warp(unlockTime);
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit ILockS.Withdrawn(bob, amount, 0);
        lock.withdraw(amount, 0);
        vm.stopPrank();

        ILockS.LockInfo[] memory latestLocks = lock.locksOf(bob);
        uint256 currentPoints = lock.previewClaimablePoints(bob, 0);
        assertEq(latestLocks[0].withdrawnAmount, latestLocks[0].lockedAmount);
        assertEq(currentPoints, ud(lockedAmount).mul(ud(lock.multipliers(lockPeriod))).intoUint256());
    }

    function testRevertUpdateMultipliersWithZeroValues() external {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(ILockS.ILock__Error.selector, "Invalid multiplier"));
        lock.updateMultipliers(0, 2e18, 3e18, 4e18);

        vm.expectRevert(abi.encodeWithSelector(ILockS.ILock__Error.selector, "Invalid multiplier"));
        lock.updateMultipliers(1e18, 0, 3e18, 4e18);

        vm.expectRevert(abi.encodeWithSelector(ILockS.ILock__Error.selector, "Invalid multiplier"));
        lock.updateMultipliers(1e18, 2e18, 0, 4e18);

        vm.expectRevert(abi.encodeWithSelector(ILockS.ILock__Error.selector, "Invalid multiplier"));
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
        emit ILockS.MultipliersUpdated(
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
        ILockS.LockInfo[] memory latestLocks = lock.locksOf(bob);

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
        ILockS.LockInfo[] memory lockInfos = lock.locksOf(bob);
        vm.stopPrank();

        assertEq(lockInfos.length, 0);
    }

    function testShouldReturnEmptyLockInfosWhenHasNoLock() external {
        vm.startPrank(bob);
        ILockS.LockInfo[] memory lockInfos = lock.locksOf(bob);
        vm.stopPrank();

        assertEq(lockInfos.length, 0);
    }
}
