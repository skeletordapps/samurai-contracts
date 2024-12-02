// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {LPStaking} from "../../src/LPStaking.sol";
import {DeployLPStaking} from "../../script/DeployLPStaking.s.sol";
import {ERC20Mock} from "../../src/mocks/ERC20Mock.sol";
import {ILPStaking} from "../../src/interfaces/ILPStaking.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";
import {BokkyPooBahsDateTimeLibrary} from "@BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";
import {console} from "forge-std/console.sol";

contract FuzzLPStakingTest is Test {
    uint256 fork;
    string public RPC_URL;

    DeployLPStaking deployer;
    LPStaking staking;
    ERC20 public token;
    ERC20 public rewards;

    address owner;
    address bob;

    uint256 totalStaked;

    uint256 threeMonths = 90 days;
    uint256 amountToStake = 10 ether;

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployLPStaking();
        (LPStaking lpStaking, address lpToken, address rewardsToken,,) = deployer.runForTests();
        staking = lpStaking;
        token = ERC20(lpToken);
        rewards = ERC20(rewardsToken);

        owner = staking.owner();
        bob = vm.addr(1);
        vm.label(bob, "bob");

        totalStaked = staking.totalStaked();
    }

    modifier hasBalance(address wallet, uint256 amount) {
        deal(address(token), wallet, amount);
        _;
    }

    modifier hasStaked(address wallet, uint256 amount, uint256 stakePeriod) {
        vm.startPrank(wallet);
        token.approve(address(staking), amount);
        staking.stake(amount, stakePeriod);
        vm.stopPrank();
        _;
    }

    function testFuzzStake(uint256 amount, uint256 timeElapsed) public hasBalance(bob, amount) {
        vm.assume(amount > 0 && amount < 1_000_000_000 ether);
        timeElapsed = bound(timeElapsed, 30 days, 365 days);
        vm.warp(block.timestamp + timeElapsed);

        vm.startPrank(bob);
        token.approve(address(staking), amount);
        staking.stake(amount, threeMonths);
        vm.stopPrank();

        (uint256 stakedAmount,, uint256 stakedAt, uint256 withdrawTime, uint256 stakePeriod,,,) = staking.stakes(bob, 0);

        assertEq(stakedAmount, amount);
        assertEq(stakedAt, block.timestamp);
        assertEq(withdrawTime, block.timestamp + threeMonths);
        assertEq(stakedAt, block.timestamp);
        assertEq(stakePeriod, threeMonths);
    }

    function testFuzzClaim(uint256 timeElapsed)
        public
        hasBalance(bob, amountToStake)
        hasStaked(bob, amountToStake, threeMonths)
    {
        timeElapsed = bound(timeElapsed, 30 days, 365 days);
        vm.warp(block.timestamp + timeElapsed);

        uint256 previewAmount = staking.previewRewards(bob);

        vm.startPrank(bob);
        staking.claimRewards();
        vm.stopPrank();

        assertEq(rewards.balanceOf(bob), previewAmount);
    }

    function testFuzzWithdraw(uint256 timeElapsed, uint256 amount) public hasBalance(bob, amountToStake) {
        vm.assume(timeElapsed > threeMonths);

        vm.startPrank(bob);
        token.approve(address(staking), amountToStake);
        staking.stake(amountToStake, threeMonths);
        vm.stopPrank();

        timeElapsed = bound(timeElapsed, threeMonths, 365 days);
        amount = bound(amount, 0.1 ether, amountToStake);
        vm.warp(block.timestamp + timeElapsed);

        vm.startPrank(bob);
        staking.withdraw(amount, 0);
        vm.stopPrank();

        (, uint256 withdrawnAmount,,,,,,) = staking.stakes(bob, 0);

        assertEq(withdrawnAmount, amount);
        assertEq(token.balanceOf(bob), amount);
    }
}
