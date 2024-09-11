// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DeploySamuraiPoints} from "../script/DeploySamuraiPoints.s.sol";
import {SamuraiPoints} from "../src/SamuraiPoints.sol";
import {IPoints} from "../src/interfaces/IPoints.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";

contract SamuraiPointsTest is Test {
    uint256 fork;
    string public RPC_URL;
    DeploySamuraiPoints deployer;

    SamuraiPoints samuraiPoints;
    address owner;
    address bob;
    address mary;
    ContractA contractA;
    ContractB contractB;

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeploySamuraiPoints();

        samuraiPoints = deployer.run();
        owner = samuraiPoints.owner();

        bob = vm.addr(1);
        mary = vm.addr(2);
        contractA = new ContractA(address(samuraiPoints));
        contractB = new ContractB(address(samuraiPoints));

        vm.label(bob, "bob");
        vm.label(mary, "mary");
    }

    function testConstructor() public {
        assertTrue(samuraiPoints.hasRole(samuraiPoints.MANAGER_ROLE(), owner));
    }

    function testCanGrantManagerRoleToAccounts() external {}

    function testCanRevokeManagerRoleFromAccounts() external {}

    function testRevertAddPoints() external {
        vm.startPrank(address(contractA));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(contractA),
                samuraiPoints.MANAGER_ROLE()
            )
        );
        contractA.grantPointsToWallet(bob, 10);
        vm.stopPrank();
    }

    function testCanAddPoints() external {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IPoints.PointsAdded(bob, 10);
        samuraiPoints.grantPoints(bob, 10);
        vm.stopPrank();
    }

    modifier pointsAdded(address to, uint256 numOfPoints) {
        vm.startPrank(owner);
        samuraiPoints.grantPoints(to, numOfPoints);
        vm.stopPrank();
        _;
    }

    function testRevertRemovePoints() external pointsAdded(mary, 40) {
        vm.startPrank(address(contractB));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(contractB),
                samuraiPoints.MANAGER_ROLE()
            )
        );
        contractB.removePointsFromWallet(mary, 20);
        vm.stopPrank();
    }

    function testCanRemovePoints() external pointsAdded(mary, 20) {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IAccessControl.RoleGranted(samuraiPoints.MANAGER_ROLE(), bob, owner);
        samuraiPoints.grantManagerRole(bob);
        vm.stopPrank();

        vm.startPrank(bob);
        emit IPoints.PointsRemoved(mary, 10);
        samuraiPoints.removePoints(mary, 10);
        vm.stopPrank();

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IAccessControl.RoleRevoked(samuraiPoints.MANAGER_ROLE(), bob, owner);
        samuraiPoints.revokeManagerRole(bob);
        vm.stopPrank();
    }
}

contract ContractA {
    IPoints iPoints;

    constructor(address _points) {
        iPoints = IPoints(_points);
    }

    function grantPointsToWallet(address wallet, uint256 numOfPoints) external {
        iPoints.grantPoints(wallet, numOfPoints);
    }
}

contract ContractB {
    IPoints iPoints;

    constructor(address _points) {
        iPoints = IPoints(_points);
    }

    function removePointsFromWallet(address wallet, uint256 numOfPoints) external {
        iPoints.removePoints(wallet, numOfPoints);
    }
}
