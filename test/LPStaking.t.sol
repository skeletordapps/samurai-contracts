// SPDX-License-Identifier: UNLINCENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console2} from "forge-std/console2.sol";
import {LPStaking} from "../src/LPStaking.sol";
import {DeployLPStaking} from "../script/DeployLPStaking.s.sol";
import {ILPStaking} from "../src/interfaces/ILPStaking.sol";

contract ParticipatorTest is Test {
    uint256 fork;
    string public RPC_URL;

    DeployLPStaking deployer;
    LPStaking staking;
    address lpToken;
    address rewardsToken;
    address gauge;

    address owner;
    address bob;
    address mary;

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployLPStaking();
        bool isFork = true;
        (staking, lpToken, rewardsToken, gauge) = deployer.run(isFork);
        owner = staking.owner();
        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");
    }

    function testConstructor() public {
        assertEq(staking.owner(), owner);
        assertEq(staking.LP_TOKEN(), lpToken);
        assertEq(staking.REWARDS_TOKEN(), rewardsToken);
        assertEq(staking.GAUGE(), gauge);

        assertTrue(staking.paused());
    }

    function testCanInit() external {
        vm.startPrank(owner);
        staking.init(60 days);
        vm.stopPrank();

        assertEq(staking.END_STAKING_UNIX_TIME(), block.timestamp + 60 days);
        assertFalse(staking.paused());
    }
}
