// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/console.sol";
import {MissingPoints} from "src/MissingPoints.sol";
import {DeployMissingPoints} from "script/DeployMissingPoints.s.sol";
import {ILock} from "src/interfaces/ILock.sol";
import {IPoints} from "src/interfaces/IPoints.sol";
import {UD60x18, ud} from "@prb/math/src/UD60x18.sol";

contract MissingPointsForLockV3Test is Test {
    uint256 fork;
    string public RPC_URL;

    DeployMissingPoints deployer;
    MissingPoints missingPoints;
    address lock;
    address points;

    ILock iLock;
    IPoints iPoints;

    address owner;
    address bob;
    address mary;
    address realUser;

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployMissingPoints();
        (missingPoints, points, lock) = deployer.runForTests(0xA5c6584d6115cC26C956834849B4051bd200973a);

        iLock = ILock(lock);
        iPoints = IPoints(points);

        owner = missingPoints.owner();

        vm.startPrank(owner);
        iPoints.grantRole(IPoints.Roles.MINTER, address(missingPoints));
        vm.stopPrank();

        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");

        realUser = 0x170D2eA8f593FCAbDB353DBf92fC9E4a417D688C;
        vm.label(realUser, "realUser");
    }

    // CONSTRUCTOR

    function testConstructorReverts() public {
        vm.expectRevert("Invalid points address");
        new MissingPoints(address(0), address(0));

        vm.expectRevert("Invalid lock address");
        new MissingPoints(points, address(0));

        vm.expectRevert("Invalid points address");
        new MissingPoints(address(0), lock);
    }

    function testConstructor() public view {
        assertEq(missingPoints.owner(), owner);
        assertEq(address(missingPoints.iPoints()), points);
        assertEq(address(missingPoints.iLock()), lock);
    }

    function testCalculate() public {
        vm.startPrank(bob);
        uint256 bobPoints = missingPoints.calculate(bob);
        assertEq(bobPoints, 0);
        vm.stopPrank();

        vm.startPrank(mary);
        uint256 maryPoints = missingPoints.calculate(mary);
        assertEq(maryPoints, 0);
        vm.stopPrank();

        uint256 expectedAmount = 348947890669706850000000;
        vm.startPrank(realUser);
        uint256 realUserPoints = missingPoints.calculate(realUser);
        assertEq(realUserPoints, expectedAmount);
        vm.stopPrank();
    }

    function testClaim() public {
        uint256 pointsBefore = iPoints.balanceOf(realUser);

        uint256 expectedAmount = 348947890669706850000000;
        vm.startPrank(realUser);
        missingPoints.claim();
        vm.stopPrank();

        assertEq(iPoints.balanceOf(realUser) - pointsBefore, expectedAmount);
        assertEq(missingPoints.claims(realUser), expectedAmount);
    }

    function testClaimReverts() public {
        vm.startPrank(realUser);
        missingPoints.claim();
        vm.expectRevert("Already claimed");
        missingPoints.claim();
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert("No points to claim");
        missingPoints.claim();
        vm.stopPrank();

        vm.startPrank(mary);
        vm.expectRevert("No points to claim");
        missingPoints.claim();
        vm.stopPrank();
    }
}
