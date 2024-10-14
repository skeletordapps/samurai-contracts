// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Vesting} from "../src/Vesting.sol";
import {DeployVesting} from "../script/DeployVesting.s.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {IVesting} from "../src/interfaces/IVesting.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";
import {BokkyPooBahsDateTimeLibrary} from "@BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";

contract VestingPeriodicTest is Test {
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
        vesting = deployer.runForTests(IVesting.VestingType.PeriodicVesting);
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

    function testPeriodic_Constructor() public {
        assertEq(vesting.owner(), owner);
        assertEq(totalPurchased, 1_000_000 ether);
        assertEq(tgeReleasePercent, 0.15e18);
        assertEq(vestingDuration, 3);
        assertEq(vestingAt, block.timestamp);
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

    function testPeriodic_CanCheckTGEBalance() external idoTokenFilled(false) {
        vm.warp(vestingAt + 1 minutes);
        uint256 expectedTGEamount = 75_000 ether;
        uint256 userAmountInTGE = vesting.previewTGETokens(bob);

        assertEq(userAmountInTGE, expectedTGEamount);
    }

    /// CALCULATE RELESEAD TOKENS

    function testPeriodic_MustReturnZeroWhenWalletHasNoAllocation() external {
        vm.warp(vestingAt);

        uint256 amount = vesting.previewClaimableTokens(paul);
        assertEq(amount, 0);
    }

    function testPeriodic_MustReturnTGEBalanceWhenCliffPeriodIsOngoing() external idoTokenFilled(false) {
        vm.warp(vestingAt + 1 days);

        uint256 expectedTGEAmount = 75_000 ether;

        uint256 amount = vesting.previewClaimableTokens(bob);
        assertEq(amount, expectedTGEAmount);
    }

    /// CLAIM TGE

    function testPeriodic_CanClaimTGE() external idoTokenFilled(false) {
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

    function testPeriodic_CanClaimTGEPlusOneMonthAmountUnlocked() external idoTokenFilled(false) {
        uint256 cliffEndsAt = vesting.cliffEndsAt();

        uint256 purchased = vesting.purchases(bob);
        uint256 expectedTGEAmount = 75_000 ether;

        vm.warp(cliffEndsAt - 1 hours);
        uint256 claimable = vesting.previewClaimableTokens(bob);
        assertEq(claimable, expectedTGEAmount);

        vm.warp(BokkyPooBahsDateTimeLibrary.addMonths(cliffEndsAt, 1));
        claimable = vesting.previewClaimableTokens(bob);
        assertTrue(claimable > expectedTGEAmount);

        UD60x18 total = ud(totalPurchased);
        UD60x18 vested = ud(vesting.previewVestedTokens());
        UD60x18 totalVestedPercentage = vested.mul(convert(100)).div(total);
        UD60x18 walletSharePercentage = ud(purchased).mul(convert(100)).div(total);
        UD60x18 walletVestedPercentage = walletSharePercentage.mul(totalVestedPercentage).div(convert(100));
        UD60x18 walletVested = total.mul(walletVestedPercentage).div(convert(100));
        uint256 expectedAmountAfterOneMonth = walletVested.intoUint256();

        assertEq(claimable, expectedAmountAfterOneMonth);

        uint256 walletBalance = ERC20(vesting.token()).balanceOf(bob);

        vm.startPrank(bob);
        vesting.claim();
        vm.stopPrank();

        uint256 walletBalanceAfter = ERC20(vesting.token()).balanceOf(bob);
        assertEq(walletBalanceAfter, walletBalance + claimable);
    }

    function testPeriodic_CanClaimTGEAnd2MonthsLater() external idoTokenFilled(false) {
        uint256 cliffEndsAt = vesting.cliffEndsAt();

        uint256 purchased = vesting.purchases(bob);
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

        UD60x18 total = ud(totalPurchased);
        UD60x18 vested = ud(vesting.previewVestedTokens());
        UD60x18 totalVestedPercentage = vested.mul(convert(100)).div(total);
        UD60x18 walletSharePercentage = ud(purchased).mul(convert(100)).div(total);
        UD60x18 walletVestedPercentage = walletSharePercentage.mul(totalVestedPercentage).div(convert(100));
        UD60x18 walletVested = total.mul(walletVestedPercentage).div(convert(100));
        uint256 expectedAmountAfter2Months = walletVested.sub(ud(expectedTGEAmount)).intoUint256();

        assertEq(claimable, expectedAmountAfter2Months);

        vm.startPrank(bob);
        vesting.claim();
        vm.stopPrank();

        uint256 walletBalance3 = ERC20(vesting.token()).balanceOf(bob);
        assertEq(walletBalance3, walletBalance2 + claimable);
    }

    function testPeriodic_CanClaimAllPurchasedTokensFollowingPeriodicVesting() external idoTokenFilled(false) {
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
