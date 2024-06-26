// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console2} from "forge-std/console2.sol";
import {IDO} from "../src/IDO.sol";
import {DeployIDO} from "../script/DeployIDO.s.sol";
import {ERC20Mock} from "../lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {IIDO} from "../src/interfaces/IIDO.sol";

contract IDOTokensTest is Test {
    uint256 fork;
    string public RPC_URL;

    DeployIDO deployer;
    IDO ido;

    address owner;
    address bob;
    address mary;
    address randomUSDCHolder;
    address walletInTiers;

    address acceptedToken;
    uint256 min;
    uint256 max;
    uint256 registrationAt;
    uint256 participationStartsAt;
    uint256 participationEndsAt;
    uint256 vestingAt;
    uint256 cliff;
    IIDO.ReleaseSchedule releaseSchedule;
    uint256 tokenPrice;
    uint256 maxAllocations;
    uint256 tgeReleasePercent;
    IIDO.WalletRange[] public ranges;

    event Allocated(address indexed wallet, address token, uint256 amount);
    event Whitelisted(address[] addresses);
    event Blacklisted(address wallet);

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployIDO();
        ido = deployer.runForTests(false, true);
        owner = ido.owner();
        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");

        randomUSDCHolder = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
        walletInTiers = 0xC2a96B13a975c656f60f401a5F72851af4717D4A;
        vm.label(randomUSDCHolder, "randomUSDCHolder");

        acceptedToken = ido.acceptedTokens(0);

        (tokenPrice, maxAllocations, tgeReleasePercent) = ido.amounts();
        (registrationAt, participationStartsAt, participationEndsAt, vestingAt, cliff, releaseSchedule) = ido.periods();
    }

    function testConstructor() public {
        uint256 rightNow = block.timestamp;
        assertEq(ido.owner(), owner);
        assertEq(ido.acceptedTokens(0), vm.envAddress("BASE_USDC_ADDRESS"));
        assertFalse(ido.samuraiTiers() == address(0));
        assertTrue(maxAllocations > 0);
        assertTrue(ido.rangesLength() == 6);
        assertEq(tokenPrice, 0.013e6);
        assertEq(maxAllocations, 50_000e6);
        assertEq(tgeReleasePercent, 8);
        assertEq(registrationAt, rightNow);
        assertEq(participationStartsAt, rightNow + 1 days);
        assertEq(participationEndsAt, rightNow + 2 days);
        assertEq(vestingAt, rightNow + 10 days);
        assertEq(cliff, 30 days);

        IIDO.WalletRange memory range1 = IIDO.WalletRange("Public", 100e6, 5_000e6);
        IIDO.WalletRange memory range2 = IIDO.WalletRange("Ronin", 100e6, 100e6);
        IIDO.WalletRange memory range3 = IIDO.WalletRange("Gokenin", 100e6, 200e6);
        IIDO.WalletRange memory range4 = IIDO.WalletRange("Goshi", 100e6, 400e6);
        IIDO.WalletRange memory range5 = IIDO.WalletRange("Hatamoto", 100e6, 800e6);
        IIDO.WalletRange memory range6 = IIDO.WalletRange("Shogun", 100e6, 1_500e6);

        uint256 totalOfRanges = ido.rangesLength();

        for (uint256 i = 0; i < totalOfRanges; i++) {
            IIDO.WalletRange memory range = ido.getRange(i);

            ranges.push(range);

            assertEq(range.name, ranges[i].name);
            assertEq(range.min, ranges[i].min);
            assertEq(range.max, ranges[i].max);
        }
    }

    // LINK WALLET

    function testRevertLinkingWalletWithBlankString() external {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Invalid.selector, "Invalid address"));
        ido.linkWallet("");
        vm.stopPrank();
    }

    function testCanLinkWallet() external {
        string memory walletToLink = "67aL4e2LBSbPeC9aLuw4y8tqTqKwuHDEhmRPTmYHKytK";
        vm.startPrank(bob);
        ido.linkWallet(walletToLink);
        vm.stopPrank();

        assertEq(ido.linkedWallets(bob), walletToLink);
    }

    modifier walletLinked(address wallet) {
        vm.startPrank(wallet);
        ido.linkWallet("67aL4e2LBSbPeC9aLuw4y8tqTqKwuHDEhmRPTmYHKytK");
        vm.stopPrank();
        _;
    }

    // REGISTERING TO WHITELIST

    function testRevertRegistration() external walletLinked(bob) {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Unauthorized.selector, "Not allowed to register"));
        ido.register();

        vm.stopPrank();
    }

    function testCanRegisterToWhitelist() external walletLinked(walletInTiers) {
        vm.startPrank(walletInTiers);
        ido.register();
        vm.stopPrank();

        assertEq(ido.whitelist(walletInTiers), true);
    }

    // PARTICIPATING

    function testRevertParticipationWhenNotRegistered() external walletLinked(bob) inParticipationPeriod {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Unauthorized.selector, "Wallet not allowed"));
        ido.participate(acceptedToken, 0);
        vm.stopPrank();
    }

    modifier isWhitelisted(address wallet) {
        vm.startPrank(wallet);
        ido.register();
        vm.stopPrank();
        _;
    }

    function testRevertParticipationWithZeroAddress()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        inParticipationPeriod
    {
        vm.startPrank(walletInTiers);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Invalid.selector, "Invalid Token"));
        ido.participate(address(0), 0);
        vm.stopPrank();
    }

    function testRevertParticipationWithNonPermittedAmounts()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        inParticipationPeriod
    {
        IIDO.WalletRange memory walletRange = ido.getWalletRange(walletInTiers);

        vm.startPrank(walletInTiers);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Invalid.selector, "Amount too low"));
        ido.participate(acceptedToken, walletRange.min / 2);

        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Invalid.selector, "Amount too high"));
        ido.participate(acceptedToken, walletRange.max * 2);
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

    modifier inParticipationPeriod() {
        vm.warp(participationStartsAt + 2 hours);
        _;
    }

    function testCanParticipate()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, acceptedToken, ido.getWalletRange(walletInTiers).min)
        inParticipationPeriod
    {
        IIDO.WalletRange memory walletRange = ido.getWalletRange(walletInTiers);
        uint256 amountToParticipate = walletRange.min;

        vm.startPrank(walletInTiers);
        ERC20(acceptedToken).approve(address(ido), amountToParticipate);
        vm.expectEmit(true, true, true, true);
        emit IIDO.Participated(walletInTiers, acceptedToken, amountToParticipate);
        ido.participate(acceptedToken, amountToParticipate);
        vm.stopPrank();

        assertEq(ido.allocations(walletInTiers), amountToParticipate);
        assertEq(ido.raised(), amountToParticipate);
    }

    modifier participated(address wallet, address token, uint256 amount) {
        vm.startPrank(wallet);
        ERC20(token).approve(address(ido), amount);
        ido.participate(token, amount);
        vm.stopPrank();
        _;
    }

    modifier isPublic() {
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IIDO.PublicAllowed();
        ido.makePublic();
        vm.stopPrank();

        assertTrue(ido.isPublic());
        _;
    }

    function testRevertParticipationWhenExceedsLimit()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, acceptedToken, ido.getWalletRange(walletInTiers).min)
        inParticipationPeriod
        participated(walletInTiers, acceptedToken, ido.getWalletRange(walletInTiers).min)
    {
        IIDO.WalletRange memory walletRange = ido.getWalletRange(walletInTiers);
        uint256 amountToParticipate = walletRange.max;
        vm.startPrank(walletInTiers);
        ERC20(acceptedToken).approve(address(ido), amountToParticipate);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Invalid.selector, "Exceeds max allocation permitted"));
        ido.participate(acceptedToken, amountToParticipate);
        vm.stopPrank();
    }

    function testWhitelistedCanTopUpWhenIsPublic()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, acceptedToken, ido.getWalletRange(walletInTiers).max)
        inParticipationPeriod
        participated(walletInTiers, acceptedToken, ido.getWalletRange(walletInTiers).max)
    {
        assertEq(ido.allocations(walletInTiers), ido.getWalletRange(walletInTiers).max);

        IIDO.WalletRange memory range = ido.getRange(0);
        uint256 amountToTopUp = range.max - ido.allocations(walletInTiers);

        vm.startPrank(owner);
        ido.makePublic();
        vm.stopPrank();

        vm.startPrank(randomUSDCHolder);
        ERC20(acceptedToken).transfer(walletInTiers, amountToTopUp);
        vm.stopPrank();

        vm.startPrank(walletInTiers);
        ERC20(acceptedToken).approve(address(ido), amountToTopUp);
        ido.participate(acceptedToken, amountToTopUp);
        vm.stopPrank();

        assertEq(ido.allocations(walletInTiers), range.max);
    }

    function testRevertNonWhitelistedsInPublicRoundWithoutLinkedWallet()
        external
        isPublic
        hasBalance(bob, acceptedToken, ido.getRange(0).max)
        inParticipationPeriod
    {
        IIDO.WalletRange memory walletRange = ido.getWalletRange(bob);
        uint256 amountToParticipate = walletRange.max;

        vm.startPrank(bob);
        ERC20(acceptedToken).approve(address(ido), amountToParticipate);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Unauthorized.selector, "Linked wallet not found"));
        ido.participate(acceptedToken, amountToParticipate);
        vm.stopPrank();
    }

    function testNonWhitelistedCanParticipateInPublicRound()
        external
        walletLinked(bob)
        isPublic
        hasBalance(bob, acceptedToken, ido.getRange(0).max)
        inParticipationPeriod
    {
        IIDO.WalletRange memory walletRange = ido.getWalletRange(bob);
        uint256 amountToParticipate = walletRange.max;

        vm.startPrank(bob);
        ERC20(acceptedToken).approve(address(ido), amountToParticipate);
        vm.expectEmit(true, true, true, true);
        emit IIDO.Participated(bob, acceptedToken, amountToParticipate);
        ido.participate(acceptedToken, amountToParticipate);
        vm.stopPrank();

        assertEq(ido.allocations(bob), amountToParticipate);
    }

    function testCanSetNewRanges() external {
        uint256 numberOfRanges = ido.rangesLength();

        IIDO.WalletRange[] memory oldRanges = new IIDO.WalletRange[](numberOfRanges);
        IIDO.WalletRange[] memory newRanges = new IIDO.WalletRange[](numberOfRanges);

        // Deep copy oldRanges
        for (uint256 i = 0; i < numberOfRanges; i++) {
            oldRanges[i] =
                IIDO.WalletRange({name: ido.getRange(i).name, min: ido.getRange(i).min, max: ido.getRange(i).max});
        }

        for (uint256 i = 0; i < numberOfRanges; i++) {
            newRanges[i] = IIDO.WalletRange({
                name: ido.getRange(i).name,
                min: ido.getRange(i).min * 2,
                max: ido.getRange(i).max * 2
            });
        }

        vm.startPrank(owner);
        ido.setRanges(newRanges);
        vm.stopPrank();

        for (uint256 i = 0; i < oldRanges.length; i++) {
            IIDO.WalletRange memory updatedRange = ido.getRange(i);

            assertEq(updatedRange.min, oldRanges[i].min * 2);
            assertEq(updatedRange.max, oldRanges[i].max * 2);
        }
    }

    function testCanWithdrawRaisedAmount()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, acceptedToken, ido.getWalletRange(walletInTiers).min)
        inParticipationPeriod
        participated(walletInTiers, acceptedToken, ido.getWalletRange(walletInTiers).min)
    {
        uint256 tokenBalanceBefore = ERC20(acceptedToken).balanceOf(address(ido));
        uint256 tokenOwnerBalanceBefore = ERC20(acceptedToken).balanceOf(owner);

        vm.startPrank(owner);
        ido.withdraw();
        vm.stopPrank();

        uint256 tokenBalanceAfter = ERC20(acceptedToken).balanceOf(address(ido));
        uint256 tokenOwnerBalanceAfter = ERC20(acceptedToken).balanceOf(owner);

        assertEq(tokenBalanceAfter, 0);
        assertEq(tokenOwnerBalanceAfter, tokenOwnerBalanceBefore + tokenBalanceBefore);
    }
}
