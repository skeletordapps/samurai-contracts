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

contract VestingCliffTest is Test {
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
        vesting = deployer.runForTests(IVesting.VestingType.CliffVesting);
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
    function testCliff_RevertSetPeriodsWhenVestingAtIsUnderStoredVestingAt()
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

    modifier idoTokenSet() {
        ERC20Mock newToken = new ERC20Mock("IDO TOKEN", "IDT");
        vm.startPrank(owner);
        vesting.setIDOToken(address(newToken));
        vm.stopPrank();
        _;
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

    function testCliff_MustReturnZeroCheckingTGEBalanceBeforeTokenIsSet() external {
        uint256 userAmountInTGE = vesting.previewTGETokens(bob);

        assertEq(userAmountInTGE, 0);
    }

    function testCliff_CanCheckTGEBalance()
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

    function testCliff_MustReturnZeroWhenVestingIsNotSet() external {
        uint256 amount = vesting.previewClaimableTokens(bob);
        assertEq(amount, 0);
    }

    function testCliff_MustReturnZeroWhenWalletHasNoAllocation() external periodsSet(8, block.timestamp + 2 days, 1) {
        vm.warp(vestingAt);

        uint256 amount = vesting.previewClaimableTokens(paul);
        assertEq(amount, 0);
    }

    function testCliff_MustReturnTGEBalanceWhenCliffPeriodIsOngoing()
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

    function testCliff_CanClaimTGE()
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

    function testCliff_CanClaimAllPurchasedTokensFollowingCliffVesting()
        external
        periodsSet(3, block.timestamp + 2 days, 1)
        idoTokenSet
        idoTokenFilled(false)
        purchasesSet
    {
        uint256 cliffEndsAt = vesting.cliffEndsAt();

        uint256 purchased = 500_000 ether;
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

        vm.warp(cliffEndsAt + 1 hours);

        uint256 vestedTokens = vesting.previewVestedTokens();
        assertEq(vestedTokens / 2, purchased);

        vm.startPrank(bob);
        vesting.claim();
        vm.stopPrank();

        balance = ERC20(vesting.token()).balanceOf(bob);
        assertEq(balance, purchased);
    }
}
