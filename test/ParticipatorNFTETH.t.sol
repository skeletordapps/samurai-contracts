// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console2} from "forge-std/console2.sol";
import {ParticipatorNFTETH} from "../src/ParticipatorNFTETH.sol";
import {DeployParticipatorNFTETH} from "../script/DeployParticipatorNFTETH.s.sol";
import {ERC20Mock} from "../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IParticipator} from "../src/interfaces/IParticipator.sol";

contract ParticipatorNFTETHTest is Test {
    uint256 fork;
    string public RPC_URL;

    DeployParticipatorNFTETH deployer;
    ParticipatorNFTETH participator;

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

        deployer = new DeployParticipatorNFTETH();
        participator = deployer.runForTests();
        owner = participator.owner();
        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");

        john = vm.addr(3);
        vm.label(john, "john");

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
        assertEq(participator.minA(), 2);
        assertEq(participator.maxA(), 5);
        assertEq(participator.minB(), 0);
        assertEq(participator.maxB(), 0);
        assertEq(participator.minPublic(), 0);
        assertEq(participator.maxPublic(), 0);
        assertEq(participator.pricePerToken(), 0.065 ether);
        assertEq(participator.maxAllocations(), 500);
    }

    modifier hasBalance(address wallet, uint256 amount) {
        vm.deal(wallet, amount);
        _;
    }

    function testReverParticipateWhenWalletNotWhitelisted() external hasBalance(bob, minA * pricePerToken) {
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(IParticipator.IParticipator__Unauthorized.selector, "Wallet not allowed")
        );
        participator.participate{value: minA * pricePerToken}(bob, minA);
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

    function testReverParticipationWithWrongMinOrMax()
        external
        hasBalance(bob, maxA * pricePerToken)
        isWhitelisted(bob, 0)
    {
        vm.startPrank(bob);

        vm.expectRevert(
            abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Insufficient number of tokens")
        );
        participator.participate{value: 0}(bob, 0);

        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Amount too low"));
        participator.participate{value: 0}(bob, 1);

        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Amount too high"));
        participator.participate{value: 0}(bob, maxA * 2);

        vm.stopPrank();
    }

    function testCanParticipate() external isWhitelisted(bob, 0) hasBalance(bob, minA * pricePerToken) {
        // WHITELIST A
        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit Allocated(bob, address(0), minA);
        participator.participate{value: minA * pricePerToken}(bob, minA);
        vm.stopPrank();

        assertEq(participator.allocations(bob), minA);
    }

    modifier allocated(address wallet, uint256 numOfTokens) {
        vm.startPrank(wallet);
        participator.participate{value: numOfTokens * pricePerToken}(wallet, numOfTokens);
        vm.stopPrank();
        _;
    }

    function testRevertParticipateWhenReachesWalletLimit()
        external
        isWhitelisted(bob, 0)
        hasBalance(bob, maxA * pricePerToken)
        allocated(bob, maxA)
        hasBalance(bob, minA * pricePerToken)
    {
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Exceeds max allocation permitted")
        );
        participator.participate{value: minA * pricePerToken}(bob, minA);
        vm.stopPrank();
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

    function testCanTopUpAllocationsInPublicPhase()
        external
        isWhitelisted(bob, 0)
        hasBalance(bob, maxA * pricePerToken)
        allocated(bob, maxA)
        whenIsPublic
    {
        assertEq(participator.allocations(bob), maxA);

        vm.startPrank(owner);
        participator.updatePublicMinMaxPerWallet(1, 10);
        vm.stopPrank();

        vm.deal(bob, 5 * pricePerToken);

        vm.startPrank(bob);
        participator.participate{value: 5 * pricePerToken}(bob, 5);
        vm.stopPrank();

        assertEq(participator.allocations(bob), 10);
    }

    function testOwnerCanWithdraw()
        external
        isWhitelisted(bob, 0)
        hasBalance(bob, minA * pricePerToken)
        allocated(bob, minA)
        isWhitelisted(mary, 0)
        hasBalance(mary, minA * pricePerToken)
        allocated(mary, minA)
    {
        uint256 contractBalanceBefore = address(participator).balance;
        uint256 ownerBalanceBefore = address(owner).balance;

        vm.startPrank(owner);
        participator.withdraw();
        vm.stopPrank();

        uint256 contractBalanceAfter = address(participator).balance;
        uint256 ownerBalanceAfter = address(owner).balance;

        assertEq(contractBalanceAfter, 0);
        assertEq(ownerBalanceAfter, ownerBalanceBefore + contractBalanceBefore);
    }

    function testUpdatePrice() external {
        vm.startPrank(owner);
        uint256 priceExpected = pricePerToken * 2;
        participator.updatePricePerToken(priceExpected);
        vm.stopPrank();

        assertEq(participator.pricePerToken(), priceExpected);
    }
}
