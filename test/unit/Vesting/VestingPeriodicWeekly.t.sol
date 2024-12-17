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

contract VestingPeriodicWeeklyTest is Test {
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
        vesting = deployer.runForPeriodicTests(IVesting.PeriodType.Weeks, 1);
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

    function testPeriodicWeekly_Constructor() public view {
        assertEq(vesting.owner(), owner);
        assertEq(totalPurchased, 1_000_000 ether);
        assertEq(tgeReleasePercent, 0.15e18);
        assertEq(vestingDuration, 1);
        assertEq(vestingAt, block.timestamp + 1 days);
        assertEq(cliff, 2);
        assertEq(vesting.purchases(bob), 500_000 ether);
        assertEq(vesting.purchases(mary), 500_000 ether);
    }

    modifier idoTokenFilled() {
        vm.warp(block.timestamp + 30 minutes);
        address idoToken = vesting.token();
        uint256 expectedAmountOfTokens = 1_000_000 ether;

        deal(idoToken, owner, expectedAmountOfTokens);

        vm.startPrank(owner);
        ERC20(idoToken).approve(address(vesting), expectedAmountOfTokens);
        vesting.fillIDOToken(expectedAmountOfTokens);
        vm.stopPrank();
        _;
    }

    function testPeriodicWeekly_CanClaimTGEPlusOneWeekAmountUnlocked() external idoTokenFilled {
        uint256 cliffEndsAt = vesting.cliffEndsAt();

        uint256 purchased = vesting.purchases(bob);
        uint256 expectedTGEAmount = 75_000 ether;

        vm.warp(cliffEndsAt - 1 hours);
        uint256 claimable = vesting.previewClaimableTokens(bob);
        assertEq(claimable, expectedTGEAmount);

        vm.warp(BokkyPooBahsDateTimeLibrary.addDays(cliffEndsAt, 1 weeks));
        claimable = vesting.previewClaimableTokens(bob);
        assertTrue(claimable > expectedTGEAmount);

        UD60x18 total = ud(totalPurchased);
        UD60x18 vested = ud(vesting.previewVestedTokens());
        UD60x18 totalVestedPercentage = vested.mul(convert(100)).div(total);
        UD60x18 walletSharePercentage = ud(purchased).mul(convert(100)).div(total);
        UD60x18 walletVestedPercentage = walletSharePercentage.mul(totalVestedPercentage).div(convert(100));
        UD60x18 walletVested = total.mul(walletVestedPercentage).div(convert(100));
        uint256 expectedAmountAfterOneWeek = walletVested.intoUint256();

        assertEq(claimable, expectedAmountAfterOneWeek);

        uint256 walletBalance = ERC20(vesting.token()).balanceOf(bob);

        vm.startPrank(bob);
        vesting.claim();
        vm.stopPrank();

        uint256 walletBalanceAfter = ERC20(vesting.token()).balanceOf(bob);
        assertEq(walletBalanceAfter, walletBalance + claimable);
    }

    function jumpWeek() public view returns (uint256) {
        return block.timestamp + 1 weeks;
    }

    function testPeriodicWeekly_CanClaimAllPurchasedTokensFollowingPeriodicVesting() external idoTokenFilled {
        uint256 cliffEndsAt = vesting.cliffEndsAt();
        uint256 vestingEndsAt = vesting.vestingEndsAt();

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

        uint256 diffWeeks = BokkyPooBahsDateTimeLibrary.diffDays(cliffEndsAt, vestingEndsAt) / 7;

        vm.warp(cliffEndsAt);
        vesting.previewClaimableTokens(bob);

        for (uint256 i = 0; i < diffWeeks; i++) {
            vm.warp(jumpWeek());
            vm.startPrank(bob);
            vesting.claim();
            vm.stopPrank();
        }

        uint256 balance = ERC20(vesting.token()).balanceOf(bob);
        assertEq(balance, purchased);
    }

    function testPeriodicWeekly_ShouldNotIncreaseClaimableWithoutAWeekCompletes() external idoTokenFilled {
        uint256 cliffEndsAt = vesting.cliffEndsAt();

        uint256 expectedTGEAmount = 75_000 ether;

        vm.warp(cliffEndsAt);
        uint256 claimable = vesting.previewClaimableTokens(bob);
        assertEq(claimable, expectedTGEAmount);

        vm.warp(cliffEndsAt + 6 days + 23 hours + 59 minutes);
        claimable = vesting.previewClaimableTokens(bob);
        assertEq(claimable, expectedTGEAmount);

        vm.warp(cliffEndsAt + 1 weeks);
        claimable = vesting.previewClaimableTokens(bob);
        assertTrue(claimable > expectedTGEAmount);

        vm.warp(block.timestamp + 6 days + 23 hours + 59 minutes);
        uint256 claimableNext = vesting.previewClaimableTokens(bob);
        assertEq(claimableNext, claimable);

        vm.warp(block.timestamp + 1 minutes);
        claimableNext = vesting.previewClaimableTokens(bob);
        assertTrue(claimableNext > claimable);
    }
}
