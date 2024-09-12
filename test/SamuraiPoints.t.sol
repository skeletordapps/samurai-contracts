// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DeploySamuraiPoints} from "../script/DeploySamuraiPoints.s.sol";
import {SamuraiPoints} from "../src/SamuraiPoints.sol";
import {IPoints} from "../src/interfaces/IPoints.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

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

    function testRevertMintPoints() external {
        vm.startPrank(address(contractA));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(contractA),
                samuraiPoints.MANAGER_ROLE()
            )
        );
        contractA.mintPointsToWallet(bob, 10 ether);
        vm.stopPrank();
    }

    function testCanAddPoints() external {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IPoints.MintedPoints(bob, 10 ether);
        samuraiPoints.mint(bob, 10 ether);
        vm.stopPrank();

        assertEq(ERC20(address(samuraiPoints)).balanceOf(bob), 10 ether);
    }

    modifier mintedPoints(address to, uint256 numOfPoints) {
        vm.startPrank(owner);
        samuraiPoints.mint(to, numOfPoints);
        vm.stopPrank();

        assertEq(ERC20(address(samuraiPoints)).balanceOf(to), numOfPoints);
        _;
    }

    function testRevertBurnPoints() external mintedPoints(mary, 40 ether) {
        vm.startPrank(address(contractB));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector,
                address(contractB),
                samuraiPoints.MANAGER_ROLE()
            )
        );
        contractB.burnPointsFromWallet(mary, 20 ether);
        vm.stopPrank();
    }

    function testRevertBurnForInsufficientPoints() external mintedPoints(mary, 50 ether) {
        vm.startPrank(owner);
        samuraiPoints.grantManagerRole(bob);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(IPoints.NotAllowed.selector, "Insufficient points"));
        samuraiPoints.burn(mary, 55 ether);
        assertEq(ERC20(address(samuraiPoints)).balanceOf(mary), 50 ether);

        samuraiPoints.burn(mary, 50 ether);
        assertEq(ERC20(address(samuraiPoints)).balanceOf(mary), 0);
        vm.stopPrank();
    }

    function testCanRemovePoints() external mintedPoints(mary, 20 ether) {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IAccessControl.RoleGranted(samuraiPoints.MANAGER_ROLE(), bob, owner);
        samuraiPoints.grantManagerRole(bob);
        vm.stopPrank();

        vm.startPrank(bob);
        emit IPoints.BurnedPoints(mary, 10 ether);
        samuraiPoints.burn(mary, 10 ether);
        vm.stopPrank();

        assertEq(ERC20(address(samuraiPoints)).balanceOf(mary), 10 ether);

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IAccessControl.RoleRevoked(samuraiPoints.MANAGER_ROLE(), bob, owner);
        samuraiPoints.revokeManagerRole(bob);
        vm.stopPrank();
    }

    function testRevertPointsTransfer() external mintedPoints(bob, 10 ether) {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(IPoints.NotAllowed.selector, "Direct transfers are not allowed"));
        ERC20(address(samuraiPoints)).transfer(mary, 5 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(IPoints.NotAllowed.selector, "Direct transfers are not allowed"));
        ERC20(address(samuraiPoints)).transferFrom(bob, mary, 5 ether);
        vm.stopPrank();
    }
}

contract ContractA {
    IPoints iPoints;

    constructor(address _points) {
        iPoints = IPoints(_points);
    }

    function mintPointsToWallet(address wallet, uint256 numOfPoints) external {
        iPoints.mint(wallet, numOfPoints);
    }
}

contract ContractB {
    IPoints iPoints;

    constructor(address _points) {
        iPoints = IPoints(_points);
    }

    function burnPointsFromWallet(address wallet, uint256 numOfPoints) external {
        iPoints.burn(wallet, numOfPoints);
    }
}
