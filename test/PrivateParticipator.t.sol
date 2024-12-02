// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/console.sol";
import {PrivateParticipator} from "../src/PrivateParticipator.sol";
import {DeployPrivateParticipator} from "../script/DeployPrivateParticipator.s.sol";
import {ERC20Mock} from "../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IParticipator} from "../src/interfaces/IParticipator.sol";

contract PrivateParticipatorTest is Test {
    uint256 fork;
    string public RPC_URL;

    DeployPrivateParticipator deployer;
    PrivateParticipator participator;

    address owner;
    address joe;
    address bob;
    address mary;
    address paul;
    address randomUSDCHolder;
    address walletInTiers;

    address acceptedToken;
    uint256 maxAllocations;
    uint256 pricePerToken;
    uint256 minPerWallet;

    event Allocated(address indexed wallet, address token, uint256 amount);
    event Whitelisted(address[] addresses);
    event Blacklisted(address wallet);

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployPrivateParticipator();
        participator = deployer.run();
        owner = participator.owner();

        joe = vm.addr(1); // 0 nodes
        vm.label(bob, "bob");

        bob = 0xcaE8cF1e2119484D6CC3B6EFAad2242aDBDB1Ea8; // 3 nodes
        vm.label(bob, "bob");

        mary = 0xcab2AaDD8b875F74d5b04f1453D9a9cAd2F395CD; // 1 node
        vm.label(mary, "mary");

        paul = 0x148AFbce5CE5417e966E92D2c04Bd81D8cB0e04e; // 20 node
        vm.label(paul, "paul");

        randomUSDCHolder = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
        walletInTiers = 0xC2a96B13a975c656f60f401a5F72851af4717D4A;
        vm.label(randomUSDCHolder, "randomUSDCHolder");

        acceptedToken = participator.acceptedToken();
        maxAllocations = participator.maxAllocations();
        pricePerToken = participator.pricePerToken();
        minPerWallet = participator.minPerWallet();
    }

    function testConstructor() public view {
        assertEq(participator.owner(), owner);
        assertEq(acceptedToken, vm.envAddress("BASE_USDC_ADDRESS"));
        assertTrue(participator.maxAllocations() > 0);
        assertEq(participator.minPerWallet(), 100e6);
        assertEq(participator.pricePerToken(), 145e6);
    }

    modifier hasBalance(address wallet, uint256 amount) {
        vm.startPrank(randomUSDCHolder);
        ERC20(acceptedToken).transfer(wallet, amount);
        vm.stopPrank();
        _;
    }

    // PARTICIPATING

    function testRevertParticipationWhenNotWhitelisted() external {
        vm.startPrank(joe);
        vm.expectRevert(
            abi.encodeWithSelector(IParticipator.IParticipator__Unauthorized.selector, "Wallet not allowed")
        );
        participator.participate(0);
        vm.stopPrank();
    }

    function testCanParticipateWithMinPerWallet() external hasBalance(bob, minPerWallet) {
        vm.startPrank(bob);
        ERC20(acceptedToken).approve(address(participator), minPerWallet);
        participator.participate(minPerWallet);
        vm.stopPrank();

        assertEq(participator.allocations(bob), minPerWallet);
    }

    function testCanParticipateWithHalfPermitted() external {
        uint256 halfMaxPermitted = participator.walletsMaxPermitted(bob) / 2;

        vm.startPrank(randomUSDCHolder);
        ERC20(acceptedToken).transfer(bob, halfMaxPermitted);
        vm.stopPrank();

        vm.startPrank(bob);
        ERC20(acceptedToken).approve(address(participator), halfMaxPermitted);
        participator.participate(halfMaxPermitted);
        vm.stopPrank();

        assertEq(participator.allocations(bob), halfMaxPermitted);
    }

    function testCanParticipateWithMaxPermitted() external {
        uint256 maxPermitted = participator.walletsMaxPermitted(bob);

        vm.startPrank(randomUSDCHolder);
        ERC20(acceptedToken).transfer(bob, maxPermitted);
        vm.stopPrank();

        vm.startPrank(bob);
        ERC20(acceptedToken).approve(address(participator), maxPermitted);
        participator.participate(maxPermitted);
        vm.stopPrank();

        assertEq(participator.allocations(bob), maxPermitted);
    }

    function testCanTopUpParticipation() external {
        uint256 amount = participator.walletsMaxPermitted(paul) / 2;

        vm.startPrank(randomUSDCHolder);
        ERC20(acceptedToken).transfer(paul, amount);
        vm.stopPrank();

        vm.startPrank(paul);
        ERC20(acceptedToken).approve(address(participator), amount);
        participator.participate(amount);
        vm.stopPrank();

        assertEq(participator.allocations(paul), amount);

        vm.startPrank(randomUSDCHolder);
        ERC20(acceptedToken).transfer(paul, amount);
        vm.stopPrank();

        vm.startPrank(paul);
        ERC20(acceptedToken).approve(address(participator), amount);
        participator.participate(amount);
        vm.stopPrank();

        assertEq(participator.allocations(paul), amount * 2);
    }

    function testRevertParticipationWithLessThanMin() external {
        uint256 less = minPerWallet - 10e6;

        vm.startPrank(randomUSDCHolder);
        ERC20(acceptedToken).transfer(bob, less);
        vm.stopPrank();

        vm.startPrank(bob);
        ERC20(acceptedToken).approve(address(participator), less);
        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Amount too low"));
        participator.participate(less);
        vm.stopPrank();
    }

    function testRevertParticipationWithMoreThanPermitted() external {
        uint256 upMax = participator.walletsMaxPermitted(bob) + 10e6;

        vm.startPrank(randomUSDCHolder);
        ERC20(acceptedToken).transfer(bob, upMax);
        vm.stopPrank();

        vm.startPrank(bob);
        ERC20(acceptedToken).approve(address(participator), upMax);
        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Amount too high"));
        participator.participate(upMax);
        vm.stopPrank();
    }
}
