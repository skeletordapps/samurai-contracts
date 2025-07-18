// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/console.sol";
import {ParticipatorV2} from "../../../src/ParticipatorV2.sol";
import {DeployParticipatorV2} from "../../../script/DeployParticipatorV2.s.sol";
import {ERC20Mock} from "../../../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IParticipator} from "../../../src/interfaces/IParticipator.sol";

contract ParticipatorV2ETHTest is Test {
    uint256 fork;
    string public RPC_URL;

    DeployParticipatorV2 deployer;
    ParticipatorV2 participator;

    address owner;
    address bob;
    address mary;
    address randomUSDCHolder;
    address walletInTiers;

    address acceptedToken;
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

        deployer = new DeployParticipatorV2();
        participator = deployer.runForTests(true, false);
        owner = participator.owner();
        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");

        randomUSDCHolder = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
        walletInTiers = 0xe6383dfABb171242D1f485FAA20DdF875eF7a5ED;
        vm.label(randomUSDCHolder, "randomUSDCHolder");

        maxAllocations = participator.maxAllocations();
    }

    function testConstructor() public view {
        assertEq(participator.owner(), owner);
        assertEq(participator.acceptedTokensLength(), 0);
        assertFalse(participator.samuraiTiers() == address(0));
        assertTrue(participator.maxAllocations() > 0);
        assertTrue(participator.rangesLength() == 6);
    }

    // LINK WALLET
    function testRevertLinkingWalletWhenNotUsingIt() external {
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(IParticipator.IParticipator__Unauthorized.selector, "Not using linked wallets")
        );
        participator.linkWallet("67aL4e2LBSbPeC9aLuw4y8tqTqKwuHDEhmRPTmYHKytK");
        vm.stopPrank();
    }

    // REGISTERING TO WHITELIST

    function testRevertRegisterToWhitelist() external {
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(IParticipator.IParticipator__Unauthorized.selector, "Not allowed to whitelist")
        );
        participator.registerToWhitelist();
        vm.stopPrank();
    }

    function testCanRegisterToWhitelist() external {
        vm.startPrank(walletInTiers);
        vm.expectEmit(true, true, true, true);
        emit IParticipator.Whitelisted(walletInTiers);
        participator.registerToWhitelist();
        vm.stopPrank();

        assertEq(participator.whitelist(walletInTiers), true);
    }

    // PARTICIPATING

    function testRevertParticipationWhenNotWhitelisted() external {
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(IParticipator.IParticipator__Unauthorized.selector, "Wallet not allowed")
        );
        participator.participateETH{value: 0 ether}(0);
        vm.stopPrank();
    }

    modifier isWhitelisted(address wallet) {
        vm.startPrank(wallet);
        participator.registerToWhitelist();
        vm.stopPrank();
        _;
    }

    function testRevertParticipationNonPermittedAmounts() external isWhitelisted(walletInTiers) {
        IParticipator.WalletRange memory walletRange = participator.getWalletRange(walletInTiers);

        vm.deal(walletInTiers, walletRange.max * 2);

        vm.startPrank(walletInTiers);
        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Amount too low"));
        participator.participateETH{value: walletRange.min / 2}(walletRange.min / 2);

        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Amount too high"));
        participator.participateETH{value: walletRange.max * 2}(walletRange.max * 2);
        vm.stopPrank();
    }

    modifier hasBalance(address wallet, uint256 amount) {
        vm.deal(wallet, amount);
        _;
    }

    function testCanParticipate()
        external
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, participator.getWalletRange(walletInTiers).min)
    {
        IParticipator.WalletRange memory walletRange = participator.getWalletRange(walletInTiers);
        uint256 amountToParticipate = walletRange.min;

        vm.startPrank(walletInTiers);
        vm.expectEmit(true, true, true, true);
        emit IParticipator.Allocated(walletInTiers, address(0), amountToParticipate);
        participator.participateETH{value: amountToParticipate}(amountToParticipate);
        vm.stopPrank();

        assertEq(participator.allocations(walletInTiers), amountToParticipate);
        assertEq(participator.raised(), amountToParticipate);
    }

    modifier participated(address wallet, uint256 amount) {
        vm.startPrank(wallet);
        participator.participateETH{value: amount}(amount);
        vm.stopPrank();
        _;
    }

    function testRevertParticipationWhenExceedsLimit()
        external
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, participator.getWalletRange(walletInTiers).min)
        participated(walletInTiers, participator.getWalletRange(walletInTiers).min)
    {
        IParticipator.WalletRange memory walletRange = participator.getWalletRange(walletInTiers);
        uint256 amountToParticipate = walletRange.max;
        vm.deal(walletInTiers, amountToParticipate);
        vm.startPrank(walletInTiers);
        vm.expectRevert(
            abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Exceeds max allocation permitted")
        );
        participator.participateETH{value: amountToParticipate}(amountToParticipate);
        vm.stopPrank();
    }

    modifier isPublic() {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IParticipator.PublicAllowed();
        participator.makePublic();
        vm.stopPrank();

        assertTrue(participator.isPublic());
        _;
    }

    function testNonWhitelistedCanParticipateInPublicRound()
        external
        isPublic
        hasBalance(bob, participator.getRange(0).max)
    {
        IParticipator.WalletRange memory publicRange = participator.getRange(0);

        uint256 amountToParticipate = publicRange.max;

        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit IParticipator.Allocated(bob, address(0), amountToParticipate);
        participator.participateETH{value: amountToParticipate}(amountToParticipate);
        vm.stopPrank();

        assertEq(participator.allocations(bob), amountToParticipate);
    }

    function testWhitelistedCanTopUpWhenIsPublic()
        external
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, participator.getWalletRange(walletInTiers).max)
        participated(walletInTiers, participator.getWalletRange(walletInTiers).max)
    {
        assertEq(participator.allocations(walletInTiers), participator.getWalletRange(walletInTiers).max);

        IParticipator.WalletRange memory range = participator.getRange(0);
        uint256 amountToTopUp = range.max - participator.allocations(walletInTiers);

        vm.startPrank(owner);
        participator.makePublic();
        vm.stopPrank();

        vm.deal(walletInTiers, amountToTopUp);

        vm.startPrank(walletInTiers);
        participator.participateETH{value: amountToTopUp}(amountToTopUp);
        vm.stopPrank();

        assertEq(participator.allocations(walletInTiers), range.max);
    }

    function testCanSetNewRanges() external {
        uint256 numberOfRanges = participator.rangesLength();

        IParticipator.WalletRange[] memory oldRanges = new IParticipator.WalletRange[](numberOfRanges);
        IParticipator.WalletRange[] memory newRanges = new IParticipator.WalletRange[](numberOfRanges);

        // Deep copy oldRanges
        for (uint256 i = 0; i < numberOfRanges; i++) {
            oldRanges[i] = IParticipator.WalletRange({
                name: participator.getRange(i).name,
                min: participator.getRange(i).min,
                max: participator.getRange(i).max
            });
        }

        for (uint256 i = 0; i < numberOfRanges; i++) {
            newRanges[i] = IParticipator.WalletRange({
                name: participator.getRange(i).name,
                min: participator.getRange(i).min * 2,
                max: participator.getRange(i).max * 2
            });
        }

        vm.startPrank(owner);
        participator.setRanges(newRanges);
        vm.stopPrank();

        for (uint256 i = 0; i < oldRanges.length; i++) {
            IParticipator.WalletRange memory updatedRange = participator.getRange(i);

            assertEq(updatedRange.min, oldRanges[i].min * 2);
            assertEq(updatedRange.max, oldRanges[i].max * 2);
        }
    }

    function testCanWithdrawRaisedAmount()
        external
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, participator.getWalletRange(walletInTiers).min)
        participated(walletInTiers, participator.getWalletRange(walletInTiers).min)
    {
        uint256 contractBalanceBefore = address(participator).balance;
        uint256 ownerBalanceBefore = owner.balance;

        vm.startPrank(owner);
        participator.withdraw();
        vm.stopPrank();

        uint256 contractBalanceAfter = address(participator).balance;
        uint256 ownerBalanceAfter = owner.balance;

        assertEq(contractBalanceAfter, 0);
        assertEq(ownerBalanceAfter, ownerBalanceBefore + contractBalanceBefore);
    }
}
