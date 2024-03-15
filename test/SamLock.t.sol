// SPDX-License-Identifier: UNLINCENSED
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console2} from "forge-std/console2.sol";
import {SamLock} from "../src/SamLock.sol";
import {DeployLock} from "../script/DeployLock.s.sol";

contract SamLockTest is Test {
    uint256 fork;
    string public RPC_URL;

    DeployLock deployer;
    SamLock lock;
    address token;

    address owner;
    address bob;
    address mary;

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployLock();

        (lock, token) = deployer.run();

        owner = lock.owner();
        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");
    }

    // CONSTRUCTOR

    function testConstructor() public {
        assertEq(lock.owner(), owner);
        assertEq(address(lock.sam()), token);
    }

    function testRevertStakeWithZeroAmount() external {
        vm.startPrank(bob);
        vm.expectRevert(SamLock.SamLock__InsufficientAmount.selector);
        lock.stake(bob, 0);
        vm.stopPrank();
    }

    function testCanStake() external {
        uint256 amount = 1 ether;
        vm.startPrank(bob);

        deal(token, bob, amount);
        ERC20(token).approve(address(lock), amount);
        vm.expectEmit(true, true, true, true);
        emit SamLock.Staked(bob, amount);
        lock.stake(bob, amount);

        vm.stopPrank();
    }

    function testRevertWithdrawWithZeroAmount() external {
        vm.startPrank(bob);
        vm.expectRevert(SamLock.SamLock__InsufficientAmount.selector);
        lock.withdraw(bob, 0);
        vm.stopPrank();
    }

    modifier staked() {
        uint256 amount = 1 ether;
        vm.startPrank(bob);

        deal(token, bob, amount);
        ERC20(token).approve(address(lock), amount);

        lock.stake(bob, amount);
        vm.stopPrank();
        _;
    }

    function testRevertWithdrawWithGreaterAmount() external staked {
        uint256 locked = lock.lockings(bob);
        vm.startPrank(bob);
        vm.expectRevert(SamLock.SamLock__InsufficientAmount.selector);
        lock.withdraw(bob, locked * 2);
        vm.stopPrank();
    }

    function testCanWithdraw() external staked {
        uint256 locked = lock.lockings(bob);
        vm.startPrank(bob);

        vm.expectEmit(true, true, true, true);
        emit SamLock.Withdrawn(bob, locked);
        lock.withdraw(bob, locked);

        vm.stopPrank();
    }
}
