// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/console.sol";
import {Vesting} from "../src/Vesting.sol";
import {DeployVesting} from "../script/DeployVesting.s.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {IVesting} from "../src/interfaces/IVesting.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";
import {BokkyPooBahsDateTimeLibrary} from "@BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";

contract VestingLinearTest is Test {
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
        vesting = deployer.runForTests(IVesting.VestingType.LinearVesting);
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

    function testConstructor() public {
        assertEq(vesting.owner(), owner);
        assertEq(totalPurchased, 1_000_000 ether);
        assertEq(tgeReleasePercent, 0.15e18);
        assertEq(vestingDuration, 0);
        assertEq(vestingAt, 0);
        assertEq(cliff, 0);
    }

    function testRevertSetAllPurchasesWithInvalidAddress() external {
        uint256 count = 2;
        address[] memory wallets = new address[](count);
        uint256[] memory tokensPurchased = new uint256[](count);

        wallets[0] = address(0);
        wallets[1] = mary;

        uint256 amount = totalPurchased / 2;

        tokensPurchased[0] = amount;
        tokensPurchased[1] = amount;

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IVesting.IVesting__Invalid.selector, "Invalid address"));
        vesting.setAllPurchases(wallets, tokensPurchased);
        vm.stopPrank();
    }

    function testRevertSetAllPurchasesWithInvalidAmountPermitted() external {
        uint256 count = 2;
        address[] memory wallets = new address[](count);
        uint256[] memory tokensPurchased = new uint256[](count);

        wallets[0] = bob;
        wallets[1] = mary;

        uint256 amount = totalPurchased / 2;

        tokensPurchased[0] = amount;
        tokensPurchased[1] = 0;

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IVesting.IVesting__Invalid.selector, "Invalid amount permitted"));
        vesting.setAllPurchases(wallets, tokensPurchased);
        vm.stopPrank();
    }

    function testCanSetAllPurchases() external {
        uint256 count = 2;
        address[] memory wallets = new address[](count);
        uint256[] memory tokensPurchased = new uint256[](count);

        wallets[0] = bob;
        wallets[1] = mary;

        uint256 amount = totalPurchased / 2;

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

        uint256 amount = totalPurchased / 2;

        tokensPurchased[0] = amount;
        tokensPurchased[1] = amount;

        vm.startPrank(owner);
        vesting.setAllPurchases(wallets, tokensPurchased);
        vm.stopPrank();
        _;
    }

    /// PERIODS

    function testCanSetPeriods() external {
        IVesting.Periods memory expectedPeriods =
            IVesting.Periods({vestingDuration: 8, vestingAt: block.timestamp + 10 days, cliff: 1});

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
    function testRevertSetPeriodsWhenVestingAtIsUnderStoredVestingAt()
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

    function testRevertSetPeriodsWhenCliffIsUnderStoredCliff() external periodsSet(8, block.timestamp + 2 days, 1) {
        IVesting.Periods memory expectedPeriods =
            IVesting.Periods({vestingDuration: vestingDuration, vestingAt: vestingAt, cliff: 0});

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IVesting.IVesting__Invalid.selector, "Invalid cliff"));
        vesting.setPeriods(expectedPeriods);
        vm.stopPrank();
    }

    // SET IDO TOKEN

    function testCanSetIDOToken() external {
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

    function testRevertSetIDOTokenIfAlreadySet() external idoTokenSet {
        ERC20Mock newToken = new ERC20Mock("IDO TOKEN 2", "IDT2");

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IVesting.IVesting__Unauthorized.selector, "Token already set"));
        vesting.setIDOToken(address(newToken));
        vm.stopPrank();
    }

    /// IDO TOKEN FILL

    function testRevertFillIDOTokenWhenTokenNotSet() external {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IVesting.IVesting__Unauthorized.selector, "IDO token not set"));
        vesting.fillIDOToken(1 ether);
        vm.stopPrank();
    }

    function testCanSendIDOTokenToContract() external idoTokenSet {
        vm.warp(block.timestamp + 30 minutes);

        address idoToken = vesting.token();

        deal(idoToken, owner, totalPurchased);

        vm.startPrank(owner);
        ERC20(idoToken).approve(address(vesting), totalPurchased);

        vm.expectEmit(true, true, true, true);
        emit IVesting.TokensFilled(owner, totalPurchased);
        vesting.fillIDOToken(totalPurchased);
        vm.stopPrank();

        assertEq(ERC20(idoToken).balanceOf(address(vesting)), totalPurchased);
    }

    modifier idoTokenFilled(bool sendHalf) {
        vm.warp(block.timestamp + 30 minutes);
        address idoToken = vesting.token();
        uint256 expectedAmountOfTokens = totalPurchased;

        if (sendHalf) expectedAmountOfTokens = expectedAmountOfTokens / 2;

        deal(idoToken, owner, expectedAmountOfTokens);

        vm.startPrank(owner);
        ERC20(idoToken).approve(address(vesting), expectedAmountOfTokens);
        vesting.fillIDOToken(expectedAmountOfTokens);
        vm.stopPrank();
        _;
    }

    function testFillInChunks() external idoTokenSet idoTokenFilled(true) {
        vm.warp(block.timestamp + 5 hours);
        address idoToken = vesting.token();
        uint256 partialAmount = ERC20(idoToken).balanceOf(address(vesting));
        deal(idoToken, owner, partialAmount);

        vm.startPrank(owner);
        ERC20(idoToken).approve(address(vesting), partialAmount);
        vesting.fillIDOToken(partialAmount);
        vm.stopPrank();

        assertEq(ERC20(idoToken).balanceOf(address(vesting)), partialAmount * 2);
    }

    function testRevertFillIDOTokenTwice() external idoTokenSet idoTokenFilled(false) {
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

    function testMustReturnZeroCheckingTGEBalanceBeforeTokenIsSet() external {
        uint256 userAmountInTGE = vesting.previewTGETokens(bob);

        assertEq(userAmountInTGE, 0);
    }

    function testCanCheckTGEBalance() external idoTokenSet {
        uint256 userAmountInTGE = vesting.previewTGETokens(bob);

        // (uint256 _price,, uint256 _tgePercentage) = vesting.amounts();
        uint256 userPurchase = vesting.purchases(bob);

        UD60x18 expectedTGEamount = convert(userPurchase).mul(ud(vesting.tgeReleasePercent()));

        assertEq(userAmountInTGE, expectedTGEamount.intoUint256());
    }

    /// CALCULATE RELESEAD TOKENS

    function testMustReturnZeroWhenVestingIsNotSet() external {
        uint256 amount = vesting.previewClaimableTokens(bob);
        assertEq(amount, 0);
    }

    function testMustReturnZeroWhenWalletHasNoAllocation() external periodsSet(8, block.timestamp + 2 days, 1) {
        vm.warp(vestingAt);

        uint256 amount = vesting.previewClaimableTokens(paul);
        assertEq(amount, 0);
    }

    function testMustReturnTGEBalanceWhenCliffPeriodIsOngoing()
        external
        periodsSet(8, block.timestamp + 2 days, 1)
        idoTokenSet
    {
        vm.warp(vestingAt + 1 days);

        uint256 expectedTGEAmount = vesting.previewTGETokens(bob);

        uint256 amount = vesting.previewClaimableTokens(bob);
        assertEq(amount, expectedTGEAmount);
    }

    /// CLAIM TGE

    function testCanClaimTGE()
        external
        periodsSet(8, block.timestamp + 2 days, 1)
        idoTokenSet
        idoTokenFilled(false)
        purchasesSet
    {
        vm.warp(vestingAt + 1 days);

        address idoToken = vesting.token();

        uint256 expectedTGEAmount = vesting.previewTGETokens(bob);
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

    function testCanClaimTGEPlusLinearVestedInPeriod()
        external
        periodsSet(8, block.timestamp + 2 days, 1)
        idoTokenSet
        idoTokenFilled(false)
        purchasesSet
    {
        vm.warp(vestingAt + 1 days);

        uint256 expectedTGEAmount = vesting.previewTGETokens(bob);
        uint256 walletBalance = ERC20(vesting.token()).balanceOf(bob);

        vm.warp(vesting.cliffEndsAt() + 100 days);

        uint256 expectedVestedTokens = vesting.previewClaimableTokens(bob);
        assertTrue(expectedVestedTokens > expectedTGEAmount);

        vm.startPrank(bob);
        vesting.claim();
        vm.stopPrank();

        uint256 walletBalanceAfter = ERC20(vesting.token()).balanceOf(bob);
        assertEq(walletBalanceAfter, walletBalance + expectedVestedTokens);
    }

    function testCanClaimVestedTokensAfterTGEClaim()
        external
        periodsSet(8, block.timestamp + 2 days, 1)
        idoTokenSet
        idoTokenFilled(false)
        purchasesSet
    {
        vm.warp(vestingAt);

        uint256 expectedTGEAmount = vesting.previewTGETokens(bob);
        uint256 walletBalance = ERC20(vesting.token()).balanceOf(bob);
        uint256 expectedVestedTokens = vesting.previewClaimableTokens(bob);
        assertEq(expectedVestedTokens, expectedTGEAmount);

        vm.startPrank(bob);
        vesting.claim();
        vm.stopPrank();

        uint256 walletBalanceAfterTGEClaim = ERC20(vesting.token()).balanceOf(bob);
        assertEq(walletBalanceAfterTGEClaim, walletBalance + expectedTGEAmount);

        vm.warp(vesting.vestingEndsAt() + 10 days);
        uint256 expectedVestedTokensAfterTGE = vesting.previewClaimableTokens(bob);

        vm.startPrank(bob);
        vesting.claim();
        vm.stopPrank();

        uint256 walletBalanceAfter = ERC20(vesting.token()).balanceOf(bob);
        assertEq(walletBalanceAfter, walletBalanceAfterTGEClaim + expectedVestedTokensAfterTGE);

        uint256 tokensBought = vesting.purchases(bob);
        uint256 tokensClaimed = vesting.tokensClaimed(bob);
        assertEq(tokensClaimed, tokensBought);
    }

    function testCanClaimAllVestedTokens()
        external
        periodsSet(8, block.timestamp + 2 days, 1)
        idoTokenSet
        idoTokenFilled(false)
        purchasesSet
    {
        vm.warp(vesting.cliffEndsAt() + 1 minutes);

        uint256 totalTokens = vesting.purchases(bob);
        uint256 totalClaimed = vesting.tokensClaimed(bob);
        uint256 claimableAmount = vesting.previewClaimableTokens(bob);

        while (totalClaimed < totalTokens) {
            if (claimableAmount > 0) {
                vm.startPrank(bob);
                vesting.claim();
                vm.stopPrank();
            }

            vm.warp(vesting.lastClaimTimestamps(bob) + 10 days);
            claimableAmount = vesting.previewClaimableTokens(bob);
            totalClaimed = vesting.tokensClaimed(bob);
        }

        assertEq(totalTokens, totalClaimed);
    }

    // EMERGENCY WITHDRAW FOR SPECIFIC WALLET

    function testRevertEmergencyWithdrawByWalletWhenTokenNotSet() external {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IVesting.IVesting__Unauthorized.selector, "Token not set"));
        vesting.emergencyWithdrawByWallet(bob);
        vm.stopPrank();
    }

    function testRevertEmergencyWithdrawByWalletWhenVesingIsOngoing()
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

    // /// FIXING
    // function testRevertEmergencyWithdrawByWalletWhenHasNoAllocation()
    //     external
    // periodsSet(8, block.timestamp + 2 days, 1)
    //     idoTokenSet
    //     idoTokenFilled(false)
    // {
    //     vm.warp(vesting.vestingEndsAt() + 1 hours);
    //     vm.startPrank(owner);
    //     vm.expectRevert(abi.encodeWithSelector(Vesting.Vesting__Unauthorized.selector, "Wallet has no allocation"));
    //     vesting.emergencyWithdrawByWallet(bob);
    //     vm.stopPrank();
    // }

    function testCanEmergencyWithdrawByWallet()
        external
        periodsSet(8, block.timestamp + 2 days, 1)
        idoTokenSet
        idoTokenFilled(false)
        purchasesSet
    {
        uint256 expectedAmountToWithdraw = vesting.purchases(bob);
        vm.warp(vesting.vestingEndsAt() + 1 hours);
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, false);
        emit IVesting.Claimed(bob, expectedAmountToWithdraw);
        vesting.emergencyWithdrawByWallet(bob);
        vm.stopPrank();
    }

    // EMERGENCY WITHDRAW

    function testRevertEmergencyWithdrawtWhenTokenNotSet() external {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IVesting.IVesting__Unauthorized.selector, "Token not set"));
        vesting.emergencyWithdraw();
        vm.stopPrank();
    }

    function testCanEmergencyWithdraw()
        external
        periodsSet(8, block.timestamp + 2 days, 1)
        idoTokenSet
        idoTokenFilled(false)
    {
        assertTrue(vesting.token() != address(0));

        uint256 expectedAmountToWithdraw = ERC20(vesting.token()).balanceOf(address(vesting));
        assertTrue(expectedAmountToWithdraw > 0);

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IVesting.RemainingTokensWithdrawal(expectedAmountToWithdraw);
        vesting.emergencyWithdraw();
        vm.stopPrank();
    }
}
