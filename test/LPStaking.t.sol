// SPDX-License-Identifier: UNLINCENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {console} from "forge-std/console.sol";
import {LPStaking} from "../src/LPStaking.sol";
import {DeployLPStaking} from "../script/DeployLPStaking.s.sol";
import {ILPStaking} from "../src/interfaces/ILPStaking.sol";
import {IGauge} from "../src/interfaces/IGauge.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";

contract LPStakingTest is Test {
    uint256 fork;
    string public RPC_URL;

    DeployLPStaking deployer;
    LPStaking staking;
    address lpToken;
    address rewardsToken;
    address gauge;
    address gaugeRewardsToken;

    address owner;
    address bob;
    address mary;

    uint256 period = 60 days;
    uint256 minToStake;
    uint256 threeMonths;

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployLPStaking();
        (staking, lpToken, rewardsToken, gauge, gaugeRewardsToken) = deployer.runForTests();
        owner = staking.owner();
        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");

        minToStake = staking.minToStake();
        threeMonths = staking.THREE_MONTHS();
        deal(rewardsToken, address(staking), 100 ether);
    }

    // CONSTRUCTOR

    function testConstructor() public {
        assertEq(staking.owner(), owner);
        assertEq(address(staking.lpToken()), lpToken);
        assertEq(address(staking.rewardsToken()), rewardsToken);
        assertEq(address(staking.gauge()), gauge);
    }

    // // GET FEES

    // function testGetFees() external {
    //     vm.startPrank(bob);
    //     uint256 amount = 400e18;
    //     uint256 currentFee = staking.withdrawEarlierFee().intoUint256();

    //     uint256 result = staking.getFees(amount);

    //     assertEq(result, amount * currentFee / 1e18);
    //     vm.stopPrank();
    // }

    // // INIT

    // modifier initialized(uint256 duration, uint256 rewardsPerDay) {
    //     vm.startPrank(owner);
    //     staking.init(duration, rewardsPerDay);
    //     vm.stopPrank();
    //     _;
    // }

    // function testCanInit() external  {
    //     assertEq(staking.periodFinish(), block.timestamp + period);
    //     assertFalse(staking.paused());
    // }

    // function testRevertWhenAlreadyInitialized() external  {
    //     vm.startPrank(owner);
    //     vm.expectRevert(Pausable.ExpectedPause.selector);
    //     staking.init(period, 10 ether);
    //     vm.stopPrank();
    // }

    modifier hasBalance(address wallet, uint256 amount) {
        deal(lpToken, wallet, amount);
        _;
    }

    // STAKING

    // function testRevertStakeWhenPeriodFinished() external {
    //     vm.warp(staking.periodFinish() + 1 minutes);

    //     vm.startPrank(bob);
    //     vm.expectRevert(ILPStaking.ILPStaking__Error.selector);
    //     staking.stake(1 ether);
    //     vm.stopPrank();
    // }

    function testRevertStakeWhenAmountIsZero() external {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILPStaking.ILPStaking__Error.selector, "Insufficient amount"));
        staking.stake(0, threeMonths);
        vm.stopPrank();
    }

    function testRevertStakeWithInvalidPeriod() external {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILPStaking.ILPStaking__Error.selector, "Invalid period"));
        staking.stake(minToStake, threeMonths + 1);
        vm.stopPrank();
    }

    function testCanStake() external hasBalance(bob, minToStake) {
        vm.startPrank(bob);
        ERC20(lpToken).approve(address(staking), minToStake);
        vm.expectEmit(true, true, true, true);
        emit ILPStaking.Staked(bob, minToStake, 0);
        staking.stake(minToStake, threeMonths);
        vm.stopPrank();

        (, uint256 stakedAmount,, uint256 stakedAt,,,, uint256 claimedRewards,) = staking.stakes(bob, 0);

        assertEq(stakedAmount, minToStake);
        assertEq(stakedAt, block.timestamp);
        assertEq(claimedRewards, 0);
        assertEq(IGauge(gauge).balanceOf(address(staking)), stakedAmount);
        assertEq(staking.totalStaked(), stakedAmount);
    }

    modifier hasStaked(address wallet, uint256 amount, uint256 stakePeriod) {
        vm.startPrank(wallet);
        ERC20(lpToken).approve(address(staking), amount);
        staking.stake(amount, stakePeriod);
        vm.stopPrank();
        _;
    }

    function testRevertStakeWhenMaxStakesReached()
        external
        hasBalance(bob, minToStake * 5)
        hasStaked(bob, minToStake, threeMonths)
        hasStaked(bob, minToStake, threeMonths)
        hasStaked(bob, minToStake, threeMonths)
        hasStaked(bob, minToStake, threeMonths)
        hasStaked(bob, minToStake, threeMonths)
    {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILPStaking.ILPStaking__Error.selector, "Max stakes reached"));
        staking.stake(minToStake, threeMonths);
        vm.stopPrank();
    }

    // WITHDRAW

    function testRevertWithdrawIfAmountIsZero()
        external
        hasBalance(bob, minToStake)
        hasStaked(bob, minToStake, threeMonths)
    {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILPStaking.ILPStaking__Error.selector, "Insufficient amount"));
        staking.withdraw(0, 0);
        vm.stopPrank();
    }

    function testRevertWithInvalidStakeIndex() external {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILPStaking.ILPStaking__Error.selector, "Invalid stake index"));
        staking.withdraw(minToStake, 0);
        vm.stopPrank();
    }

    function testRevertWithdrawBeforePeriodEnds()
        external
        hasBalance(bob, minToStake)
        hasStaked(bob, minToStake, threeMonths)
    {
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(ILPStaking.ILPStaking__Error.selector, "Cannot withdraw before period ends")
        );
        staking.withdraw(minToStake, 0);
        vm.stopPrank();
    }

    function testRevertWithdrawIfAmountIsGreaterThanStakedBalance()
        external
        hasBalance(bob, minToStake)
        hasStaked(bob, minToStake, threeMonths)
    {
        vm.warp(block.timestamp + threeMonths + 1 hours);
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILPStaking.ILPStaking__Error.selector, "Insufficient amount"));
        staking.withdraw(minToStake * 2, 0);
        vm.stopPrank();
    }

    function testCanWithdrawStakedBalance()
        external
        hasBalance(bob, minToStake)
        hasStaked(bob, minToStake, threeMonths)
    {
        vm.warp(block.timestamp + threeMonths + 1 hours);
        uint256 initialWalletBalance = ERC20(lpToken).balanceOf(bob);

        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit ILPStaking.Withdrawn(bob, minToStake, 0);
        staking.withdraw(minToStake, 0);
        vm.stopPrank();

        (, uint256 stakedAmount, uint256 withdrawnAmount,,,,,,) = staking.stakes(bob, 0);
        uint256 endWalletBalance = ERC20(lpToken).balanceOf(bob);

        assertEq(initialWalletBalance + minToStake, endWalletBalance);
        assertEq(stakedAmount - withdrawnAmount, 0);
    }

    // function testPayTaxToWithdrawEarlier() external hasBalance(bob, minToStake) hasStaked(bob, minToStake) {
    //     uint256 initialWalletBalance = ERC20(lpToken).balanceOf(bob);
    //     (uint256 lockedAmount,,,) = staking.stakings(bob);

    //     uint256 tax = staking.getFees(lockedAmount);

    //     vm.startPrank(bob);
    //     vm.expectEmit(true, true, true, false);
    //     emit ILPStaking.StakeWithdrawn(bob, minToStake - tax);
    //     staking.withdraw(minToStake);
    //     vm.stopPrank();

    //     uint256 endWalletBalance = ERC20(lpToken).balanceOf(bob);

    //     assertEq(initialWalletBalance + minToStake - tax, endWalletBalance);
    // }

    // function testCanWithdrawAfterPeriodFinish() external hasBalance(bob, minToStake) hasStaked(bob, minToStake) {
    //     vm.warp(staking.periodFinish() + 3 days);

    //     uint256 initialWalletBalance = ERC20(lpToken).balanceOf(bob);

    //     vm.startPrank(bob);
    //     vm.expectEmit(true, true, true, true);
    //     emit ILPStaking.StakeWithdrawn(bob, minToStake);
    //     staking.withdraw(minToStake);
    //     vm.stopPrank();

    //     (uint256 lockedAmount,,, uint256 rewardsEarned) = staking.stakings(bob);
    //     uint256 endWalletBalance = ERC20(lpToken).balanceOf(bob);

    //     assertEq(initialWalletBalance + minToStake, endWalletBalance);
    //     assertEq(lockedAmount, 0);
    //     assertTrue(rewardsEarned > 0);
    // }

    // function testCanWithdrawAfterEmergencyWithdraw() external hasBalance(bob, minToStake) hasStaked(bob, minToStake) {
    //     uint256 initialWalletBalance = ERC20(lpToken).balanceOf(bob);

    //     vm.warp(block.timestamp + 2 days); // to increase rewards
    //     uint256 initialRewards = staking.calculateRewards(bob);

    //     vm.startPrank(owner);
    //     staking.emergencyWithdraw();
    //     vm.stopPrank();

    //     vm.warp(block.timestamp + 10 weeks);

    //     vm.startPrank(bob);
    //     vm.expectEmit(true, true, true, true);
    //     emit ILPStaking.StakeWithdrawn(bob, minToStake);
    //     staking.withdraw(minToStake);
    //     vm.stopPrank();

    //     (uint256 endLockedAmount,,,) = staking.stakings(bob);
    //     uint256 endWalletBalance = ERC20(lpToken).balanceOf(bob);
    //     uint256 endRewards = staking.calculateRewards(bob);

    //     assertEq(initialWalletBalance + minToStake, endWalletBalance);
    //     assertEq(endLockedAmount, 0);
    //     assertEq(initialRewards, endRewards);
    //     assertTrue(endRewards > 0);
    // }

    // modifier withdrawn(address wallet, uint256 amount, uint256 timestamp) {
    //     if (timestamp > 0) vm.warp(block.timestamp + timestamp);

    //     vm.startPrank(wallet);
    //     staking.withdraw(amount);
    //     vm.stopPrank();
    //     _;
    // }

    // // CALCULATE REWARDS

    // function testCanCheckRewards()
    //     external
    //     hasBalance(bob, minToStake)
    //     hasBalance(mary, minToStake)
    //     hasStaked(bob, minToStake)
    //     hasStaked(mary, minToStake)
    // {
    //     uint256 bobRewards1 = staking.calculateRewards(bob);
    //     uint256 maryRewards1 = staking.calculateRewards(mary);

    //     assertEq(bobRewards1, 0);
    //     assertEq(maryRewards1, 0);

    //     vm.warp(block.timestamp + 10 days);

    //     uint256 bobRewards2 = staking.calculateRewards(bob);
    //     uint256 maryRewards2 = staking.calculateRewards(mary);

    //     assertTrue(bobRewards2 > bobRewards1);
    //     assertTrue(maryRewards2 > maryRewards1);

    //     vm.warp(block.timestamp + 10 days);

    //     uint256 bobRewards3 = staking.calculateRewards(bob);
    //     uint256 maryRewards3 = staking.calculateRewards(mary);

    //     assertTrue(bobRewards3 > bobRewards2);
    //     assertTrue(maryRewards3 > maryRewards2);
    // }

    // // CLAIM REWARDS

    // function testRevertClaimStakeWhenTotalRewardsIsZero() external {
    //     vm.startPrank(bob);
    //     vm.expectRevert(abi.encodeWithSelector(ILPStaking.ILPStaking__Error.selector, "No rewards available"));
    //     staking.claimRewards();
    //     vm.stopPrank();
    // }

    // function testRevertClaimStakeWhenWalletRewardsAreZero()
    //     external
    //     hasBalance(bob, minToStake)
    //     hasStaked(bob, minToStake)
    // {
    //     vm.warp(block.timestamp + 2 days);

    //     vm.startPrank(bob);
    //     vm.expectRevert(abi.encodeWithSelector(ILPStaking.ILPStaking__Error.selector, "No rewards available"));
    //     staking.claimRewards();
    //     vm.stopPrank();
    // }

    // function testCanClaimRewards() external hasBalance(bob, minToStake) hasStaked(bob, minToStake) {
    //     vm.warp(block.timestamp + 10 days);
    //     uint256 initialRewardsBalance = ERC20(rewardsToken).balanceOf(bob);
    //     uint256 initialRewards = staking.calculateRewards(bob);

    //     vm.startPrank(bob);
    //     vm.expectEmit(true, true, true, true);
    //     emit ILPStaking.RewardsClaimed(block.timestamp, bob, initialRewards);
    //     staking.claimRewards();
    //     vm.stopPrank();

    //     uint256 zeroRewards = staking.calculateRewards(bob);
    //     uint256 endRewardsBalance = ERC20(rewardsToken).balanceOf(bob);

    //     assertEq(zeroRewards, 0);
    //     assertEq(endRewardsBalance, initialRewardsBalance + initialRewards);
    // }

    // // CLAIM FEES

    // function testCanClaimFees()
    //     external
    //     hasBalance(bob, minToStake)
    //     hasBalance(mary, minToStake)
    //     hasStaked(bob, minToStake)
    //     hasStaked(mary, minToStake)
    //     withdrawn(bob, minToStake, 0)
    //     withdrawn(mary, minToStake, 0)
    // {
    //     uint256 feesToClaim = staking.getFees(minToStake) * 2;
    //     uint256 currentFeesAvailable = staking.collectedFees();

    //     assertEq(feesToClaim, currentFeesAvailable);

    //     uint256 ownerBalance = ERC20(lpToken).balanceOf(owner);

    //     vm.startPrank(owner);
    //     vm.expectEmit(true, true, true, true);
    //     emit ILPStaking.FeesWithdrawn(feesToClaim);
    //     staking.collectFees();
    //     vm.stopPrank();

    //     uint256 endOwnerBalance = ERC20(lpToken).balanceOf(owner);

    //     assertEq(staking.collectedFees(), 0);
    //     assertEq(endOwnerBalance, ownerBalance + feesToClaim);
    // }

    // // EMERGENCY WITHDRAW

    // function testCanDoEmergencyWithdraw()
    //     external
    //     hasBalance(bob, minToStake)
    //     hasBalance(mary, minToStake)
    //     hasStaked(bob, minToStake)
    //     hasStaked(mary, minToStake)
    // {
    //     uint256 feesToClaim = staking.getFees(minToStake) * 2;

    //     vm.startPrank(owner);
    //     vm.expectEmit(true, true, true, false);
    //     emit ILPStaking.EmergencyWithdrawnFunds(feesToClaim);
    //     staking.emergencyWithdraw();
    //     vm.stopPrank();

    //     assertEq(staking.collectedFees(), 0);
    //     assertEq(staking.periodFinish(), block.timestamp);
    //     assertTrue(staking.paused());
    // }

    // // UPDATE SENSTIVE DATA

    // function testUpdateWithdrawEarlierFeeLockTime() external {
    //     vm.startPrank(owner);
    //     uint256 newLockTime = staking.withdrawEarlierFeeLockTime() * 2;
    //     staking.updateWithdrawEarlierFeeLockTime(newLockTime);
    //     vm.stopPrank();

    //     assertEq(staking.withdrawEarlierFeeLockTime(), newLockTime);
    // }

    // function testUpdateWithdrawEarlierFee() external {
    //     vm.startPrank(owner);
    //     uint256 newFee = staking.withdrawEarlierFee().intoUint256() * 2;
    //     staking.updateWithdrawEarlierFee(newFee);
    //     vm.stopPrank();

    //     assertEq(staking.withdrawEarlierFee().intoUint256(), newFee);
    // }

    // function testRevertUpdateminToStakeWhenZero() external {
    //     vm.startPrank(owner);
    //     vm.expectRevert(ILPStaking.ILPStaking__Error.selector);
    //     staking.updateminToStake(0);
    //     vm.stopPrank();
    // }

    // function testUpdateminToStake() external {
    //     vm.startPrank(owner);
    //     uint256 newminToStake = staking.minToStake() * 2;
    //     staking.updateminToStake(newminToStake);
    //     vm.stopPrank();

    //     assertEq(staking.minToStake(), newminToStake);
    // }
}
