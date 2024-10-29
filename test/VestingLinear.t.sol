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
import {console} from "forge-std/console.sol";

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

    function testLinear_Constructor() public view {
        assertEq(vesting.owner(), owner);
        assertEq(totalPurchased, 1_000_000 ether);
        assertEq(tgeReleasePercent, 0.15e18);
        assertEq(vestingDuration, 3);
        assertEq(vestingAt, block.timestamp);
        assertEq(cliff, 2);
        assertEq(vesting.purchases(bob), 500_000 ether);
        assertEq(vesting.purchases(mary), 500_000 ether);
        assertEq(vesting.pointsPerToken(), 100 ether);
    }

    function testLinear_CanSendIDOTokenToContract() external {
        vm.warp(block.timestamp + 30 minutes);

        address idoToken = vesting.token();
        uint256 expectedAmountOfTokens = 1_000_000 ether;
        deal(idoToken, owner, expectedAmountOfTokens);

        vm.startPrank(owner);
        ERC20(idoToken).approve(address(vesting), expectedAmountOfTokens);

        vm.expectEmit(true, true, true, true);
        emit IVesting.TokensFilled(owner, expectedAmountOfTokens);
        vesting.fillIDOToken(expectedAmountOfTokens);
        vm.stopPrank();

        assertEq(ERC20(idoToken).balanceOf(address(vesting)), expectedAmountOfTokens);
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

    function testLinear_FillInChunks() external idoTokenFilled(true) {
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

    function testLinear_RevertFillIDOTokenTwice() external idoTokenFilled(false) {
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

    function testLinear_CanCheckTGEBalance() external view {
        uint256 userAmountInTGE = vesting.previewTGETokens(bob);
        uint256 userPurchase = vesting.purchases(bob);
        UD60x18 expectedTGEamount = ud(userPurchase).mul(ud(vesting.tgeReleasePercent()));

        assertEq(userAmountInTGE, expectedTGEamount.intoUint256());
    }

    /// CALCULATE RELESEAD TOKENS

    function testLinear_MustReturnZeroWhenWalletHasNoAllocation() external {
        vm.warp(vestingAt);

        uint256 amount = vesting.previewClaimableTokens(paul);
        assertEq(amount, 0);
    }

    function testLinear_MustReturnTGEBalanceWhenCliffPeriodIsOngoing() external {
        vm.warp(vestingAt + 1 days);

        uint256 expectedTGEAmount = 75_000 ether; // 15% of 500_000 ether
        uint256 amount = vesting.previewClaimableTokens(bob);
        assertEq(amount, expectedTGEAmount);
    }

    /// CLAIM TGE

    function testLinear_CanClaimTGE() external idoTokenFilled(false) {
        vm.warp(vestingAt + 1 days);

        address idoToken = vesting.token();
        uint256 expectedTGEAmount = 75_000 ether; // 15% of 500_000 ether
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

    function testLinear_RevertAskRefundWhenClaimedTGE() external idoTokenFilled(false) tgeClaimed(bob) {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVesting.IVesting__Unauthorized.selector, "Not refundable"));
        vesting.askForRefund();
        vm.stopPrank();
    }

    function testLinear_CanAskForRefund() external idoTokenFilled(false) {
        vm.warp(vestingAt + 1 days);

        vm.startPrank(bob);
        vesting.askForRefund();
        vm.stopPrank();

        address[] memory walletsToRefund = vesting.getWalletsToRefund();
        assertEq(walletsToRefund.length, 1);

        address[] memory expectedList = new address[](2);
        expectedList[0] = bob;
        expectedList[1] = mary;

        vm.startPrank(mary);
        vm.expectEmit();
        emit IVesting.NeedRefund(expectedList);
        vesting.askForRefund();
        vm.stopPrank();

        walletsToRefund = vesting.getWalletsToRefund();
        assertEq(walletsToRefund.length, 2);
    }

    function testLinear_CanClaimTGEPlusLinearVestedInPeriod() external idoTokenFilled(false) {
        vm.warp(vestingAt + 1 days);

        uint256 expectedTGEAmount = 75_000 ether;
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

    function testLinear_CanClaimVestedTokensAfterTGEClaim() external idoTokenFilled(false) {
        vm.warp(vestingAt);

        uint256 expectedTGEAmount = 75_000 ether;
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

    function testLinear_CanClaimAllVestedTokens() external idoTokenFilled(false) {
        vm.warp(vesting.cliffEndsAt() + 1 minutes);

        uint256 totalClaimed;
        uint256 totalTokens = 500_000 ether;
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

    function testLinear_RevertEmergencyWithdrawByWalletWhenVesingIsOngoing() external idoTokenFilled(false) {
        (uint256 _vestingDuration, uint256 _vestingAt,) = vesting.periods();
        vm.warp(_vestingAt + _vestingDuration - 1 days);
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IVesting.IVesting__Unauthorized.selector, "Vesting is ongoing"));
        vesting.emergencyWithdrawByWallet(bob);
        vm.stopPrank();
    }

    function testLinear_CanEmergencyWithdrawByWallet() external idoTokenFilled(false) {
        uint256 expectedAmountToWithdraw = 500_000 ether;
        vm.warp(vesting.vestingEndsAt() + 1 hours);
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, false);
        emit IVesting.Claimed(bob, expectedAmountToWithdraw);
        vesting.emergencyWithdrawByWallet(bob);
        vm.stopPrank();
    }

    // EMERGENCY WITHDRAW

    function testLinear_CanEmergencyWithdraw() external idoTokenFilled(false) {
        uint256 expectedAmountToWithdraw = 1_000_000 ether;

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IVesting.RemainingTokensWithdrawal(expectedAmountToWithdraw);
        vesting.emergencyWithdraw();
        vm.stopPrank();
    }
}
