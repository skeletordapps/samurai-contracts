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

contract VestingUpdateTGETest is Test {
    DeployVesting deployer;
    Vesting vesting;

    address owner;
    uint256 vestingDuration;
    uint256 vestingAt;
    uint256 cliff;

    function setUp() public virtual {
        deployer = new DeployVesting();
        vesting = deployer.runForTests(IVesting.VestingType.LinearVesting);
        owner = vesting.owner();

        (vestingDuration, vestingAt, cliff) = vesting.periods();
    }

    function testVestingPeriods_revertWhenZero() external {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IVesting.IVesting__Invalid.selector, "Invalid vestingAt"));
        vesting.updateVestingAt(0);
        vm.stopPrank();
    }

    function testVestingPeriods_revertWhenVestingIsOngoing() external {
        vm.warp(vestingAt);

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IVesting.IVesting__Unauthorized.selector, "Vesting is ongoing"));
        vesting.updateVestingAt(block.timestamp + 2 days);
        vm.stopPrank();
    }

    function testVestingPeriods_revertWhenDecreasingVestingAt() external {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IVesting.IVesting__Unauthorized.selector, "Not allowed to decrease vesting date")
        );
        vesting.updateVestingAt(vestingAt - 1 hours);
        vm.stopPrank();
    }

    function testVestingPeriods_canUpdate() external {
        uint256 newVestingAt = vestingAt + 2 days;
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IVesting.VestingAtUpdated(newVestingAt);
        vesting.updateVestingAt(newVestingAt);
        vm.stopPrank();
    }
}
