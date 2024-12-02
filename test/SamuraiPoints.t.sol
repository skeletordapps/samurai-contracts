// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DeploySamuraiPoints} from "../script/DeploySamuraiPoints.s.sol";
import {SamuraiPoints} from "../src/SamuraiPoints.sol";
import {IPoints} from "../src/interfaces/IPoints.sol";
import {IAccessControl} from "@openzeppelin/contracts/access/IAccessControl.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IVesting} from "../src/interfaces/IVesting.sol";

contract SamuraiPointsTest is Test {
    uint256 fork;
    string public RPC_URL;
    DeploySamuraiPoints deployer;

    SamuraiPoints samuraiPoints;
    address owner;
    address bob;
    address mary;
    BoosterContract booster;
    MinterContract minter;
    BurnerContract burner;

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeploySamuraiPoints();

        samuraiPoints = deployer.run();
        owner = samuraiPoints.owner();

        bob = vm.addr(1);
        mary = vm.addr(2);
        booster = new BoosterContract(address(samuraiPoints));
        minter = new MinterContract(address(samuraiPoints));
        burner = new BurnerContract(address(samuraiPoints));

        vm.label(bob, "bob");
        vm.label(mary, "mary");
    }

    function testConstructor() public view {
        assertTrue(samuraiPoints.hasRole(samuraiPoints.BOOSTER_ROLE(), owner));
        assertTrue(samuraiPoints.hasRole(samuraiPoints.MINTER_ROLE(), owner));
        assertTrue(samuraiPoints.hasRole(samuraiPoints.BURNER_ROLE(), owner));
    }

    modifier roleGranted(IPoints.Roles role, address account) {
        vm.startPrank(owner);
        samuraiPoints.grantRole(role, account);
        vm.stopPrank();
        _;
    }

    function testRevertBoostAccountWithoutBoosterRole() external {
        vm.startPrank(address(booster));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(booster), samuraiPoints.BOOSTER_ROLE()
            )
        );
        booster.boostWallet(bob, 2);
        vm.stopPrank();
    }

    function testRevertBoostAccountFor6() external roleGranted(IPoints.Roles.BOOSTER, address(booster)) {
        vm.startPrank(address(booster));
        vm.expectRevert(abi.encodeWithSelector(IPoints.NotAllowed.selector, "Invalid boost amount"));
        booster.boostWallet(bob, 6);
        vm.stopPrank();
    }

    function testRevertBoostAccountForInvalidAddress() external roleGranted(IPoints.Roles.BOOSTER, address(booster)) {
        vm.startPrank(address(booster));
        vm.expectRevert(abi.encodeWithSelector(IPoints.NotAllowed.selector, "Invalid address"));
        booster.boostWallet(address(0), 2);
        vm.stopPrank();
    }

    function testCanBoostAccount() external roleGranted(IPoints.Roles.BOOSTER, address(booster)) {
        vm.startPrank(address(booster));
        vm.expectEmit(true, true, true, true);
        emit IPoints.BoostSet(mary, 0.5 ether);
        booster.boostWallet(mary, 2);
        vm.stopPrank();

        assertEq(samuraiPoints.boostOf(mary), 0.5 ether);
    }

    function testRevertMintPointsForInvalidAddress() external roleGranted(IPoints.Roles.MINTER, address(minter)) {
        vm.startPrank(address(minter));
        vm.expectRevert(abi.encodeWithSelector(IPoints.NotAllowed.selector, "Invalid address"));
        minter.mintPointsToWallet(address(0), 10 ether);
        vm.stopPrank();
    }

    function testRevertMintPoints() external {
        vm.startPrank(address(minter));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(minter), samuraiPoints.MINTER_ROLE()
            )
        );
        minter.mintPointsToWallet(bob, 10 ether);
        vm.stopPrank();
    }

    function testCanMintPoints() external {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IPoints.MintedPoints(bob, 10 ether, 0);
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
        vm.startPrank(address(burner));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(burner), samuraiPoints.BURNER_ROLE()
            )
        );
        burner.burnPointsFromWallet(mary, 20 ether);
        vm.stopPrank();
    }

    function testReverBurnPointsForInvalidAddress() external roleGranted(IPoints.Roles.BURNER, address(burner)) {
        vm.startPrank(address(burner));
        vm.expectRevert(abi.encodeWithSelector(IPoints.NotAllowed.selector, "Invalid address"));
        burner.burnPointsFromWallet(address(0), 10 ether);
        vm.stopPrank();
    }

    function testRevertBurnForInsufficientPoints()
        external
        mintedPoints(mary, 50 ether)
        roleGranted(IPoints.Roles.BURNER, bob)
    {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(IPoints.NotAllowed.selector, "Insufficient points"));
        samuraiPoints.burn(mary, 55 ether);
        assertEq(ERC20(address(samuraiPoints)).balanceOf(mary), 50 ether);

        samuraiPoints.burn(mary, 50 ether);
        assertEq(ERC20(address(samuraiPoints)).balanceOf(mary), 0);
        vm.stopPrank();
    }

    function testCanBurnPoints() external mintedPoints(mary, 20 ether) {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IAccessControl.RoleGranted(samuraiPoints.BURNER_ROLE(), bob, owner);
        samuraiPoints.grantRole(IPoints.Roles.BURNER, bob);
        vm.stopPrank();

        vm.startPrank(bob);
        emit IPoints.BurnedPoints(mary, 10 ether);
        samuraiPoints.burn(mary, 10 ether);
        vm.stopPrank();

        assertEq(ERC20(address(samuraiPoints)).balanceOf(mary), 10 ether);

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IAccessControl.RoleRevoked(samuraiPoints.BURNER_ROLE(), bob, owner);
        samuraiPoints.revokeRole(IPoints.Roles.BURNER, bob);
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

    function testRevertBoostAccount() external mintedPoints(mary, 40 ether) {
        vm.startPrank(address(burner));
        vm.expectRevert(
            abi.encodeWithSelector(
                IAccessControl.AccessControlUnauthorizedAccount.selector, address(booster), samuraiPoints.BOOSTER_ROLE()
            )
        );
        booster.boostWallet(mary, 2);
        vm.stopPrank();
    }

    function testCanRevokeRoles()
        external
        roleGranted(IPoints.Roles.BOOSTER, address(booster))
        roleGranted(IPoints.Roles.MINTER, address(minter))
        roleGranted(IPoints.Roles.BURNER, address(burner))
    {
        vm.startPrank(owner);
        samuraiPoints.revokeRole(IPoints.Roles.BOOSTER, address(booster));
        samuraiPoints.revokeRole(IPoints.Roles.MINTER, address(minter));
        samuraiPoints.revokeRole(IPoints.Roles.BURNER, address(burner));
        vm.stopPrank();

        assertFalse(samuraiPoints.hasRole(samuraiPoints.BOOSTER_ROLE(), address(booster)));
        assertFalse(samuraiPoints.hasRole(samuraiPoints.MINTER_ROLE(), address(minter)));
        assertFalse(samuraiPoints.hasRole(samuraiPoints.BURNER_ROLE(), address(burner)));
    }
}

contract MinterContract {
    IPoints iPoints;

    constructor(address _points) {
        iPoints = IPoints(_points);
    }

    function mintPointsToWallet(address wallet, uint256 numOfPoints) external {
        iPoints.mint(wallet, numOfPoints);
    }
}

contract BurnerContract {
    IPoints iPoints;

    constructor(address _points) {
        iPoints = IPoints(_points);
    }

    function burnPointsFromWallet(address wallet, uint256 numOfPoints) external {
        iPoints.burn(wallet, numOfPoints);
    }
}

contract BoosterContract {
    IPoints iPoints;

    constructor(address _points) {
        iPoints = IPoints(_points);
    }

    function boostWallet(address wallet, uint8 amount) external {
        iPoints.setBoost(wallet, amount);
    }
}
