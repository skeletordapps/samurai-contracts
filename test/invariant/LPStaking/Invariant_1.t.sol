// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {Vm} from "forge-std/Vm.sol";
import {LPStaking} from "../../../src/LPStaking.sol";
import {ILPStaking} from "../../../src/interfaces/ILPStaking.sol";
import {DeployLPStaking} from "../../../script/DeployLPStaking.s.sol";
import {console} from "forge-std/console.sol";

contract LPStaking_Invariant_1 is Test {
    uint256 fork;
    string public RPC_URL;

    DeployLPStaking deployer;
    LPStaking private lpStaking;
    address private lpToken;
    address private rewardsToken;
    address private gauge;
    address private points;

    function setUp() public {
        deployer = new DeployLPStaking();

        ((lpStaking, lpToken, rewardsToken, gauge, points)) = deployer.runForTests();

        targetContract(address(lpStaking));
    }

    function invariant_test_totalStaked_is_always_greater_or_equal_totalWithdrawn() public view {
        assertGe(lpStaking.totalStaked(), lpStaking.totalWithdrawn());
    }
}
