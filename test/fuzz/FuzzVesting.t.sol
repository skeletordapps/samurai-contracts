// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Vesting} from "../../src/Vesting.sol";
import {DeployVesting} from "../../script/DeployVesting.s.sol";
import {ERC20Mock} from "../../src/mocks/ERC20Mock.sol";
import {IVesting} from "../../src/interfaces/IVesting.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";
import {BokkyPooBahsDateTimeLibrary} from "@BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";
import {console} from "forge-std/console.sol";

contract FuzzVestingTest is Test {
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

    ERC20 public token;

    function setUp() public virtual {
        deployer = new DeployVesting();
        vesting = deployer.runForTests(IVesting.VestingType.LinearVesting);
        owner = vesting.owner();
        token = ERC20(vesting.token());

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

    function testFuzzClaimAfterTGE(uint256 timeElapsed) public {
        timeElapsed = bound(timeElapsed, 30 days, 365 days);
        vm.warp(block.timestamp + timeElapsed);

        uint256 previewAmount = vesting.previewClaimableTokens(bob);

        vm.startPrank(bob);
        vesting.claim();
        vm.stopPrank();

        assertEq(token.balanceOf(bob), previewAmount);
    }
}
