// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Giveaways} from "../../../src/Giveaways.sol";
import {IGiveaways} from "../../../src/interfaces/IGiveaways.sol";
import {DeployGiveaways} from "../../../script/DeployGiveaways.s.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";
import {BokkyPooBahsDateTimeLibrary} from "@BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";

contract GiveawaysTest is Test {
    uint256 fork;
    string public RPC_URL;

    DeployGiveaways deployer;
    Giveaways giveaways;

    address owner;
    address bob;
    address mary;
    address paul;

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployGiveaways();
        giveaways = deployer.run();
        owner = giveaways.owner();

        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");

        paul = vm.addr(3);
        vm.label(paul, "paul");
    }

    function testConstructor() public view {
        assertEq(address(giveaways.points()), address(0xDf0fDc572849f01CdaB35b80cA41Ce67051C8Dfe));
        assertEq(giveaways.paused(), false);
        assertEq(giveaways.getGiveawaysIds().length, 0);
    }
}
