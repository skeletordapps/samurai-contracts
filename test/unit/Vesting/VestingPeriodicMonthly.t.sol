// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Vesting} from "../../../src/Vesting.sol";
import {DeployVesting} from "../../../script/DeployVesting.s.sol";
import {ERC20Mock} from "../../../src/mocks/ERC20Mock.sol";
import {IVesting} from "../../../src/interfaces/IVesting.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";
import {BokkyPooBahsDateTimeLibrary} from "@BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";
import {console} from "forge-std/console.sol";

contract VestingPeriodicMonthlyTest is Test {
    uint256 fork;
    string public RPC_URL;

    DeployVesting deployer;
    Vesting vesting;

    address owner;
    address bob;
    address mary;
    address paul;

    uint256 totalPurchased;
    uint256 tgeReleasePercent;
    uint256 vestingDuration;
    uint256 vestingAt;
    uint256 cliff;

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployVesting();
        vesting = deployer.runForPeriodicTests(IVesting.PeriodType.Months, 3);
        owner = vesting.owner();

        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");

        paul = vm.addr(3);
        vm.label(paul, "paul");

        totalPurchased = vesting.totalPurchased();
        tgeReleasePercent = vesting.tgeReleasePercent();
        (vestingDuration, vestingAt, cliff) = vesting.periods();
    }

    function testPeriodicMonthly_Constructor() public view {
        assertEq(vesting.owner(), owner);
        assertEq(totalPurchased, 1_000_000 ether);
        assertEq(tgeReleasePercent, 0.15e18);
        assertEq(vestingDuration, 3);
        assertEq(vestingAt, block.timestamp + 1 days);
        assertEq(cliff, 2);
        assertEq(vesting.purchases(bob), 500_000 ether);
        assertEq(vesting.purchases(mary), 500_000 ether);
    }

    modifier idoTokenFilled(bool sendHalf) {
        vm.warp(block.timestamp + 30 minutes);
        address idoToken = vesting.token();
        uint256 expectedAmountOfTokens = 1_000_000 ether;

        if (sendHalf) expectedAmountOfTokens = expectedAmountOfTokens / 2;

        deal(idoToken, owner, expectedAmountOfTokens);

        vm.startPrank(owner);
        ERC20(idoToken).approve(address(vesting), expectedAmountOfTokens);
        vesting.fillIDOToken(expectedAmountOfTokens);
        vm.stopPrank();
        _;
    }

    /// TGE CALCULATION

    function testPeriodicMonthly_CanCheckTGEBalance() external idoTokenFilled(false) {
        vm.warp(vestingAt + 1 minutes);
        uint256 expectedTGEamount = 75_000 ether;
        uint256 userAmountInTGE = vesting.previewTGETokens(bob);

        assertEq(userAmountInTGE, expectedTGEamount);
    }

    /// CALCULATE RELESEAD TOKENS

    function testPeriodicMonthly_MustReturnZeroWhenWalletHasNoAllocation() external {
        vm.warp(vestingAt);

        uint256 amount = vesting.previewClaimableTokens(paul);
        assertEq(amount, 0);
    }

    function testPeriodicMonthly_MustReturnTGEBalanceWhenCliffPeriodIsOngoing() external idoTokenFilled(false) {
        vm.warp(vestingAt + 1 days);

        uint256 expectedTGEAmount = 75_000 ether;

        uint256 amount = vesting.previewClaimableTokens(bob);
        assertEq(amount, expectedTGEAmount);
    }

    /// CLAIM TGE

    function testPeriodicMonthly_CanClaimTGE() external idoTokenFilled(false) {
        vm.warp(vestingAt + 1 days);

        address idoToken = vesting.token();

        uint256 expectedTGEAmount = 75_000 ether;
        uint256 walletBalance = ERC20(idoToken).balanceOf(bob);

        vm.startPrank(bob);
        vesting.claim();
        vm.stopPrank();

        uint256 walletBalanceAfter = ERC20(idoToken).balanceOf(bob);

        assertEq(walletBalanceAfter, walletBalance + expectedTGEAmount);
    }

    modifier tgeClaimed(address wallet) {
        vm.warp(vestingAt + 1 days);
        vm.startPrank(wallet);
        vesting.claim();
        vm.stopPrank();
        _;
    }

    function testPeriodicMonthly_CanClaimTGEPlusOneMonthAmountUnlocked() external idoTokenFilled(false) {
        uint256 cliffEndsAt = vesting.cliffEndsAt();

        uint256 expectedTGEAmount = 75_000 ether;

        vm.warp(cliffEndsAt - 1 hours);
        uint256 claimable = vesting.previewClaimableTokens(bob);
        assertEq(claimable, expectedTGEAmount);

        vm.warp(BokkyPooBahsDateTimeLibrary.addMonths(cliffEndsAt, 1));
        claimable = vesting.previewClaimableTokens(bob);
        assertTrue(claimable > expectedTGEAmount);

        assertEq(claimable, 216666666666666666666666);

        uint256 walletBalance = ERC20(vesting.token()).balanceOf(bob);

        vm.startPrank(bob);
        vesting.claim();
        vm.stopPrank();

        uint256 walletBalanceAfter = ERC20(vesting.token()).balanceOf(bob);
        assertEq(walletBalanceAfter, walletBalance + claimable);
    }

    function testPeriodicMonthly_CanClaimTGEAnd2MonthsLater() external idoTokenFilled(false) {
        uint256 cliffEndsAt = vesting.cliffEndsAt();

        uint256 expectedTGEAmount = 75_000 ether;

        vm.warp(cliffEndsAt - 1 hours);
        uint256 claimable = vesting.previewClaimableTokens(bob);
        assertEq(claimable, expectedTGEAmount);

        uint256 walletBalance1 = ERC20(vesting.token()).balanceOf(bob);

        vm.startPrank(bob);
        vesting.claim();
        vm.stopPrank();

        claimable = vesting.previewClaimableTokens(bob);
        assertEq(claimable, 0);

        uint256 walletBalance2 = ERC20(vesting.token()).balanceOf(bob);
        assertEq(walletBalance2, walletBalance1 + expectedTGEAmount);

        vm.warp(BokkyPooBahsDateTimeLibrary.addMonths(cliffEndsAt, 2));
        claimable = vesting.previewClaimableTokens(bob);

        assertEq(claimable, 283333333333333333333333);

        vm.startPrank(bob);
        vesting.claim();
        vm.stopPrank();

        uint256 walletBalance3 = ERC20(vesting.token()).balanceOf(bob);
        assertEq(walletBalance3, walletBalance2 + claimable);
    }

    function testPeriodicMonthly_CanClaimAllPurchasedTokensFollowingPeriodicVesting() external idoTokenFilled(false) {
        uint256 cliffEndsAt = vesting.cliffEndsAt();

        uint256 purchased = vesting.purchases(bob);
        uint256 expectedTGEAmount = 75_000 ether;

        vm.warp(cliffEndsAt - 1 hours);
        uint256 claimable = vesting.previewClaimableTokens(bob);
        assertEq(claimable, expectedTGEAmount);

        vm.startPrank(bob);
        vesting.claim();
        vm.stopPrank();

        claimable = vesting.previewClaimableTokens(bob);
        assertEq(claimable, 0);

        uint256 balance = ERC20(vesting.token()).balanceOf(bob);
        assertEq(balance, expectedTGEAmount);

        vm.warp(BokkyPooBahsDateTimeLibrary.addMonths(cliffEndsAt, 1));

        vm.startPrank(bob);
        vesting.claim();
        vm.stopPrank();

        vm.warp(BokkyPooBahsDateTimeLibrary.addMonths(cliffEndsAt, 2));

        vm.startPrank(bob);
        vesting.claim();
        vm.stopPrank();

        vm.warp(BokkyPooBahsDateTimeLibrary.addMonths(cliffEndsAt, 3));

        vm.startPrank(bob);
        vesting.claim();
        vm.stopPrank();

        vm.warp(BokkyPooBahsDateTimeLibrary.addMonths(cliffEndsAt, 3) + 1 hours);

        vm.startPrank(bob);
        vesting.claim();
        vm.stopPrank();

        balance = ERC20(vesting.token()).balanceOf(bob);
        assertEq(balance, purchased);
    }
}
