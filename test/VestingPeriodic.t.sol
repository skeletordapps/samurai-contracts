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
        assertEq(vestingDuration, 0);
        assertEq(vestingAt, 0);
        assertEq(cliff, 0);
    }

    function testPeriodic_CanSetAllPurchases() external {
        uint256 count = 2;
        address[] memory wallets = new address[](count);
        uint256[] memory tokensPurchased = new uint256[](count);

        wallets[0] = bob;
        wallets[1] = mary;

        uint256 amount = 500_000 ether;

        tokensPurchased[0] = amount;
        tokensPurchased[1] = amount;

        vm.startPrank(owner);
        vesting.setAllPurchases(wallets, tokensPurchased);
        vm.stopPrank();

        assertEq(vesting.purchases(bob), amount);
        assertEq(vesting.purchases(mary), amount);
    }

    modifier purchasesSet() {
        uint256 count = 2;
        address[] memory wallets = new address[](count);
        uint256[] memory tokensPurchased = new uint256[](count);

        wallets[0] = bob;
        wallets[1] = mary;

        uint256 amount = 500_000 ether;

        tokensPurchased[0] = amount;
        tokensPurchased[1] = amount;

        vm.startPrank(owner);
        vesting.setAllPurchases(wallets, tokensPurchased);
        vm.stopPrank();
        _;
    }

    /// PERIODS

    function testPeriodic_CanSetPeriods() external {
        IVesting.Periods memory expectedPeriods = IVesting.Periods({
            vestingDuration: 30 days * 8, // 8 months
            vestingAt: block.timestamp + 10 days,
            cliff: 30 days
        });

        vm.startPrank(owner);
        vesting.setPeriods(expectedPeriods);
        vm.stopPrank();

        (uint256 _newVestingDuration, uint256 _newVestingAt, uint256 _newCliff) = vesting.periods();

        assertEq(_newVestingDuration, expectedPeriods.vestingDuration);
        assertEq(_newVestingAt, expectedPeriods.vestingAt);
        assertEq(_newCliff, expectedPeriods.cliff);
    }

    modifier periodsSet(uint256 newVestingDuration, uint256 newVestingAt, uint256 cliffDuration) {
        IVesting.Periods memory expectedPeriods =
            IVesting.Periods({vestingDuration: newVestingDuration, vestingAt: newVestingAt, cliff: cliffDuration});

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IVesting.PeriodsSet(expectedPeriods);
        vesting.setPeriods(expectedPeriods);
        vm.stopPrank();

        (vestingDuration, vestingAt, cliff) = vesting.periods();

        _;
    }

    /// When vestingAt is already set
    function testPeriodic_RevertSetPeriodsWhenVestingAtIsUnderStoredVestingAt()
        external
        periodsSet(8, block.timestamp + 2 days, 0)
    {
        IVesting.Periods memory expectedPeriods =
            IVesting.Periods({vestingDuration: 8, vestingAt: block.timestamp + 1 days, cliff: cliff});

        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IVesting.IVesting__Invalid.selector,
                "New vestingAt value must be greater or equal current vestingAt value"
            )
        );
        vesting.setPeriods(expectedPeriods);
        vm.stopPrank();
    }

    function testPeriodic_RevertSetPeriodsWhenCliffIsUnderStoredCliff()
        external
        periodsSet(8, block.timestamp + 2 days, 1)
    {
        IVesting.Periods memory expectedPeriods = IVesting.Periods({vestingDuration: 8, vestingAt: vestingAt, cliff: 0});

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IVesting.IVesting__Invalid.selector, "Invalid cliff"));
        vesting.setPeriods(expectedPeriods);
        vm.stopPrank();
    }

    // SET IDO TOKEN

    function testPeriodic_CanSetIDOToken() external {
        vm.warp(block.timestamp + 2 hours);

        ERC20Mock newToken = new ERC20Mock("IDO TOKEN", "IDT");

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IVesting.IDOTokenSet(address(newToken));
        vesting.setIDOToken(address(newToken));
        vm.stopPrank();

        assertEq(vesting.token(), address(newToken));
    }

    modifier idoTokenSet() {
        ERC20Mock newToken = new ERC20Mock("IDO TOKEN", "IDT");
        vm.startPrank(owner);
        vesting.setIDOToken(address(newToken));
        vm.stopPrank();
        _;
    }

    function testPeriodic_RevertSetIDOTokenIfAlreadySet() external idoTokenSet {
        ERC20Mock newToken = new ERC20Mock("IDO TOKEN 2", "IDT2");

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IVesting.IVesting__Unauthorized.selector, "Token already set"));
        vesting.setIDOToken(address(newToken));
        vm.stopPrank();
    }

    /// IDO TOKEN FILL

    function testPeriodic_RevertFillIDOTokenWhenTokenNotSet() external {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IVesting.IVesting__Unauthorized.selector, "IDO token not set"));
        vesting.fillIDOToken(1 ether);
        vm.stopPrank();
    }

    function testPeriodic_CanSendIDOTokenToContract() external idoTokenSet {
        vm.warp(block.timestamp + 30 minutes);

        address idoToken = vesting.token();
        uint256 expectedTotalPurchased = 1_000_000 ether;

        deal(idoToken, owner, expectedTotalPurchased);

        vm.startPrank(owner);
        ERC20(idoToken).approve(address(vesting), expectedTotalPurchased);

        vm.expectEmit(true, true, true, true);
        emit IVesting.TokensFilled(owner, expectedTotalPurchased);
        vesting.fillIDOToken(expectedTotalPurchased);
        vm.stopPrank();

        assertEq(ERC20(idoToken).balanceOf(address(vesting)), expectedTotalPurchased);
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

    function testPeriodic_FillInChunks() external idoTokenSet idoTokenFilled(true) {
        vm.warp(block.timestamp + 5 hours);
        address idoToken = vesting.token();
        uint256 partialAmount = 500_000 ether;
        deal(idoToken, owner, partialAmount);

        vm.startPrank(owner);
        ERC20(idoToken).approve(address(vesting), partialAmount);
        vesting.fillIDOToken(partialAmount);
        vm.stopPrank();

        assertEq(ERC20(idoToken).balanceOf(address(vesting)), partialAmount * 2);
    }

    function testPeriodic_RevertFillIDOTokenTwice() external idoTokenSet idoTokenFilled(false) {
        address idoToken = vesting.token();
        deal(idoToken, owner, 1 ether);

        vm.startPrank(owner);
        ERC20(idoToken).approve(address(vesting), 1 ether);
        vm.expectRevert(
            abi.encodeWithSelector(IVesting.IVesting__Unauthorized.selector, "Unable to receive more IDO tokens")
        );
        vesting.fillIDOToken(1 ether);
        vm.stopPrank();
    }

    /// TGE CALCULATION

    function testPeriodic_MustReturnZeroCheckingTGEBalanceBeforeTokenIsSet() external {
        uint256 userAmountInTGE = vesting.previewTGETokens(bob);

        assertEq(userAmountInTGE, 0);
    }

    function testPeriodic_CanCheckTGEBalance()
        external
        periodsSet(3, block.timestamp + 2 days, 1)
        idoTokenSet
        idoTokenFilled(false)
        purchasesSet
    {
        vm.warp(vestingAt + 1 minutes);
        uint256 expectedTGEamount = 75_000 ether;
        uint256 userAmountInTGE = vesting.previewTGETokens(bob);

        assertEq(userAmountInTGE, expectedTGEamount);
    }

    /// CALCULATE RELESEAD TOKENS

    function testPeriodic_MustReturnZeroWhenVestingIsNotSet() external {
        uint256 amount = vesting.previewClaimableTokens(bob);
        assertEq(amount, 0);
    }

    function testPeriodic_MustReturnZeroWhenWalletHasNoAllocation()
        external
        periodsSet(8, block.timestamp + 2 days, 1)
    {
        vm.warp(vestingAt);

        uint256 amount = vesting.previewClaimableTokens(paul);
        assertEq(amount, 0);
    }

    function testPeriodic_MustReturnTGEBalanceWhenCliffPeriodIsOngoing()
        external
        periodsSet(8, block.timestamp + 2 days, 1)
        idoTokenSet
        idoTokenFilled(false)
        purchasesSet
    {
        vm.warp(vestingAt + 1 days);

        uint256 expectedTGEAmount = 75_000 ether;

        uint256 amount = vesting.previewClaimableTokens(bob);
        assertEq(amount, expectedTGEAmount);
    }

    /// CLAIM TGE

    function testPeriodic_CanClaimTGE()
        external
        periodsSet(8, block.timestamp + 2 days, 1)
        idoTokenSet
        idoTokenFilled(false)
        purchasesSet
    {
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

    function testPeriodic_CanClaimTGEPlusOneMonthAmountUnlocked()
        external
        periodsSet(3, block.timestamp + 2 days, 1)
        idoTokenSet
        idoTokenFilled(false)
        purchasesSet
    {
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

    function testPeriodic_CanClaimTGEAnd2MonthsLater()
        external
        periodsSet(3, block.timestamp + 2 days, 1)
        idoTokenSet
        idoTokenFilled(false)
        purchasesSet
    {
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

    function testPeriodic_CanClaimAllPurchasedTokensFollowingPeriodicVesting()
        external
        periodsSet(3, block.timestamp + 2 days, 1)
        idoTokenSet
        idoTokenFilled(false)
        purchasesSet
    {
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

    // EMERGENCY WITHDRAW FOR SPECIFIC WALLET

    function testPeriodic_RevertEmergencyWithdrawByWalletWhenTokenNotSet() external {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IVesting.IVesting__Unauthorized.selector, "Token not set"));
        vesting.emergencyWithdrawByWallet(bob);
        vm.stopPrank();
    }

    function testPeriodic_RevertEmergencyWithdrawByWalletWhenVesingIsOngoing()
        external
        periodsSet(8, block.timestamp + 2 days, 1)
        idoTokenSet
        idoTokenFilled(false)
        purchasesSet
    {
        (uint256 _vestingDuration, uint256 _vestingAt,) = vesting.periods();
        vm.warp(_vestingAt + _vestingDuration - 1 days);
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IVesting.IVesting__Unauthorized.selector, "Vesting is ongoing"));
        vesting.emergencyWithdrawByWallet(bob);
        vm.stopPrank();
    }

    function testPeriodic_CanEmergencyWithdrawByWallet()
        external
        periodsSet(8, block.timestamp + 2 days, 1)
        idoTokenSet
        idoTokenFilled(false)
        purchasesSet
    {
        uint256 expectedAmountToWithdraw = 500_000 ether;
        vm.warp(vesting.vestingEndsAt() + 1 hours);
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, false);
        emit IVesting.Claimed(bob, expectedAmountToWithdraw);
        vesting.emergencyWithdrawByWallet(bob);
        vm.stopPrank();
    }

    // EMERGENCY WITHDRAW

    function testPeriodic_RevertEmergencyWithdrawtWhenTokenNotSet() external {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IVesting.IVesting__Unauthorized.selector, "Token not set"));
        vesting.emergencyWithdraw();
        vm.stopPrank();
    }

    function testPeriodic_CanEmergencyWithdraw()
        external
        periodsSet(8, block.timestamp + 2 days, 1)
        idoTokenSet
        idoTokenFilled(false)
    {
        assertTrue(vesting.token() != address(0));

        uint256 expectedAmountToWithdraw = 1_000_000 ether;

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IVesting.RemainingTokensWithdrawal(expectedAmountToWithdraw);
        vesting.emergencyWithdraw();
        vm.stopPrank();
    }
}
