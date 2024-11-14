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
    address points;

    uint256 pointsPerToken;
    uint256 threeMonths = 90 days;
    uint256 amountToStake = 10 ether;

    address owner;
    address bob;
    address mary;

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployLPStaking();
        (staking, lpToken, rewardsToken, gauge, points) = deployer.runForTests();
        owner = staking.owner();
        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");

        pointsPerToken = staking.pointsPerToken();
        deal(rewardsToken, address(staking), 100 ether);
    }

    // CONSTRUCTOR

    function testConstructor() public view {
        assertEq(staking.owner(), owner);
        assertEq(address(staking.lpToken()), lpToken);
        assertEq(address(staking.rewardsToken()), rewardsToken);
        assertEq(address(staking.gauge()), gauge);
        assertEq(pointsPerToken, 1071 ether);
    }

    modifier hasBalance(address wallet, uint256 amount) {
        deal(lpToken, wallet, amount);
        _;
    }

    function testRevertStakeWhenAmountIsZero() external {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILPStaking.ILPStaking__Error.selector, "Insufficient amount"));
        staking.stake(0, threeMonths);
        vm.stopPrank();
    }

    function testRevertStakeWithInvalidPeriod() external {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILPStaking.ILPStaking__Error.selector, "Invalid period"));
        staking.stake(amountToStake, threeMonths + 1);
        vm.stopPrank();
    }

    function testCanStake() external hasBalance(bob, amountToStake) {
        vm.startPrank(bob);
        ERC20(lpToken).approve(address(staking), amountToStake);
        vm.expectEmit(true, true, true, true);
        emit ILPStaking.Staked(bob, amountToStake, 0);
        staking.stake(amountToStake, threeMonths);
        vm.stopPrank();

        (uint256 stakedAmount,, uint256 stakedAt,,,, uint256 claimedRewards,) = staking.stakes(bob, 0);

        assertEq(stakedAmount, amountToStake);
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
        hasBalance(bob, amountToStake * 5)
        hasStaked(bob, amountToStake, threeMonths)
        hasStaked(bob, amountToStake, threeMonths)
        hasStaked(bob, amountToStake, threeMonths)
        hasStaked(bob, amountToStake, threeMonths)
        hasStaked(bob, amountToStake, threeMonths)
    {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILPStaking.ILPStaking__Error.selector, "Max stakes reached"));
        staking.stake(amountToStake, threeMonths);
        vm.stopPrank();
    }

    // WITHDRAW

    function testRevertWithdrawIfAmountIsZero()
        external
        hasBalance(bob, amountToStake)
        hasStaked(bob, amountToStake, threeMonths)
    {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILPStaking.ILPStaking__Error.selector, "Insufficient amount"));
        staking.withdraw(0, 0);
        vm.stopPrank();
    }

    function testRevertWithInvalidStakeIndex() external {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILPStaking.ILPStaking__Error.selector, "Invalid stake index"));
        staking.withdraw(amountToStake, 0);
        vm.stopPrank();
    }

    function testRevertWithdrawIfAmountIsGreaterThanStakedBalance()
        external
        hasBalance(bob, amountToStake)
        hasStaked(bob, amountToStake, threeMonths)
    {
        vm.warp(block.timestamp + threeMonths + 1 hours);
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILPStaking.ILPStaking__Error.selector, "Insufficient amount"));
        staking.withdraw(amountToStake * 2, 0);
        vm.stopPrank();
    }

    function testCanWithdrawStakedBalance()
        external
        hasBalance(bob, amountToStake)
        hasStaked(bob, amountToStake, threeMonths)
    {
        vm.warp(block.timestamp + threeMonths + 1 hours);
        uint256 initialWalletBalance = ERC20(lpToken).balanceOf(bob);

        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit ILPStaking.Withdrawn(bob, amountToStake, 0);
        staking.withdraw(amountToStake, 0);
        vm.stopPrank();

        (uint256 stakedAmount, uint256 withdrawnAmount,,,,,,) = staking.stakes(bob, 0);
        uint256 endWalletBalance = ERC20(lpToken).balanceOf(bob);

        assertEq(initialWalletBalance + amountToStake, endWalletBalance);
        assertEq(stakedAmount - withdrawnAmount, 0);
    }

    function testRevertWithdrawBeforePeriodEnds()
        external
        hasBalance(bob, amountToStake)
        hasStaked(bob, amountToStake, threeMonths)
    {
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(ILPStaking.ILPStaking__Error.selector, "Not allowed to withdraw in staking period")
        );
        staking.withdraw(amountToStake, 0);
        vm.stopPrank();
    }

    function testCanWithdrawAfterPeriodFinish()
        external
        hasBalance(bob, amountToStake)
        hasStaked(bob, amountToStake, threeMonths)
    {
        (,,, uint256 withdrawTime,,,,) = staking.stakes(bob, 0);
        vm.warp(withdrawTime + 3 days);

        uint256 initialWalletBalance = ERC20(lpToken).balanceOf(bob);

        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit ILPStaking.Withdrawn(bob, amountToStake, 0);
        staking.withdraw(amountToStake, 0);
        vm.stopPrank();

        uint256 endWalletBalance = ERC20(lpToken).balanceOf(bob);

        assertEq(initialWalletBalance + amountToStake, endWalletBalance);
        assertEq(staking.totalWithdrawn(), amountToStake);
    }

    modifier withdrawn(address wallet, uint256 amount, uint256 timestamp) {
        if (timestamp > 0) vm.warp(block.timestamp + timestamp);

        vm.startPrank(wallet);
        staking.withdraw(amount, 0);
        vm.stopPrank();
        _;
    }

    // REWARDS

    function testCanCheckRewards()
        external
        hasBalance(bob, amountToStake)
        hasBalance(mary, amountToStake)
        hasStaked(bob, amountToStake, threeMonths)
        hasStaked(mary, amountToStake, threeMonths)
    {
        uint256 bobRewards1 = staking.previewRewards(bob);
        uint256 maryRewards1 = staking.previewRewards(mary);

        assertEq(bobRewards1, 0);
        assertEq(maryRewards1, 0);

        uint256 timestamp = block.timestamp + 100 days;

        vm.warp(timestamp);

        uint256 bobRewards2 = staking.previewRewards(bob);
        uint256 maryRewards2 = staking.previewRewards(mary);

        assertTrue(bobRewards2 > bobRewards1);
        assertTrue(maryRewards2 > maryRewards1);

        // timestamp += 200 days;

        // vm.warp(timestamp);

        // uint256 bobRewards3 = staking.previewRewards(bob);
        // uint256 maryRewards3 = staking.previewRewards(mary);

        // assertTrue(bobRewards3 > bobRewards2);
        // assertTrue(maryRewards3 > maryRewards2);
    }

    function testRevertClaimStakeWhenTotalRewardsIsZero() external {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILPStaking.ILPStaking__Error.selector, "Insufficient rewards to claim"));
        staking.claimRewards();
        vm.stopPrank();
    }

    function testRevertClaimStakeWhenWalletRewardsAreZero()
        external
        hasBalance(bob, amountToStake)
        hasStaked(bob, amountToStake, threeMonths)
    {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(ILPStaking.ILPStaking__Error.selector, "Insufficient rewards to claim"));
        staking.claimRewards();
        vm.stopPrank();
    }

    function testCanClaimRewards() external hasBalance(bob, amountToStake) hasStaked(bob, amountToStake, threeMonths) {
        vm.warp(block.timestamp + 10 days);
        uint256 initialRewardsBalance = ERC20(rewardsToken).balanceOf(bob);
        uint256 initialRewards = staking.previewRewards(bob);

        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit ILPStaking.RewardsClaimed(bob, initialRewards);
        staking.claimRewards();
        vm.stopPrank();

        uint256 zeroRewards = staking.previewRewards(bob);
        uint256 endRewardsBalance = ERC20(rewardsToken).balanceOf(bob);

        assertEq(zeroRewards, 0);
        assertEq(endRewardsBalance, initialRewardsBalance + initialRewards);
    }

    // POINTS

    function testCanPreviewClaimablePoints()
        public
        hasBalance(bob, amountToStake * 3)
        hasStaked(bob, amountToStake * 3, threeMonths * 2)
    {
        uint256 expectedPoints = ud(amountToStake * 3).mul(ud(1071 ether)).mul(ud(3 ether)).intoUint256();
        uint256 claimablePoints = staking.previewClaimablePoints(bob, 0);

        assertEq(claimablePoints, expectedPoints);
    }

    function testCanClaimPoints()
        public
        hasBalance(bob, amountToStake * 3)
        hasStaked(bob, amountToStake * 3, threeMonths * 2)
    {
        uint256 expectedPoints = ud(amountToStake * 3).mul(ud(1071 ether)).mul(ud(3 ether)).intoUint256();

        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit ILPStaking.PointsClaimed(bob, expectedPoints);
        staking.claimPoints();
        vm.stopPrank();

        (,,,,, uint256 claimedPoints,,) = staking.stakes(bob, 0);
        assertEq(claimedPoints, expectedPoints);
        assertEq(staking.previewClaimablePoints(bob, 0), 0);
        assertEq(ERC20(points).balanceOf(bob), expectedPoints);
    }

    // EMERGENCY WITHDRAW

    function testCanDoEmergencyWithdraw()
        external
        hasBalance(bob, amountToStake)
        hasBalance(mary, amountToStake)
        hasStaked(bob, amountToStake, threeMonths)
        hasStaked(mary, amountToStake, threeMonths)
    {
        vm.warp(block.timestamp + 60 days);

        uint256 lpInGauge = IGauge(gauge).balanceOf(address(staking));
        uint256 rewardsInGauge = IGauge(gauge).earned(address(staking));

        uint256 lpInContract = ERC20(lpToken).balanceOf(address(staking));
        uint256 rewardsInContract = ERC20(rewardsToken).balanceOf(address(staking));

        uint256 ownerInitialLP = ERC20(lpToken).balanceOf(owner);
        uint256 ownerInitialRewards = ERC20(rewardsToken).balanceOf(owner);

        vm.startPrank(owner);
        staking.emergencyWithdraw();
        vm.stopPrank();

        uint256 ownerEndLPBalance = ERC20(lpToken).balanceOf(owner);
        uint256 ownerEndRewards = ERC20(rewardsToken).balanceOf(owner);

        assertEq(IGauge(gauge).earned(address(staking)), 0);
        assertEq(IGauge(gauge).balanceOf(address(staking)), 0);

        assertEq(ownerEndLPBalance, ownerInitialLP + lpInGauge + lpInContract);
        assertEq(ownerEndRewards, ownerInitialRewards + rewardsInGauge + rewardsInContract);

        assertTrue(staking.paused());
    }

    // UPDATE SENSTIVE DATA

    function testRevertUpdateMultipliersWhenValuesAreLowerThanCurrent() public {
        vm.startPrank(owner);

        vm.expectRevert(abi.encodeWithSelector(ILPStaking.ILPStaking__Error.selector, "Invalid multiplier"));
        staking.updateMultipliers(0.4 ether, 2 ether, 4 ether, 6 ether);
        vm.stopPrank();
    }

    function testCanUpdateMultipliers() public {
        vm.startPrank(owner);

        // 1e18, 3e18, 5e18, 7e18
        vm.expectEmit(true, true, true, true);
        emit ILPStaking.MultipliersUpdated(2 ether, 4 ether, 6 ether, 8 ether);
        staking.updateMultipliers(2 ether, 4 ether, 6 ether, 8 ether);
        vm.stopPrank();
    }
}
