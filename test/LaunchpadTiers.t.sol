// SPDX-License-Identifier: UNLINCENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {LaunchpadTiers} from "../src/LaunchpadTiers.sol";
import {DeployLaunchpadTiers} from "../script/DeployLaunchpadTiers.s.sol";
import {ILaunchpadTiers} from "../src/interfaces/ILaunchpadTiers.sol";

contract LaunchpadTiersTest is Test {
    uint256 fork;
    string public RPC_URL;

    DeployLaunchpadTiers deployer;
    LaunchpadTiers launchpadTiers;

    address owner;
    address bob;
    address mary;

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployLaunchpadTiers();

        launchpadTiers = deployer.run();

        owner = launchpadTiers.owner();
        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");
    }

    // CONSTRUCTOR

    function testConstructor() public {
        assertEq(launchpadTiers.owner(), owner);
        assertEq(launchpadTiers.counter(), 0);
    }

    function testCanAddNewTier() external {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit ILaunchpadTiers.Added(1);
        launchpadTiers.addTier("Shogun", 200_000, 900, 8);
        vm.stopPrank();

        uint256 index = launchpadTiers.counter();
        (string memory name, uint256 staking, uint256 lpStaking, uint256 multiplier) = launchpadTiers.tiers(index);

        assertEq(index, 1);
        assertEq(name, "Shogun");
        assertEq(staking, 200_000);
        assertEq(lpStaking, 900);
        assertEq(multiplier, 8);
    }

    modifier tierAdded(string memory name, uint256 staking, uint256 lpStaking, uint256 multiplier) {
        vm.startPrank(owner);
        launchpadTiers.addTier(name, staking, lpStaking, multiplier);
        vm.stopPrank();
        _;
    }

    function testCanRemoveTier() external tierAdded("Shogun", 200_000, 900, 8) {
        uint256 index = launchpadTiers.counter();

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit ILaunchpadTiers.Removed(ILaunchpadTiers.Tier("Shogun", 200_000, 900, 8));
        launchpadTiers.removeTier(index);
        vm.stopPrank();

        assertEq(launchpadTiers.counter(), 0);
    }

    function testCanUpdateTier() external tierAdded("Shogun", 200_000, 900, 8) {
        uint256 index = launchpadTiers.counter();

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit ILaunchpadTiers.Updated(1);
        launchpadTiers.updateTier(index, "Hatamoto", 100_000, 450, 4);
        vm.stopPrank();

        (string memory name, uint256 staking, uint256 lpStaking, uint256 multiplier) = launchpadTiers.tiers(index);

        assertEq(index, 1);
        assertEq(name, "Hatamoto");
        assertEq(staking, 100_000);
        assertEq(lpStaking, 450);
        assertEq(multiplier, 4);
    }
}
