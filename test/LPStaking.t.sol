// // SPDX-License-Identifier: UNLINCENSED
// pragma solidity ^0.8.24;

// import {Test} from "forge-std/Test.sol";
// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
// import {console} from "forge-std/console.sol";
// import {LPStaking} from "../src/LPStaking.sol";
// import {DeployLPStaking} from "../script/DeployLPStaking.s.sol";
// import {ILPStaking} from "../src/interfaces/ILPStaking.sol";
// import {IGauge} from "../src/interfaces/IGauge.sol";
// import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";

// contract LPStakingTest is Test {
//     uint256 fork;
//     string public RPC_URL;

//     DeployLPStaking deployer;
//     LPStaking staking;
//     address lpToken;
//     address rewardsToken;
//     address gauge;

//     address owner;
//     address bob;
//     address mary;

//     uint256 period = 60 days;
//     uint256 minPerWallet;

//     function setUp() public virtual {
//         RPC_URL = vm.envString("BASE_RPC_URL");
//         fork = vm.createFork(RPC_URL);
//         vm.selectFork(fork);

//         deployer = new DeployLPStaking();
//         bool isFork = true;
//         (staking, lpToken, rewardsToken, gauge) = deployer.run(isFork);
//         owner = staking.owner();
//         bob = vm.addr(1);
//         vm.label(bob, "bob");

//         mary = vm.addr(2);
//         vm.label(mary, "mary");

//         minPerWallet = staking.minPerWallet();
//     }

//     // CONSTRUCTOR

//     function testConstructor() public {
//         assertEq(staking.owner(), owner);
//         assertEq(staking.lpToken(), lpToken);
//         assertEq(staking.rewardsToken(), rewardsToken);
//         assertEq(staking.gauge(), gauge);

//         assertTrue(staking.paused());
//     }

//     // GET FEES

//     function testGetFees() external {
//         vm.startPrank(bob);
//         uint256 amount = 400e18;
//         uint256 currentFee = staking.withdrawEarlierFee().intoUint256();

//         uint256 result = staking.getFees(amount);

//         assertEq(result, amount * currentFee / 1e18);
//         vm.stopPrank();
//     }

//     // INIT

//     modifier initialized(uint256 duration) {
//         vm.startPrank(owner);
//         staking.init(duration);
//         vm.stopPrank();
//         _;
//     }

//     function testCanInit() external initialized(period) {
//         assertEq(staking.periodFinish(), block.timestamp + period);
//         assertFalse(staking.paused());
//     }

//     function testRevertWhenAlreadyInitialized() external initialized(period) {
//         vm.startPrank(owner);
//         vm.expectRevert(Pausable.ExpectedPause.selector);
//         staking.init(period);
//         vm.stopPrank();
//     }

//     modifier hasBalance(address wallet, uint256 amount) {
//         deal(lpToken, wallet, amount);
//         _;
//     }

//     // STAKING

//     function testRevertStakeWhenPeriodFinished() external initialized(period) {
//         vm.warp(staking.periodFinish() + 1 minutes);

//         vm.startPrank(bob);
//         vm.expectRevert(ILPStaking.Staking_Period_Ended.selector);
//         staking.stake(bob, 1 ether);
//         vm.stopPrank();
//     }

//     function testRevertWhenAmountIsZero() external initialized(period) {
//         vm.startPrank(bob);
//         vm.expectRevert(ILPStaking.Staking_Insufficient_Amount.selector);
//         staking.stake(bob, 0);
//         vm.stopPrank();
//     }

//     function testRevertWhenAmountExceedsMaxAmounToStake()
//         external
//         initialized(period)
//         hasBalance(bob, staking.MAX_ALLOWED_TO_STAKE() + minPerWallet)
//     {
//         uint256 amount = staking.MAX_ALLOWED_TO_STAKE() + minPerWallet;

//         vm.startPrank(bob);
//         vm.expectRevert(ILPStaking.Staking_Max_Limit_Reached.selector);
//         staking.stake(bob, amount);
//         vm.stopPrank();
//     }

//     function testCanStake() external initialized(period) hasBalance(bob, minPerWallet) {
//         vm.startPrank(bob);
//         ERC20(lpToken).approve(address(staking), minPerWallet);
//         vm.expectEmit(true, true, true, true);
//         emit ILPStaking.Staked(bob, minPerWallet);
//         staking.stake(bob, minPerWallet);
//         vm.stopPrank();

//         (uint256 lockedAmount, uint256 lastUpdate, uint256 rewardsClaimed, uint256 rewardsEarned) =
//             staking.stakings(bob);

//         assertEq(lockedAmount, minPerWallet);
//         assertEq(lastUpdate, block.timestamp);
//         assertEq(rewardsClaimed, 0);
//         assertEq(rewardsEarned, 0);
//         assertEq(IGauge(gauge).balanceOf(address(staking)), lockedAmount);
//         assertEq(staking.totalStaked(), lockedAmount);
//     }

//     modifier hasStaked(address wallet, uint256 amount) {
//         vm.startPrank(wallet);
//         ERC20(lpToken).approve(address(staking), amount);
//         staking.stake(wallet, amount);
//         vm.stopPrank();
//         _;
//     }

//     // WITHDRAW

//     function testRevertWithdrawIfAmountIsZero()
//         external
//         initialized(period)
//         hasBalance(bob, minPerWallet)
//         hasStaked(bob, minPerWallet)
//     {
//         vm.startPrank(bob);
//         vm.expectRevert(ILPStaking.Staking_Insufficient_Amount.selector);
//         staking.withdraw(bob, 0);
//         vm.stopPrank();
//     }

//     function testRevertWhenHasNoBalanceStaked() external initialized(period) {
//         vm.startPrank(bob);
//         vm.expectRevert(ILPStaking.Staking_No_Balance_Staked.selector);
//         staking.withdraw(bob, minPerWallet);
//         vm.stopPrank();
//     }

//     function testRevertWithdrawIfAmountIsGreaterThanStakedBalance()
//         external
//         initialized(period)
//         hasBalance(bob, minPerWallet)
//         hasStaked(bob, minPerWallet)
//     {
//         vm.startPrank(bob);
//         vm.expectRevert(ILPStaking.Staking_Amount_Exceeds_Balance.selector);
//         staking.withdraw(bob, minPerWallet * 2);
//         vm.stopPrank();
//     }

//     function testCanWithdrawStakedBalance()
//         external
//         initialized(period)
//         hasBalance(bob, minPerWallet)
//         hasStaked(bob, minPerWallet)
//     {
//         (, uint256 lastUpdate,,) = staking.stakings(bob);
//         vm.warp(lastUpdate + staking.withdrawEarlierFeeLockTime());

//         uint256 initialWalletBalance = ERC20(lpToken).balanceOf(bob);

//         vm.startPrank(bob);
//         vm.expectEmit(true, true, true, true);
//         emit ILPStaking.StakeWithdrawn(bob, minPerWallet);
//         staking.withdraw(bob, minPerWallet);
//         vm.stopPrank();

//         (uint256 lockedAmount,,, uint256 rewardsEarned) = staking.stakings(bob);
//         uint256 endWalletBalance = ERC20(lpToken).balanceOf(bob);

//         assertEq(initialWalletBalance + minPerWallet, endWalletBalance);
//         assertEq(lockedAmount, 0);
//         assertTrue(rewardsEarned > 0);
//     }

//     function testPayTaxToWithdrawEarlier()
//         external
//         initialized(period)
//         hasBalance(bob, minPerWallet)
//         hasStaked(bob, minPerWallet)
//     {
//         uint256 initialWalletBalance = ERC20(lpToken).balanceOf(bob);
//         (uint256 lockedAmount,,,) = staking.stakings(bob);

//         uint256 tax = staking.getFees(lockedAmount);

//         vm.startPrank(bob);
//         vm.expectEmit(true, true, true, false);
//         emit ILPStaking.StakeWithdrawn(bob, minPerWallet - tax);
//         staking.withdraw(bob, minPerWallet);
//         vm.stopPrank();

//         uint256 endWalletBalance = ERC20(lpToken).balanceOf(bob);

//         assertEq(initialWalletBalance + minPerWallet - tax, endWalletBalance);
//     }

//     function testCanWithdrawAfterPeriodFinish()
//         external
//         initialized(period)
//         hasBalance(bob, minPerWallet)
//         hasStaked(bob, minPerWallet)
//     {
//         vm.warp(staking.periodFinish() + 3 days);

//         uint256 initialWalletBalance = ERC20(lpToken).balanceOf(bob);

//         vm.startPrank(bob);
//         vm.expectEmit(true, true, true, true);
//         emit ILPStaking.StakeWithdrawn(bob, minPerWallet);
//         staking.withdraw(bob, minPerWallet);
//         vm.stopPrank();

//         (uint256 lockedAmount,,, uint256 rewardsEarned) = staking.stakings(bob);
//         uint256 endWalletBalance = ERC20(lpToken).balanceOf(bob);

//         assertEq(initialWalletBalance + minPerWallet, endWalletBalance);
//         assertEq(lockedAmount, 0);
//         assertTrue(rewardsEarned > 0);
//     }

//     function testCanWithdrawAfterEmergencyWithdraw()
//         external
//         initialized(period)
//         hasBalance(bob, minPerWallet)
//         hasStaked(bob, minPerWallet)
//     {
//         uint256 initialWalletBalance = ERC20(lpToken).balanceOf(bob);

//         vm.warp(block.timestamp + 2 days); // to increase rewards
//         uint256 initialRewards = staking.calculateRewards(bob);

//         vm.startPrank(owner);
//         staking.emergencyWithdraw();
//         vm.stopPrank();

//         vm.warp(block.timestamp + 10 weeks);

//         vm.startPrank(bob);
//         vm.expectEmit(true, true, true, true);
//         emit ILPStaking.StakeWithdrawn(bob, minPerWallet);
//         staking.withdraw(bob, minPerWallet);
//         vm.stopPrank();

//         (uint256 endLockedAmount,,,) = staking.stakings(bob);
//         uint256 endWalletBalance = ERC20(lpToken).balanceOf(bob);
//         uint256 endRewards = staking.calculateRewards(bob);

//         assertEq(initialWalletBalance + minPerWallet, endWalletBalance);
//         assertEq(endLockedAmount, 0);
//         assertEq(initialRewards, endRewards);
//         assertTrue(endRewards > 0);
//     }

//     modifier withdrawn(address wallet, uint256 amount, uint256 timestamp) {
//         if (timestamp > 0) vm.warp(block.timestamp + timestamp);

//         vm.startPrank(wallet);
//         staking.withdraw(wallet, amount);
//         vm.stopPrank();
//         _;
//     }

//     // CALCULATE REWARDS

//     function testCanCheckRewards()
//         external
//         initialized(period)
//         hasBalance(bob, minPerWallet)
//         hasBalance(mary, minPerWallet)
//         hasStaked(bob, minPerWallet)
//         hasStaked(mary, minPerWallet)
//     {
//         uint256 bobRewards1 = staking.calculateRewards(bob);
//         uint256 maryRewards1 = staking.calculateRewards(mary);

//         assertEq(bobRewards1, 0);
//         assertEq(maryRewards1, 0);

//         vm.warp(block.timestamp + 10 days);

//         uint256 bobRewards2 = staking.calculateRewards(bob);
//         uint256 maryRewards2 = staking.calculateRewards(mary);

//         assertTrue(bobRewards2 > bobRewards1);
//         assertTrue(maryRewards2 > maryRewards1);

//         vm.warp(block.timestamp + 10 days);

//         uint256 bobRewards3 = staking.calculateRewards(bob);
//         uint256 maryRewards3 = staking.calculateRewards(mary);

//         assertTrue(bobRewards3 > bobRewards2);
//         assertTrue(maryRewards3 > maryRewards2);
//     }

//     // CLAIM REWARDS

//     function testRevertClaimStakeWhenTotalRewardsIsZero() external initialized(period) {
//         vm.startPrank(bob);
//         vm.expectRevert(ILPStaking.Staking_No_Rewards_Available.selector);
//         staking.claimRewards(bob);
//         vm.stopPrank();
//     }

//     function testRevertClaimStakeWhenWalletRewardsAreZero()
//         external
//         initialized(period)
//         hasBalance(bob, minPerWallet)
//         hasStaked(bob, minPerWallet)
//     {
//         vm.warp(block.timestamp + 2 days);

//         vm.startPrank(bob);
//         vm.expectRevert(ILPStaking.Staking_No_Rewards_Available.selector);
//         staking.claimRewards(mary);
//         vm.stopPrank();
//     }

//     function testCanClaimRewards()
//         external
//         initialized(period)
//         hasBalance(bob, minPerWallet)
//         hasStaked(bob, minPerWallet)
//     {
//         vm.warp(block.timestamp + 10 days);
//         uint256 initialRewardsBalance = ERC20(rewardsToken).balanceOf(bob);
//         uint256 initialRewards = staking.calculateRewards(bob);

//         vm.startPrank(bob);
//         vm.expectEmit(true, true, true, true);
//         emit ILPStaking.RewardsClaimed(block.timestamp, bob, initialRewards);
//         staking.claimRewards(bob);
//         vm.stopPrank();

//         uint256 zeroRewards = staking.calculateRewards(bob);
//         uint256 endRewardsBalance = ERC20(rewardsToken).balanceOf(bob);

//         assertEq(zeroRewards, 0);
//         assertEq(endRewardsBalance, initialRewardsBalance + initialRewards);
//     }

//     // CLAIM FEES

//     function testCanClaimFees()
//         external
//         initialized(period)
//         hasBalance(bob, minPerWallet)
//         hasBalance(mary, minPerWallet)
//         hasStaked(bob, minPerWallet)
//         hasStaked(mary, minPerWallet)
//         withdrawn(bob, minPerWallet, 0)
//         withdrawn(mary, minPerWallet, 0)
//     {
//         uint256 feesToClaim = staking.getFees(minPerWallet) * 2;
//         uint256 currentFeesAvailable = staking.collectedFees();

//         assertEq(feesToClaim, currentFeesAvailable);

//         uint256 ownerBalance = ERC20(lpToken).balanceOf(owner);

//         vm.startPrank(owner);
//         vm.expectEmit(true, true, true, true);
//         emit ILPStaking.FeesWithdrawn(feesToClaim);
//         staking.collectFees();
//         vm.stopPrank();

//         uint256 endOwnerBalance = ERC20(lpToken).balanceOf(owner);

//         assertEq(staking.collectedFees(), 0);
//         assertEq(endOwnerBalance, ownerBalance + feesToClaim);
//     }

//     // EMERGENCY WITHDRAW

//     function testCanDoEmergencyWithdraw()
//         external
//         initialized(period)
//         hasBalance(bob, minPerWallet)
//         hasBalance(mary, minPerWallet)
//         hasStaked(bob, minPerWallet)
//         hasStaked(mary, minPerWallet)
//     {
//         uint256 feesToClaim = staking.getFees(minPerWallet) * 2;

//         vm.startPrank(owner);
//         vm.expectEmit(true, true, true, false);
//         emit ILPStaking.EmergencyWithdrawnFunds(feesToClaim);
//         staking.emergencyWithdraw();
//         vm.stopPrank();

//         assertEq(staking.collectedFees(), 0);
//         assertEq(staking.periodFinish(), block.timestamp);
//         assertTrue(staking.paused());
//     }

//     // UPDATE SENSTIVE DATA

//     function testUpdateWithdrawEarlierFeeLockTime() external initialized(period) {
//         vm.startPrank(owner);
//         uint256 newLockTime = staking.withdrawEarlierFeeLockTime() * 2;
//         staking.updateWithdrawEarlierFeeLockTime(newLockTime);
//         vm.stopPrank();

//         assertEq(staking.withdrawEarlierFeeLockTime(), newLockTime);
//     }

//     function testUpdateWithdrawEarlierFee() external initialized(period) {
//         vm.startPrank(owner);
//         uint256 newFee = staking.withdrawEarlierFee().intoUint256() * 2;
//         staking.updateWithdrawEarlierFee(newFee);
//         vm.stopPrank();

//         assertEq(staking.withdrawEarlierFee().intoUint256(), newFee);
//     }

//     function testRevertUpdateMinPerWalletWhenZero() external initialized(period) {
//         vm.startPrank(owner);
//         vm.expectRevert(ILPStaking.Staking_Insufficient_Amount.selector);
//         staking.updateMinPerWallet(0);
//         vm.stopPrank();
//     }

//     function testUpdateMinPerWallet() external initialized(period) {
//         vm.startPrank(owner);
//         uint256 newMinPerWallet = staking.minPerWallet() * 2;
//         staking.updateMinPerWallet(newMinPerWallet);
//         vm.stopPrank();

//         assertEq(staking.minPerWallet(), newMinPerWallet);
//     }
// }
