// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/console.sol";
import {ParticipatorV2} from "../src/ParticipatorV2.sol";
import {DeployParticipatorV2} from "../script/DeployParticipatorV2.s.sol";
import {ERC20Mock} from "../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IParticipator} from "../src/interfaces/IParticipator.sol";

contract ParticipatorV2TokensTest is Test {
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
        participator = deployer.runForTests(false, true);
        owner = participator.owner();
        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");

        randomUSDCHolder = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
        walletInTiers = 0xC2a96B13a975c656f60f401a5F72851af4717D4A;
        vm.label(randomUSDCHolder, "randomUSDCHolder");

        acceptedToken = participator.acceptedTokens(0);
        maxAllocations = participator.maxAllocations();
    }

    function testConstructor() public view {
        assertEq(participator.owner(), owner);
        assertEq(participator.acceptedTokens(0), vm.envAddress("BASE_USDC_ADDRESS"));
        assertFalse(participator.samuraiTiers() == address(0));
        assertTrue(participator.maxAllocations() > 0);
        assertTrue(participator.rangesLength() == 6);
    }

    // LINK WALLET

    function testRevertLinkingWalletWithBlankString() external {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Invalid address"));
        participator.linkWallet("");
        vm.stopPrank();
    }

    function testCanLinkWallet() external {
        string memory walletToLink = "67aL4e2LBSbPeC9aLuw4y8tqTqKwuHDEhmRPTmYHKytK";
        vm.startPrank(bob);
        participator.linkWallet(walletToLink);
        vm.stopPrank();

        assertEq(participator.linkedWallets(bob), walletToLink);
    }

    modifier walletLinked(address wallet) {
        vm.startPrank(wallet);
        participator.linkWallet("67aL4e2LBSbPeC9aLuw4y8tqTqKwuHDEhmRPTmYHKytK");
        vm.stopPrank();
        _;
    }

    // REGISTERING TO WHITELIST

    function testRevertRegisterToWhitelist() external walletLinked(bob) {
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(IParticipator.IParticipator__Unauthorized.selector, "Not allowed to whitelist")
        );
        participator.registerToWhitelist();

        vm.stopPrank();
    }

    function testCanRegisterToWhitelist() external walletLinked(walletInTiers) {
        vm.startPrank(walletInTiers);
        participator.registerToWhitelist();
        vm.stopPrank();

        assertEq(participator.whitelist(walletInTiers), true);
    }

    // PARTICIPATING

    function testRevertParticipationWhenNotWhitelisted() external walletLinked(bob) {
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(IParticipator.IParticipator__Unauthorized.selector, "Wallet not allowed")
        );
        participator.participate(acceptedToken, 0);
        vm.stopPrank();
    }

    modifier isWhitelisted(address wallet) {
        vm.startPrank(wallet);
        participator.registerToWhitelist();
        vm.stopPrank();
        _;
    }

    function testRevertParticipationWithZeroAddress()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
    {
        vm.startPrank(walletInTiers);
        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Invalid Token"));
        participator.participate(address(0), 0);
        vm.stopPrank();
    }

    function testRevertParticipationNonPermittedAmounts()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
    {
        IParticipator.WalletRange memory walletRange = participator.getWalletRange(walletInTiers);

        vm.startPrank(walletInTiers);
        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Amount too low"));
        participator.participate(acceptedToken, walletRange.min / 2);

        vm.expectRevert(abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Amount too high"));
        participator.participate(acceptedToken, walletRange.max * 2);
        vm.stopPrank();
    }

    modifier hasBalance(address wallet, address token, uint256 amount) {
        if (keccak256(abi.encodePacked(ERC20(token).symbol())) == keccak256(abi.encodePacked("USDC"))) {
            vm.startPrank(randomUSDCHolder);
            ERC20(token).transfer(wallet, amount);
            vm.stopPrank();
        } else {
            deal(token, wallet, amount);
        }
        _;
    }

    function testCanParticipate()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, acceptedToken, participator.getWalletRange(walletInTiers).min)
    {
        IParticipator.WalletRange memory walletRange = participator.getWalletRange(walletInTiers);
        uint256 amountToParticipate = walletRange.min;

        vm.startPrank(walletInTiers);
        ERC20(acceptedToken).approve(address(participator), amountToParticipate);
        vm.expectEmit(true, true, true, true);
        emit IParticipator.Allocated(walletInTiers, acceptedToken, amountToParticipate);
        participator.participate(acceptedToken, amountToParticipate);
        vm.stopPrank();

        assertEq(participator.allocations(walletInTiers), amountToParticipate);
        assertEq(participator.raised(), amountToParticipate);
    }

    modifier participated(address wallet, address token, uint256 amount) {
        vm.startPrank(wallet);
        ERC20(token).approve(address(participator), amount);
        participator.participate(token, amount);
        vm.stopPrank();
        _;
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

    function testRevertParticipationWhenExceedsLimit()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, acceptedToken, participator.getWalletRange(walletInTiers).min)
        participated(walletInTiers, acceptedToken, participator.getWalletRange(walletInTiers).min)
    {
        IParticipator.WalletRange memory walletRange = participator.getWalletRange(walletInTiers);
        uint256 amountToParticipate = walletRange.max;
        vm.startPrank(walletInTiers);
        ERC20(acceptedToken).approve(address(participator), amountToParticipate);
        vm.expectRevert(
            abi.encodeWithSelector(IParticipator.IParticipator__Invalid.selector, "Exceeds max allocation permitted")
        );
        participator.participate(acceptedToken, amountToParticipate);
        vm.stopPrank();
    }

    function testWhitelistedCanTopUpWhenIsPublic()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, acceptedToken, participator.getWalletRange(walletInTiers).max)
        participated(walletInTiers, acceptedToken, participator.getWalletRange(walletInTiers).max)
    {
        assertEq(participator.allocations(walletInTiers), participator.getWalletRange(walletInTiers).max);

        IParticipator.WalletRange memory range = participator.getRange(0);
        uint256 amountToTopUp = range.max - participator.allocations(walletInTiers);

        vm.startPrank(owner);
        participator.makePublic();
        vm.stopPrank();

        vm.startPrank(randomUSDCHolder);
        ERC20(acceptedToken).transfer(walletInTiers, amountToTopUp);
        vm.stopPrank();

        vm.startPrank(walletInTiers);
        ERC20(acceptedToken).approve(address(participator), amountToTopUp);
        participator.participate(acceptedToken, amountToTopUp);
        vm.stopPrank();

        assertEq(participator.allocations(walletInTiers), range.max);
    }

    function testRevertNonWhitelistedsInPublicRoundWithoutLinkedWallet()
        external
        isPublic
        hasBalance(bob, acceptedToken, participator.getRange(0).max)
    {
        IParticipator.WalletRange memory walletRange = participator.getWalletRange(bob);
        uint256 amountToParticipate = walletRange.max;

        vm.startPrank(bob);
        ERC20(acceptedToken).approve(address(participator), amountToParticipate);
        vm.expectRevert(
            abi.encodeWithSelector(IParticipator.IParticipator__Unauthorized.selector, "Linked wallet not found")
        );
        participator.participate(acceptedToken, amountToParticipate);
        vm.stopPrank();
    }

    function testNonWhitelistedCanParticipateInPublicRound()
        external
        walletLinked(bob)
        isPublic
        hasBalance(bob, acceptedToken, participator.getRange(0).max)
    {
        IParticipator.WalletRange memory walletRange = participator.getWalletRange(bob);
        uint256 amountToParticipate = walletRange.max;

        vm.startPrank(bob);
        ERC20(acceptedToken).approve(address(participator), amountToParticipate);
        vm.expectEmit(true, true, true, true);
        emit IParticipator.Allocated(bob, acceptedToken, amountToParticipate);
        participator.participate(acceptedToken, amountToParticipate);
        vm.stopPrank();

        assertEq(participator.allocations(bob), amountToParticipate);
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
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, acceptedToken, participator.getWalletRange(walletInTiers).min)
        participated(walletInTiers, acceptedToken, participator.getWalletRange(walletInTiers).min)
    {
        uint256 tokenBalanceBefore = ERC20(acceptedToken).balanceOf(address(participator));
        uint256 tokenOwnerBalanceBefore = ERC20(acceptedToken).balanceOf(owner);

        vm.startPrank(owner);
        participator.withdraw();
        vm.stopPrank();

        uint256 tokenBalanceAfter = ERC20(acceptedToken).balanceOf(address(participator));
        uint256 tokenOwnerBalanceAfter = ERC20(acceptedToken).balanceOf(owner);

        assertEq(tokenBalanceAfter, 0);
        assertEq(tokenOwnerBalanceAfter, tokenOwnerBalanceBefore + tokenBalanceBefore);
    }
}
