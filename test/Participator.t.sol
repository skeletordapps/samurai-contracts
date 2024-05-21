// SPDX-License-Identifier: UNLINCENSED
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console2} from "forge-std/console2.sol";
import {Participator} from "../src/IDO/Participator.sol";
import {DeployParticipator} from "../script/DeployParticipator.s.sol";
import {ERC20Mock} from "../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IParticipator} from "../src/interfaces/IParticipator.sol";

contract ParticipatorTest is Test {
    uint256 fork;
    string public RPC_URL;

    DeployParticipator deployer;
    Participator participator;

    address owner;
    address bob;
    address mary;
    address randomUSDCHolder;

    address token1;
    address token2;
    uint256 min;
    uint256 max;
    uint256 maxAllocations;

    event Allocated(address indexed wallet, address token, uint256 amount);
    event Whitelisted(address[] addresses);
    event Blacklisted(address wallet);

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployParticipator();
        participator = deployer.run();
        owner = participator.owner();
        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");

        randomUSDCHolder = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
        vm.label(randomUSDCHolder, "randomUSDCHolder");

        token1 = participator.acceptedTokens(0);
        token2 = participator.acceptedTokens(1);
        min = participator.min();
        max = participator.max();
        maxAllocations = participator.maxAllocations();
    }

    function testConstructor() public {
        assertEq(participator.owner(), owner);
        assertEq(participator.acceptedTokens(0), vm.envAddress("BASE_USDC_ADDRESS"));
        assertEq(participator.acceptedTokens(1), vm.envAddress("BASE_USDC_BASE_ADDRESS"));
        assertEq(participator.min(), 100 * 1e6);
        assertEq(participator.max(), 2000 * 1e6);
    }

    modifier bobHasBalance(uint256 amount) {
        vm.startPrank(randomUSDCHolder); // random user
        ERC20(token1).transfer(bob, amount);
        vm.stopPrank();

        deal(token2, bob, amount);
        _;
    }

    modifier maryHasBalance() {
        vm.startPrank(randomUSDCHolder); // random user
        ERC20(token1).transfer(mary, min);
        vm.stopPrank();

        deal(token2, mary, min);
        _;
    }

    function testReverSendTokenWhenWalletNotWhitelisted() external bobHasBalance(min) {
        vm.startPrank(bob);
        ERC20(token1).approve(address(participator), min);

        vm.expectRevert(
            abi.encodeWithSelector(IParticipator.IParticipator__Unauthorized.selector, "Wallet not allowed")
        );
        participator.sendToken(bob, token1, min);
        vm.stopPrank();
    }

    modifier bobIsWhitelisted() {
        address[] memory wallets = new address[](1);
        wallets[0] = bob;

        vm.startPrank(owner);
        participator.addBatchToWhitelist(wallets);
        vm.stopPrank();
        _;
    }

    modifier maryIsWhitelisted() {
        address[] memory wallets = new address[](1);
        wallets[0] = mary;

        vm.startPrank(owner);
        participator.addBatchToWhitelist(wallets);
        vm.stopPrank();
        _;
    }

    function testRevertSendTokenWithInvalidToken() external bobHasBalance(min) bobIsWhitelisted {
        vm.startPrank(bob);
        ERC20(token1).approve(address(participator), min);

        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Invalid Token"));
        participator.sendToken(bob, address(0), min);
        vm.stopPrank();
    }

    function testRevertSendTokenWithWrongMinOrMax() external bobHasBalance(min) bobIsWhitelisted {
        vm.startPrank(bob);

        ERC20(token1).approve(address(participator), min / 2);
        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Amount too low"));
        participator.sendToken(bob, token1, min / 2);

        ERC20(token1).approve(address(participator), max * 2);
        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Amount too high"));
        participator.sendToken(bob, token1, max * 2);

        vm.stopPrank();
    }

    function testRevertSendTokenWithNonAcceptedToken() external bobIsWhitelisted {
        vm.startPrank(bob);

        ERC20Mock tokenMock = new ERC20Mock();
        deal(address(tokenMock), bob, min);

        ERC20(tokenMock).approve(address(participator), min / 2);
        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Token not accepted"));
        participator.sendToken(bob, address(tokenMock), min);

        vm.stopPrank();
    }

    function testCanSendToken1() external bobIsWhitelisted bobHasBalance(min) {
        vm.startPrank(bob);
        ERC20(token1).approve(address(participator), min);

        vm.expectEmit(true, true, true, true);
        emit Allocated(bob, token1, min);
        participator.sendToken(bob, token1, min);
        vm.stopPrank();

        assertEq(participator.allocations(bob), min);
    }

    function testCanSendToken2() external maryIsWhitelisted maryHasBalance {
        vm.startPrank(mary);
        ERC20(token2).approve(address(participator), min);

        vm.expectEmit(true, true, true, true);
        emit Allocated(mary, token2, min);
        participator.sendToken(mary, token2, min);
        vm.stopPrank();

        assertEq(participator.allocations(mary), min);
    }

    modifier bobAllocatedToken1() {
        vm.startPrank(bob);
        ERC20(token1).approve(address(participator), min);
        participator.sendToken(bob, token1, min);
        vm.stopPrank();
        _;
    }

    modifier bobAllocatedMaxInToken1() {
        vm.startPrank(bob);
        ERC20(token1).approve(address(participator), max);
        participator.sendToken(bob, token1, max);
        vm.stopPrank();
        _;
    }

    modifier bobAllocatedToken2() {
        vm.startPrank(bob);
        ERC20(token2).approve(address(participator), min);
        participator.sendToken(bob, token2, min);
        vm.stopPrank();
        _;
    }

    modifier maryAllocatedToken2() {
        vm.startPrank(mary);
        ERC20(token2).approve(address(participator), min);
        participator.sendToken(mary, token2, min);
        vm.stopPrank();
        _;
    }

    function testRevertSendTokenWhenWalletAlreadyAllocatedMaxPerWallet()
        external
        bobIsWhitelisted
        bobHasBalance(max)
        bobAllocatedMaxInToken1
        bobHasBalance(min)
    {
        vm.startPrank(bob);

        ERC20(token1).approve(address(participator), min);
        vm.expectRevert(
            abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Exceeds max allocation permitted")
        );
        participator.sendToken(bob, token1, min);

        vm.stopPrank();
    }

    function testWalletCanParticipateWhileDontReachMaxPerWallet() external bobIsWhitelisted bobHasBalance(max) {
        vm.startPrank(bob);
        for (uint256 i = 0; i < 4; i++) {
            ERC20(token1).approve(address(participator), max / 4);
            participator.sendToken(bob, token1, max / 4);
        }
        vm.stopPrank();

        assertEq(participator.allocations(bob), max);
    }

    function testRevertWhenReachMaxAllocations() external {
        uint256 counter = 1;

        while (participator.raised() < maxAllocations) {
            // define wallet
            address wallet = vm.addr(counter);

            // whitelist
            address[] memory wallets = new address[](1);
            wallets[0] = wallet;
            vm.startPrank(owner);
            participator.addBatchToWhitelist(wallets);
            vm.stopPrank();

            // deal balance to wallet
            deal(token2, wallet, max);

            // wallet allocate
            vm.startPrank(wallet);
            ERC20(token2).approve(address(participator), max);
            participator.sendToken(wallet, token2, max);
            vm.stopPrank();

            // update counter
            counter++;
        }

        // assertEq(participator.raised(), maxAllocations);

        // address newWallet = vm.addr(counter);

        // // whitelist
        // address[] memory newWallets = new address[](1);
        // newWallets[0] = newWallet;
        // vm.startPrank(owner);
        // participator.addBatchToWhitelist(newWallets);
        // vm.stopPrank();

        // // deal balance to wallet
        // deal(token2, newWallet, max);

        // // wallet allocate
        // vm.startPrank(newWallet);
        // ERC20(token2).approve(address(participator), max);
        // vm.expectRevert(
        //     abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Exceeds max allocations permitted")
        // );
        // participator.sendToken(newWallet, token2, max);
        // vm.stopPrank();
    }

    function testOwnerCanMakeItPublic() external {
        assertFalse(participator.isPublic());

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IParticipator.PublicAllowed();
        participator.makePublic();
        vm.stopPrank();

        assertTrue(participator.isPublic());
    }

    modifier whenIsPublic() {
        vm.startPrank(owner);
        participator.makePublic();
        vm.stopPrank();
        _;
    }

    function testRevertUpdateMinMaxWhenMaxIsMinorThanMin() external {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Max should be higher than Min")
        );
        participator.updateMinMaxPerWallet(300 ether, 200 ether);
        vm.stopPrank();
    }

    function testCanUpdateMinMax() external {
        uint256 expectedMin = 300 ether;
        uint256 expectedMax = 500 ether;
        vm.startPrank(owner);
        participator.updateMinMaxPerWallet(expectedMin, expectedMax);
        vm.stopPrank();

        assertEq(participator.min(), expectedMin);
        assertEq(participator.max(), expectedMax);
    }

    function testNotWhitelistedsCanSendTokenWhenPublicIsAllowed() external bobHasBalance(min) whenIsPublic {
        vm.startPrank(bob);
        ERC20(token1).approve(address(participator), min);

        vm.expectEmit(true, true, true, true);
        emit Allocated(bob, token1, min);
        participator.sendToken(bob, token1, min);
        vm.stopPrank();

        assertEq(participator.allocations(bob), min);
    }

    function testOwnerCanWithdraw()
        external
        bobIsWhitelisted
        bobHasBalance(min)
        bobAllocatedToken1
        maryIsWhitelisted
        maryHasBalance
        maryAllocatedToken2
    {
        uint256 token1BalanceBefore = ERC20(token1).balanceOf(address(participator));
        uint256 token1OwnerBalanceBefore = ERC20(token1).balanceOf(owner);

        uint256 token2BalanceBefore = ERC20(token2).balanceOf(address(participator));
        uint256 token2OwnerBalanceBefore = ERC20(token2).balanceOf(owner);

        vm.startPrank(owner);
        participator.withdraw();
        vm.stopPrank();

        uint256 token1BalanceAfter = ERC20(token1).balanceOf(address(participator));
        uint256 token1OwnerBalanceAfter = ERC20(token1).balanceOf(owner);

        uint256 token2BalanceAfter = ERC20(token2).balanceOf(address(participator));
        uint256 token2OwnerBalanceAfter = ERC20(token2).balanceOf(owner);

        assertEq(token1BalanceAfter, 0);
        assertEq(token1OwnerBalanceAfter, token1OwnerBalanceBefore + token1BalanceBefore);

        assertEq(token2BalanceAfter, 0);
        assertEq(token2OwnerBalanceAfter, token2OwnerBalanceBefore + token2BalanceBefore);
    }
}
