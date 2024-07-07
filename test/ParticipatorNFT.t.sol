// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/console.sol";
import {ParticipatorNFT} from "../src/ParticipatorNFT.sol";
import {DeployParticipatorNFT} from "../script/DeployParticipatorNFT.s.sol";
import {ERC20Mock} from "../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IParticipator} from "../src/interfaces/IParticipator.sol";

contract ParticipatorNFTTest is Test {
    uint256 fork;
    string public RPC_URL;

    DeployParticipatorNFT deployer;
    ParticipatorNFT participator;

    address owner;
    address bob;
    address mary;
    address john;
    address randomUSDCHolder;

    address token1;
    address token2;
    uint256 minA;
    uint256 maxA;
    uint256 minB;
    uint256 maxB;
    uint256 minPublic;
    uint256 maxPublic;
    uint256 pricePerToken;
    uint256 maxAllocations;
    uint256 maxAllocationsOfTokensPermitted;

    event Allocated(address indexed wallet, address token, uint256 amount);
    event Whitelisted(address[] addresses);
    event Blacklisted(address wallet);

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployParticipatorNFT();
        participator = deployer.run();
        owner = participator.owner();
        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");

        john = vm.addr(3);
        vm.label(john, "john");

        randomUSDCHolder = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
        vm.label(randomUSDCHolder, "randomUSDCHolder");

        token1 = participator.acceptedTokens(0);
        token2 = participator.acceptedTokens(1);
        minA = participator.minA();
        maxA = participator.maxA();
        minB = participator.minB();
        maxB = participator.maxB();
        minPublic = participator.minPublic();
        maxPublic = participator.maxPublic();
        pricePerToken = participator.pricePerToken();
        maxAllocations = participator.maxAllocations();
        maxAllocationsOfTokensPermitted = maxAllocations * pricePerToken;
    }

    function testConstructor() public {
        assertEq(participator.owner(), owner);
        assertEq(participator.acceptedTokens(0), vm.envAddress("BASE_USDC_ADDRESS"));
        assertEq(participator.acceptedTokens(1), vm.envAddress("BASE_USDC_BASE_ADDRESS"));
        assertEq(participator.minA(), 1);
        assertEq(participator.maxA(), 1);
        assertEq(participator.minB(), 1);
        assertEq(participator.maxB(), 3);
        assertEq(participator.minPublic(), 1);
        assertEq(participator.maxPublic(), 5);
        assertEq(participator.pricePerToken(), 620 * 1e6);
        assertEq(participator.maxAllocations(), 200);
        assertEq(participator.maxAllocationsOfTokensPermitted(), maxAllocationsOfTokensPermitted);
    }

    modifier hasBalance(address wallet, address token, uint256 amount) {
        if (token == token1) {
            vm.startPrank(randomUSDCHolder); // random user
            ERC20(token1).transfer(wallet, amount);
            vm.stopPrank();
        } else {
            deal(token2, wallet, amount);
        }

        _;
    }

    function testReverSendTokenWhenWalletNotWhitelisted() external hasBalance(bob, token1, minA * pricePerToken) {
        vm.startPrank(bob);
        ERC20(token1).approve(address(participator), minA * pricePerToken);

        vm.expectRevert(
            abi.encodeWithSelector(IParticipator.IParticipator__Unauthorized.selector, "Wallet not allowed")
        );
        participator.sendToken(bob, token1, minA * pricePerToken);
        vm.stopPrank();
    }

    modifier isWhitelisted(address wallet, uint256 index) {
        address[] memory wallets = new address[](1);
        wallets[0] = wallet;

        vm.startPrank(owner);
        participator.addBatchToWhitelist(wallets, index);
        vm.stopPrank();
        _;
    }

    function testRevertSendTokenWithInvalidToken()
        external
        hasBalance(bob, token1, minA * pricePerToken)
        isWhitelisted(bob, 0)
    {
        vm.startPrank(bob);
        ERC20(token1).approve(address(participator), minA * pricePerToken);

        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Invalid Token"));
        participator.sendToken(bob, address(0), minA);
        vm.stopPrank();
    }

    function testRevertSendTokenWithWrongMinOrMax()
        external
        hasBalance(bob, token1, maxA * pricePerToken)
        isWhitelisted(bob, 0)
        hasBalance(mary, token1, maxB * pricePerToken)
        isWhitelisted(mary, 1)
    {
        vm.startPrank(bob);

        ERC20(token1).approve(address(participator), minA * pricePerToken / 2);
        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Amount too low"));
        participator.sendToken(bob, token1, minA * pricePerToken / 2);

        ERC20(token1).approve(address(participator), maxA * pricePerToken * 2);
        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Amount too high"));
        participator.sendToken(bob, token1, maxA * pricePerToken * 2);

        vm.stopPrank();

        vm.startPrank(mary);

        ERC20(token1).approve(address(participator), minB * pricePerToken / 2);
        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Amount too low"));
        participator.sendToken(mary, token1, minB * pricePerToken / 2);

        ERC20(token1).approve(address(participator), maxA * pricePerToken * 2);
        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Amount too high"));
        participator.sendToken(mary, token1, maxB * pricePerToken * 2);

        vm.stopPrank();

        vm.startPrank(owner);
        participator.makePublic();
        vm.stopPrank();

        vm.startPrank(john);

        ERC20(token1).approve(address(participator), minPublic * pricePerToken / 2);
        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Amount too low"));
        participator.sendToken(john, token1, minPublic * pricePerToken / 2);

        ERC20(token1).approve(address(participator), maxA * pricePerToken * 2);
        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Amount too high"));
        participator.sendToken(john, token1, maxPublic * pricePerToken * 2);

        vm.stopPrank();
    }

    function testRevertSendTokenWithNonAcceptedToken() external isWhitelisted(bob, 0) {
        vm.startPrank(bob);

        ERC20Mock tokenMock = new ERC20Mock();
        deal(address(tokenMock), bob, minA * pricePerToken);

        ERC20(tokenMock).approve(address(participator), minA * pricePerToken);
        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Token not accepted"));
        participator.sendToken(bob, address(tokenMock), minA * pricePerToken);

        vm.stopPrank();
    }

    function testCanSendToken1()
        external
        isWhitelisted(bob, 0)
        isWhitelisted(mary, 1)
        hasBalance(bob, token1, minA * pricePerToken)
        hasBalance(mary, token1, minB * pricePerToken)
        hasBalance(john, token1, minPublic * pricePerToken)
    {
        // WHITELIST A
        vm.startPrank(bob);
        ERC20(token1).approve(address(participator), minA * pricePerToken);

        vm.expectEmit(true, true, true, true);
        emit Allocated(bob, token1, minA);
        participator.sendToken(bob, token1, minA * pricePerToken);
        vm.stopPrank();

        // WHITELIST B
        vm.startPrank(mary);
        ERC20(token1).approve(address(participator), minB * pricePerToken);

        vm.expectEmit(true, true, true, true);
        emit Allocated(mary, token1, minB);
        participator.sendToken(mary, token1, minB * pricePerToken);
        vm.stopPrank();

        // PUBLIC
        vm.startPrank(owner);
        participator.makePublic();
        vm.stopPrank();

        vm.startPrank(john);
        ERC20(token1).approve(address(participator), minPublic * pricePerToken);

        vm.expectEmit(true, true, true, true);
        emit Allocated(john, token1, minPublic);
        participator.sendToken(john, token1, minPublic * pricePerToken);
        vm.stopPrank();

        assertEq(participator.allocations(bob), minA);
        assertEq(participator.allocations(mary), minB);
        assertEq(participator.allocations(john), minPublic);
    }

    function testCanSendToken2()
        external
        isWhitelisted(bob, 0)
        isWhitelisted(mary, 1)
        hasBalance(bob, token2, minA * pricePerToken)
        hasBalance(mary, token2, minB * pricePerToken)
    {
        vm.startPrank(bob);
        ERC20(token2).approve(address(participator), minA * pricePerToken);

        vm.expectEmit(true, true, true, true);
        emit Allocated(bob, token2, minA);
        participator.sendToken(bob, token2, minA * pricePerToken);
        vm.stopPrank();

        vm.startPrank(mary);
        ERC20(token2).approve(address(participator), minB * pricePerToken);

        vm.expectEmit(true, true, true, true);
        emit Allocated(mary, token2, minB);
        participator.sendToken(mary, token2, minB * pricePerToken);
        vm.stopPrank();

        assertEq(participator.allocations(bob), minA);
        assertEq(participator.allocations(mary), minB);
    }

    modifier allocated(address wallet, address token, uint256 list, uint256 amount) {
        vm.startPrank(wallet);
        ERC20(token).approve(address(participator), amount);
        participator.sendToken(wallet, token, amount);
        vm.stopPrank();
        _;
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

    function testRevertUpdateAMinMaxWhenMaxIsMinorThanMin() external {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Max should be higher or equal Min")
        );
        participator.updateAMinMaxPerWallet(5, 3);
        vm.stopPrank();
    }

    function testCanUpdateAMinMax() external {
        uint256 expectedMin = 1;
        uint256 expectedMax = 5;
        vm.startPrank(owner);
        participator.updateAMinMaxPerWallet(expectedMin, expectedMax);
        vm.stopPrank();

        assertEq(participator.minA(), expectedMin);
        assertEq(participator.maxA(), expectedMax);
    }

    function testRevertUpdateBMinMaxWhenMaxIsMinorThanMin() external {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Max should be higher or equal Min")
        );
        participator.updateBMinMaxPerWallet(5, 3);
        vm.stopPrank();
    }

    function testCanUpdateBMinMax() external {
        uint256 expectedMin = 1;
        uint256 expectedMax = 5;
        vm.startPrank(owner);
        participator.updateBMinMaxPerWallet(expectedMin, expectedMax);
        vm.stopPrank();

        assertEq(participator.minB(), expectedMin);
        assertEq(participator.maxB(), expectedMax);
    }

    function testRevertUpdatePublicMinMaxAWhenMaxIsMinorThanMin() external {
        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Max should be higher or equal Min")
        );
        participator.updatePublicMinMaxPerWallet(5, 3);
        vm.stopPrank();
    }

    function testCanUpdatePublicMinMax() external {
        uint256 expectedMin = 1;
        uint256 expectedMax = 5;
        vm.startPrank(owner);
        participator.updatePublicMinMaxPerWallet(expectedMin, expectedMax);
        vm.stopPrank();

        assertEq(participator.minPublic(), expectedMin);
        assertEq(participator.maxPublic(), expectedMax);
    }

    function testNotWhitelistedsCanSendTokenWhenPublicIsAllowed()
        external
        hasBalance(bob, token1, minPublic * pricePerToken)
        whenIsPublic
    {
        vm.startPrank(bob);
        ERC20(token1).approve(address(participator), minPublic * pricePerToken);

        vm.expectEmit(true, true, true, true);
        emit Allocated(bob, token1, minPublic);
        participator.sendToken(bob, token1, minPublic * pricePerToken);
        vm.stopPrank();

        assertEq(participator.allocations(bob), minPublic);
    }

    function testCanTopUpAllocationsInPublicPhase()
        external
        isWhitelisted(bob, 0)
        hasBalance(bob, token1, minA * pricePerToken)
        allocated(bob, token1, 0, minA * pricePerToken)
        whenIsPublic
        hasBalance(bob, token1, minPublic * pricePerToken)
    {
        vm.startPrank(bob);

        ERC20(token1).approve(address(participator), minPublic * pricePerToken);

        vm.expectEmit(true, true, true, true);
        emit Allocated(bob, token1, minPublic);
        participator.sendToken(bob, token1, minPublic * pricePerToken);
        vm.stopPrank();

        assertEq(participator.allocations(bob), minA + minPublic);
    }

    function testOwnerCanWithdraw()
        external
        isWhitelisted(bob, 0)
        hasBalance(bob, token1, minA * pricePerToken)
        allocated(bob, token1, 0, minA * pricePerToken)
        isWhitelisted(mary, 1)
        hasBalance(mary, token2, minB * pricePerToken)
        allocated(mary, token2, 1, minB * pricePerToken)
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

    function testUpdatePrice() external {
        vm.startPrank(owner);
        uint256 priceExpected = pricePerToken * 2;
        participator.updatePricePerToken(priceExpected);
        vm.stopPrank();

        assertEq(participator.pricePerToken(), priceExpected);
    }
}
