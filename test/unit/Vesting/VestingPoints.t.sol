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

contract VestingPointsTest is Test {
    DeployVesting deployer;
    Vesting vesting;

    address owner;
    address bob;
    address mary;
    address paul;

    uint256 totalPurchased;
    uint256 tgeReleasePercent;
    uint256 pointsPerToken;
    uint256 vestingDuration;
    uint256 vestingAt;
    uint256 cliff;

    uint256 fork;
    string public RPC_URL;

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployVesting();
        vesting = deployer.runForPointsTests(IVesting.VestingType.LinearVesting);
        owner = vesting.owner();

        bob = 0xcaE8cF1e2119484D6CC3B6EFAad2242aDBDB1Ea8;
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");

        paul = vm.addr(3);
        vm.label(paul, "paul");

        totalPurchased = vesting.totalPurchased();
        tgeReleasePercent = vesting.tgeReleasePercent();
        pointsPerToken = vesting.pointsPerToken();
        (vestingDuration, vestingAt, cliff) = vesting.periods();
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

    modifier tgeClaimed(address wallet) {
        vm.warp(vestingAt + 1 days);
        vm.startPrank(wallet);
        vesting.claim();
        vm.stopPrank();
        _;
    }

    modifier askedForRefund(address wallet) {
        vm.warp(vestingAt + 1 days);
        vm.startPrank(wallet);
        vesting.askForRefund();
        vm.stopPrank();
        _;
    }

    modifier pointsClaimed(address wallet) {
        vm.warp(vestingAt + 1 days);
        vm.startPrank(wallet);
        vesting.claimPoints();
        vm.stopPrank();
        _;
    }

    function testPoints_revertClaimPointsWhenWalletHasNoPurchases() external idoTokenFilled {
        vm.warp(vesting.cliffEndsAt());
        vm.startPrank(paul);
        vm.expectRevert(abi.encodeWithSelector(IVesting.IVesting__Unauthorized.selector, "No tokens available"));
        vesting.claimPoints();
        vm.stopPrank();
    }

    function testPoints_revertClaimPointsWhenAskedForRefund() external idoTokenFilled {
        vm.warp(vestingAt + 1 days);
        vm.startPrank(bob);
        vesting.askForRefund();
        vm.expectRevert(abi.encodeWithSelector(IVesting.IVesting__Unauthorized.selector, "Nothing to claim"));
        vesting.claimPoints();
        vm.stopPrank();
    }

    function testPoints_revertClaimPointsWereAlreadyClaimed() external idoTokenFilled pointsClaimed(bob) {
        vm.warp(vestingAt + 1 days);
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(IVesting.IVesting__Unauthorized.selector, "Nothing to claim"));
        vesting.claimPoints();
        vm.stopPrank();
    }

    function testPoints_canClaimPoints() external idoTokenFilled tgeClaimed(bob) {
        vm.warp(block.timestamp + 1 days); // Time passed since tge claim

        uint256 expectedPoints = ud(500000000000000000000000).mul(ud(0.315e18)).intoUint256(); // purchase * pointsPerToken

        assertEq(expectedPoints, 157_500 ether);

        uint256 expectedBoost = 1e18;

        UD60x18 pointsWithBoost = ud(expectedPoints).add(ud(expectedPoints).mul(ud(expectedBoost)));

        expectedPoints = pointsWithBoost.intoUint256();

        uint256 previewedPoints = vesting.previewClaimablePoints(bob);

        assertEq(previewedPoints, expectedPoints);

        uint256 walletBalanceInPoints = ERC20(vesting.points()).balanceOf(bob);

        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit IVesting.PointsClaimed(bob, expectedPoints);
        vesting.claimPoints();
        vm.stopPrank();

        assertEq(ERC20(vesting.points()).balanceOf(bob), walletBalanceInPoints + expectedPoints);
    }
}
