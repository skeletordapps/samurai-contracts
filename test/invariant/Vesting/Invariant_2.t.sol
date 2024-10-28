// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {Vesting} from "../../../src/Vesting.sol";
import {IVesting} from "../../../src/interfaces/IVesting.sol";
import {DeployVesting} from "../../../script/DeployVesting.s.sol";
import {console} from "forge-std/console.sol";

contract Vesting_Invariant_2 is Test {
    DeployVesting deployer;

    Vesting private target1;
    Vesting private target2;
    Vesting private target3;

    function setUp() public {
        deployer = new DeployVesting();

        target1 = deployer.runForTests(IVesting.VestingType.CliffVesting);
        target2 = deployer.runForTests(IVesting.VestingType.LinearVesting);
        target3 = deployer.runForTests(IVesting.VestingType.PeriodicVesting);

        targetContract(address(target1));
        targetContract(address(target2));
        targetContract(address(target3));
    }

    function invariant_test_cliff_totalVested_is_always_higher_or_equal_totalClaimed() public {
        assertGe(target1.previewVestedTokens(), target1.totalClaimed());
    }

    function invariant_test_linear_totalVested_is_always_higher_or_equal_totalClaimed() public {
        assertGe(target2.previewVestedTokens(), target2.totalClaimed());
    }

    function invariant_test_periodic_totalVested_is_always_higher_or_equal_totalClaimed() public {
        assertGe(target3.previewVestedTokens(), target3.totalClaimed());
    }
}
