// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/console.sol";
import {IDO} from "../src/IDO.sol";
import {DeployIDO} from "../script/DeployIDO.s.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {IIDO} from "../src/interfaces/IIDO.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";

contract IDOEtherTest is Test {
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
    uint256 vestingDuration;
    uint256 vestingAt;
    uint256 cliff;
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
        ido = deployer.runForTests(true, true);
        owner = ido.owner();
        acceptedToken = ido.acceptedToken();
        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");

        walletInTiers = 0xC2a96B13a975c656f60f401a5F72851af4717D4A;

        (tokenPrice, maxAllocations, tgeReleasePercent) = ido.amounts();
        uint256 numberOfRanges = ido.rangesLength();
        for (uint256 i = 0; i < numberOfRanges; i++) {
            ranges.push(ido.getRange(i));
        }
        (registrationAt, participationStartsAt, participationEndsAt, vestingDuration, vestingAt, cliff) = ido.periods();
    }

    function testConstructor() public {
        uint256 rightNow = block.timestamp;
        assertEq(ido.owner(), owner);
        assertTrue(ido.usingETH());
        assertEq(ido.acceptedToken(), address(0));
        assertFalse(ido.samuraiTiers() == address(0));
        assertTrue(maxAllocations > 0);
        assertTrue(ido.rangesLength() == 6);
        assertEq(tokenPrice, 0.013e18);
        assertEq(maxAllocations, 50_000 ether);
        assertEq(tgeReleasePercent, 0.08e18);
        assertEq(registrationAt, rightNow);
        assertEq(participationStartsAt, rightNow + 1 days);
        assertEq(participationEndsAt, rightNow + 2 days);
        assertEq(vestingAt, 0);
        assertEq(cliff, 0);

        IIDO.WalletRange[] memory expectedRanges = new IIDO.WalletRange[](6);
        expectedRanges[0] = IIDO.WalletRange("Public", 0.1 ether, 5 ether);
        expectedRanges[1] = IIDO.WalletRange("Ronin", 0.1 ether, 0.1 ether);
        expectedRanges[2] = IIDO.WalletRange("Gokenin", 0.1 ether, 0.5 ether);
        expectedRanges[3] = IIDO.WalletRange("Goshi", 0.1 ether, 0.7 ether);
        expectedRanges[4] = IIDO.WalletRange("Hatamoto", 0.1 ether, 1.4 ether);
        expectedRanges[5] = IIDO.WalletRange("Shogun", 0.1 ether, 2 ether);

        uint256 totalOfRanges = ido.rangesLength();

        for (uint256 i = 0; i < totalOfRanges; i++) {
            IIDO.WalletRange memory range = ido.getRange(i);
            ranges.push(range);

            assertEq(range.name, expectedRanges[i].name);
            assertEq(range.min, expectedRanges[i].min);
            assertEq(range.max, expectedRanges[i].max);
        }

        bool refundable = true;
        uint256 refundPercent = 0.01e18;
        uint256 refundPeriod = 24 hours;
        (bool active, uint256 feePercent, uint256 period) = ido.refund();

        assertEq(active, refundable);
        assertEq(feePercent, refundPercent);
        assertEq(period, refundPeriod);
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

    modifier isWhitelisted(address wallet) {
        vm.startPrank(wallet);
        ido.register();
        vm.stopPrank();
        _;
    }

    // PARTICIPATING

    modifier inParticipationPeriod() {
        vm.warp(participationStartsAt + 2 hours);
        _;
    }

    function testRevertParticipationWhenNotRegistered() external walletLinked(bob) inParticipationPeriod {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Unauthorized.selector, "Wallet not allowed"));
        ido.participateETH{value: 0}(0);
        vm.stopPrank();
    }

    modifier hasBalance(address wallet, uint256 amount) {
        vm.deal(wallet, amount);
        _;
    }

    function testRevertParticipationETHWithNonPermittedAmounts()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        inParticipationPeriod
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).max * 2)
    {
        IIDO.WalletRange memory walletRange = ido.getWalletRange(walletInTiers);

        vm.startPrank(walletInTiers);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Invalid.selector, "Amount too low"));
        ido.participateETH{value: walletRange.min / 2}(walletRange.min / 2);

        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Invalid.selector, "Amount too high"));
        ido.participateETH{value: walletRange.max * 2}(walletRange.max * 2);
        vm.stopPrank();
    }

    function testCanParticipateETH()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).min)
        inParticipationPeriod
    {
        IIDO.WalletRange memory walletRange = ido.getWalletRange(walletInTiers);
        uint256 amountToParticipate = walletRange.min;

        vm.startPrank(walletInTiers);
        vm.expectEmit(true, true, true, true);
        emit IIDO.Participated(walletInTiers, address(0), amountToParticipate);
        ido.participateETH{value: amountToParticipate}(amountToParticipate);
        vm.stopPrank();

        assertEq(ido.allocations(walletInTiers), amountToParticipate);
        assertEq(ido.raised(), amountToParticipate);
    }

    modifier participated(address wallet, uint256 amount) {
        vm.startPrank(wallet);
        ido.participateETH{value: amount}(amount);
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
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).max * 2)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).min)
    {
        IIDO.WalletRange memory walletRange = ido.getWalletRange(walletInTiers);
        uint256 amountToParticipate = walletRange.max;
        vm.startPrank(walletInTiers);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Invalid.selector, "Exceeds max allocation permitted"));
        ido.participateETH{value: amountToParticipate}(amountToParticipate);
        vm.stopPrank();
    }

    function testWhitelistedCanTopUpWhenIsPublic()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).max)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).max)
    {
        assertEq(ido.allocations(walletInTiers), ido.getWalletRange(walletInTiers).max);

        IIDO.WalletRange memory range = ido.getRange(0);
        uint256 amountToTopUp = range.max - ido.allocations(walletInTiers);

        vm.startPrank(owner);
        ido.makePublic();
        vm.stopPrank();

        vm.deal(walletInTiers, amountToTopUp);

        vm.startPrank(walletInTiers);
        ido.participateETH{value: amountToTopUp}(amountToTopUp);
        vm.stopPrank();

        assertEq(ido.allocations(walletInTiers), range.max);
    }

    function testRevertNonWhitelistedsInPublicRoundWithoutLinkedWallet()
        external
        isPublic
        hasBalance(bob, ido.getRange(0).max)
        inParticipationPeriod
    {
        IIDO.WalletRange memory walletRange = ido.getWalletRange(bob);
        uint256 amountToParticipate = walletRange.max;

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Unauthorized.selector, "Linked wallet not found"));
        ido.participateETH{value: amountToParticipate}(amountToParticipate);
        vm.stopPrank();
    }

    function testNonWhitelistedCanParticipateInPublicRound()
        external
        walletLinked(bob)
        isPublic
        hasBalance(bob, ido.getRange(0).max)
        inParticipationPeriod
    {
        IIDO.WalletRange memory walletRange = ido.getWalletRange(bob);
        uint256 amountToParticipate = walletRange.max;

        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit IIDO.Participated(bob, acceptedToken, amountToParticipate);
        ido.participateETH{value: amountToParticipate}(amountToParticipate);
        vm.stopPrank();

        assertEq(ido.allocations(bob), amountToParticipate);
    }

    /// AMOUNTS

    function testRevertSetAmountsWithLowerTokenPrice() external {
        IIDO.Amounts memory newAmounts =
            IIDO.Amounts({tokenPrice: 0, maxAllocations: maxAllocations, tgeReleasePercent: tgeReleasePercent});

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Invalid.selector, "Cannot update with a lower tokenPrice"));
        ido.setAmounts(newAmounts);
        vm.stopPrank();
    }

    function testRevertSetAmountsWithLowerMaxAllocations() external {
        IIDO.Amounts memory newAmounts =
            IIDO.Amounts({tokenPrice: tokenPrice, maxAllocations: 20_000 ether, tgeReleasePercent: tgeReleasePercent});

        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IIDO.IIDO__Invalid.selector, "Cannot update with a lower maxAllocations")
        );
        ido.setAmounts(newAmounts);
        vm.stopPrank();
    }

    function testRevertSetAmountsWithLowerTGEReleasePercent() external {
        IIDO.Amounts memory newAmounts =
            IIDO.Amounts({tokenPrice: tokenPrice, maxAllocations: maxAllocations, tgeReleasePercent: 0.07e18});

        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(IIDO.IIDO__Invalid.selector, "Cannot update with a lower tgeReleasePercent")
        );
        ido.setAmounts(newAmounts);
        vm.stopPrank();
    }

    function testCanSetNewAmounts() external {
        IIDO.Amounts memory newSameAmounts =
            IIDO.Amounts({tokenPrice: tokenPrice, maxAllocations: maxAllocations, tgeReleasePercent: tgeReleasePercent});

        IIDO.Amounts memory newDoubledAmounts = IIDO.Amounts({
            tokenPrice: tokenPrice * 2,
            maxAllocations: maxAllocations * 2,
            tgeReleasePercent: tgeReleasePercent * 2
        });

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IIDO.AmountsSet(newSameAmounts);
        ido.setAmounts(newSameAmounts);

        vm.expectEmit(true, true, true, true);
        emit IIDO.AmountsSet(newDoubledAmounts);
        ido.setAmounts(newDoubledAmounts);
        vm.stopPrank();
    }

    /// RANGES

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

    /// PERIODS

    function testSetPeriodsRevertWhenRegistrationIsUnderCurrentTimestamp() external {
        IIDO.Periods memory expectedPeriods = IIDO.Periods({
            registrationAt: 0,
            participationStartsAt: participationStartsAt,
            participationEndsAt: participationEndsAt,
            vestingDuration: vestingDuration,
            vestingAt: vestingAt,
            cliff: cliff
        });

        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IIDO.IIDO__Invalid.selector, "New registrationStartsAt cannot be under current stored value"
            )
        );
        ido.setPeriods(expectedPeriods);
        vm.stopPrank();
    }

    function testSetPeriodsRevertWhenParticipationStartsIsUnderRegistrationEndsAt() external {
        IIDO.Periods memory expectedPeriods = IIDO.Periods({
            registrationAt: registrationAt,
            participationStartsAt: 0,
            participationEndsAt: participationEndsAt,
            vestingDuration: vestingDuration,
            vestingAt: vestingAt,
            cliff: cliff
        });

        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IIDO.IIDO__Invalid.selector, "participationStartsAt should be higher than registrationEndsAt"
            )
        );
        ido.setPeriods(expectedPeriods);
        vm.stopPrank();
    }

    function testSetPeriodsRevertWhenParticipationEndsAtIsUnderParticipationStartsAt() external {
        IIDO.Periods memory expectedPeriods = IIDO.Periods({
            registrationAt: registrationAt,
            participationStartsAt: participationStartsAt,
            participationEndsAt: 0,
            vestingDuration: vestingDuration,
            vestingAt: vestingAt,
            cliff: cliff
        });

        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IIDO.IIDO__Invalid.selector, "participationEndsAt should be higher than participationStartsAt"
            )
        );
        ido.setPeriods(expectedPeriods);
        vm.stopPrank();
    }

    function testCanSetPeriods() external {
        (uint256 _registrationAt, uint256 _participationStartsAt, uint256 _participationEndsAt,,,) = ido.periods();

        IIDO.Periods memory expectedPeriods = IIDO.Periods({
            registrationAt: _registrationAt,
            participationStartsAt: _participationStartsAt,
            participationEndsAt: _participationEndsAt,
            vestingDuration: 30 days * 8,
            vestingAt: _participationEndsAt + 10 days,
            cliff: 30 days
        });

        vm.startPrank(owner);
        ido.setPeriods(expectedPeriods);
        vm.stopPrank();

        (
            uint256 _newRegistrationAt,
            uint256 _newParticipationStartsAt,
            uint256 _newParticipationEndsAt,
            uint256 _newVestingDuration,
            uint256 _newVestingAt,
            uint256 _newCliff
        ) = ido.periods();

        assertEq(_newRegistrationAt, expectedPeriods.registrationAt);
        assertEq(_newParticipationStartsAt, expectedPeriods.participationStartsAt);
        assertEq(_newParticipationEndsAt, expectedPeriods.participationEndsAt);
        assertEq(_newVestingDuration, expectedPeriods.vestingDuration);
        assertEq(_newVestingAt, expectedPeriods.vestingAt);
        assertEq(_newCliff, expectedPeriods.cliff);
    }

    modifier periodsSet(uint256 newVestingDuration, uint256 newVestingAt, uint256 cliffDuration) {
        (uint256 _registrationAt, uint256 _participationStartsAt, uint256 _participationEndsAt,,,) = ido.periods();

        IIDO.Periods memory expectedPeriods = IIDO.Periods({
            registrationAt: _registrationAt,
            participationStartsAt: _participationStartsAt,
            participationEndsAt: _participationEndsAt,
            vestingDuration: newVestingDuration,
            vestingAt: newVestingAt,
            cliff: cliffDuration
        });

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IIDO.PeriodsSet(expectedPeriods);
        ido.setPeriods(expectedPeriods);
        vm.stopPrank();

        (registrationAt, participationStartsAt, participationEndsAt, vestingDuration, vestingAt, cliff) = ido.periods();

        _;
    }

    /// When vestingAt is not set
    function testRevertSetPeriodsWhenNewVestingIsUnderParticipationEnd() external {
        IIDO.Periods memory expectedPeriods = IIDO.Periods({
            registrationAt: registrationAt,
            participationStartsAt: participationStartsAt,
            participationEndsAt: participationEndsAt,
            vestingDuration: 30 days * 8,
            vestingAt: participationEndsAt - 2 hours,
            cliff: cliff
        });

        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IIDO.IIDO__Invalid.selector, "New vestingAt value must be greater or equal participationEndsAt"
            )
        );
        ido.setPeriods(expectedPeriods);
        vm.stopPrank();
    }

    /// When vestingAt is already set
    function testRevertSetPeriodsWhenStoredVestingAtIsSetAndNewValueIsUnderParticipationEnd()
        external
        periodsSet(30 days * 8, participationEndsAt + 1 days, 0)
    {
        IIDO.Periods memory expectedPeriods = IIDO.Periods({
            registrationAt: registrationAt,
            participationStartsAt: participationStartsAt,
            participationEndsAt: participationEndsAt,
            vestingDuration: 30 days * 8,
            vestingAt: participationEndsAt - 2 hours,
            cliff: cliff
        });

        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IIDO.IIDO__Invalid.selector, "New vestingAt must be greater or equal than participationEndsAt"
            )
        );
        ido.setPeriods(expectedPeriods);
        vm.stopPrank();
    }

    /// When vestingAt is already set
    function testRevertSetPeriodsWhenVestingAtIsUnderStoredVestingAt()
        external
        periodsSet(30 days * 8, participationEndsAt + 2 days, 0)
    {
        IIDO.Periods memory expectedPeriods = IIDO.Periods({
            registrationAt: registrationAt,
            participationStartsAt: participationStartsAt,
            participationEndsAt: participationEndsAt,
            vestingDuration: 30 days * 8,
            vestingAt: participationEndsAt + 1 days,
            cliff: cliff
        });

        vm.startPrank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                IIDO.IIDO__Invalid.selector, "New vestingAt value must be greater or equal current vestingAt value"
            )
        );
        ido.setPeriods(expectedPeriods);
        vm.stopPrank();
    }

    function testRevertSetPeriodsWhenCliffIsUnderStoredCliff()
        external
        periodsSet(30 days * 8, participationEndsAt + 2 days, 10 days)
    {
        IIDO.Periods memory expectedPeriods = IIDO.Periods({
            registrationAt: registrationAt,
            participationStartsAt: participationStartsAt,
            participationEndsAt: participationEndsAt,
            vestingDuration: 30 days * 8,
            vestingAt: vestingAt,
            cliff: 0
        });

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Invalid.selector, "Invalid cliff"));
        ido.setPeriods(expectedPeriods);
        vm.stopPrank();
    }

    // WITHDRAW RAISED

    function testCanWithdrawRaisedETHAmount()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).min)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).min)
    {
        uint256 balanceBefore = address(ido).balance;
        uint256 ownerBalanceBefore = owner.balance;

        vm.startPrank(owner);
        ido.withdraw();
        vm.stopPrank();

        uint256 balanceAfter = address(ido).balance;
        uint256 ownerBalanceAfter = owner.balance;

        assertEq(balanceAfter, 0);
        assertEq(ownerBalanceAfter, ownerBalanceBefore + balanceBefore);
    }

    // SET IDO TOKEN

    function testCanSetIDOToken() external {
        vm.warp(participationEndsAt + 2 hours);

        ERC20Mock newToken = new ERC20Mock("IDO TOKEN", "IDT");

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IIDO.IDOTokenSet(address(newToken));
        ido.setIDOToken(address(newToken));
        vm.stopPrank();

        assertEq(ido.token(), address(newToken));
    }

    modifier idoTokenSet() {
        vm.warp(participationEndsAt + 2 hours);
        ERC20Mock newToken = new ERC20Mock("IDO TOKEN", "IDT");
        vm.startPrank(owner);
        ido.setIDOToken(address(newToken));
        vm.stopPrank();
        _;
    }

    function testRevertSetIDOTokenIfAlreadySet() external idoTokenSet {
        ERC20Mock newToken = new ERC20Mock("IDO TOKEN 2", "IDT2");

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Unauthorized.selector, "Token already set"));
        ido.setIDOToken(address(newToken));
        vm.stopPrank();
    }

    /// IDO TOKEN FILL

    function testRevertFillIDOTokenWhenTokenNotSet()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).max)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).max)
    {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Unauthorized.selector, "IDO token not set"));
        ido.fillIDOToken(1 ether);
        vm.stopPrank();
    }

    function testRevertFillIDOTokenWhenWithoutParticipations() external idoTokenSet {
        address idoToken = ido.token();
        deal(idoToken, owner, 1 ether);

        vm.startPrank(owner);
        ERC20(idoToken).approve(address(ido), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Unauthorized.selector, "Nothing raised"));
        ido.fillIDOToken(1 ether);
        vm.stopPrank();
    }

    function testCanSendIDOTokenToContract()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).max)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).max)
        idoTokenSet
    {
        vm.warp(participationEndsAt + 30 minutes);

        address idoToken = ido.token();
        uint256 raised = ido.raised();
        uint256 expectedAmountOfTokens = raised / tokenPrice;

        deal(idoToken, owner, expectedAmountOfTokens);

        vm.startPrank(owner);
        ERC20(idoToken).approve(address(ido), expectedAmountOfTokens);

        vm.expectEmit(true, true, true, true);
        emit IIDO.IDOTokensFilled(owner, expectedAmountOfTokens);
        ido.fillIDOToken(expectedAmountOfTokens);
        vm.stopPrank();

        assertEq(ERC20(idoToken).balanceOf(address(ido)), expectedAmountOfTokens);
    }

    modifier idoTokenFilled(bool sendHalf) {
        vm.warp(participationEndsAt + 30 minutes);
        address idoToken = ido.token();
        uint256 raised = ido.raised();
        uint256 expectedAmountOfTokens = ido.tokenAmountByParticipation(raised);

        if (sendHalf) expectedAmountOfTokens = expectedAmountOfTokens / 2;

        deal(idoToken, owner, expectedAmountOfTokens);

        vm.startPrank(owner);
        ERC20(idoToken).approve(address(ido), expectedAmountOfTokens);
        ido.fillIDOToken(expectedAmountOfTokens);
        vm.stopPrank();
        _;
    }

    function testFillInChunks()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).max)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).max)
        idoTokenSet
        idoTokenFilled(true)
    {
        vm.warp(block.timestamp + 5 hours);
        address idoToken = ido.token();
        uint256 partialAmount = ERC20(idoToken).balanceOf(address(ido));
        deal(idoToken, owner, partialAmount);

        vm.startPrank(owner);
        ERC20(idoToken).approve(address(ido), partialAmount);
        ido.fillIDOToken(partialAmount);
        vm.stopPrank();

        assertEq(ERC20(idoToken).balanceOf(address(ido)), partialAmount * 2);
    }

    function testRevertFillIDOTokenTwice()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).max)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).max)
        idoTokenSet
        idoTokenFilled(false)
    {
        address idoToken = ido.token();
        deal(idoToken, owner, 1 ether);

        vm.startPrank(owner);
        ERC20(idoToken).approve(address(ido), 1 ether);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Unauthorized.selector, "Unable to receive more IDO tokens"));
        ido.fillIDOToken(1 ether);
        vm.stopPrank();
    }

    /// TGE CALCULATION

    function testMustReturnZeroCheckingTGEBalanceBeforeTokenIsSet()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).min)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).min)
    {
        uint256 userAmountInTGE = ido.previewTGETokens(walletInTiers);

        assertEq(userAmountInTGE, 0);
    }

    function testCanCheckTGEBalance()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).min)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).min)
        idoTokenSet
    {
        uint256 userAmountInTGE = ido.previewTGETokens(walletInTiers);

        // price 0.013 ether
        // paid 0.1 ether
        // percentage 8%
        // 0.1 / 0.013 = 7,692307692307692 = 7692307692307692000
        // 8% of 7,692307692307692 = 0,615384615384615 = 615384615384615000 wei
        assertEq(userAmountInTGE, 615384615384615384);

        (uint256 _price,, uint256 _tgePercentage) = ido.amounts();
        uint256 allocation = ido.allocations(walletInTiers);

        UD60x18 price = convert(_price);
        UD60x18 tokens = convert(allocation).div(price);
        UD60x18 expectedTGEamount = tokens.mul(ud(_tgePercentage));

        assertEq(userAmountInTGE, expectedTGEamount.intoUint256());
    }

    /// CALCULATE RELESEAD TOKENS

    function testMustReturnZeroWhenVestingIsNotSet() external {
        uint256 amount = ido.previewClaimableTokens(bob);
        assertEq(amount, 0);
    }

    function testMustReturnZeroWhenVestingDidNotStart() external {
        uint256 amount = ido.previewClaimableTokens(bob);
        assertEq(amount, 0);
    }

    function testMustReturnZeroWhenWalletHasNoAllocation()
        external
        periodsSet(30 days * 8, participationEndsAt + 2 days, 10 days)
    {
        vm.warp(vestingAt);

        uint256 amount = ido.previewClaimableTokens(bob);
        assertEq(amount, 0);
    }

    function testMustReturnTGEBalanceWhenCliffPeriodIsOngoing()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).min)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).min)
        periodsSet(30 days * 8, participationEndsAt + 2 days, 10 days)
        idoTokenSet
    {
        vm.warp(vestingAt + 1 days);

        uint256 expectedTGEAmount = ido.previewTGETokens(walletInTiers);

        uint256 amount = ido.previewClaimableTokens(walletInTiers);
        assertEq(amount, expectedTGEAmount);
    }

    /// CLAIM TGE

    function testCanClaimTGE()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).min)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).min)
        periodsSet(30 days * 8, participationEndsAt + 2 days, 10 days)
        idoTokenSet
        idoTokenFilled(false)
    {
        vm.warp(vestingAt + 1 days);

        uint256 expectedTGEAmount = ido.previewTGETokens(walletInTiers);
        uint256 walletBalance = ERC20(ido.token()).balanceOf(walletInTiers);

        vm.startPrank(walletInTiers);
        ido.claim();
        vm.stopPrank();

        uint256 walletBalanceAfter = ERC20(ido.token()).balanceOf(walletInTiers);

        assertEq(walletBalanceAfter, walletBalance + expectedTGEAmount);
    }

    modifier tgeClaimed(address wallet) {
        vm.warp(vestingAt + 1 days);
        vm.startPrank(wallet);
        ido.claim();
        vm.stopPrank();
        _;
    }

    // REFUND

    function testOwnerCanSetRefundConfigs() external {
        bool refundable = false;
        uint256 refundPercent = 0.005e18;
        uint256 refundPeriod = 48 hours;

        IIDO.Refund memory refundConfig =
            IIDO.Refund({active: refundable, feePercent: refundPercent, period: refundPeriod});

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IIDO.RefundSet(refundConfig);
        ido.setRefund(refundConfig);
        vm.stopPrank();

        (bool active, uint256 feePercent, uint256 period) = ido.refund();
        assertEq(active, refundable);
        assertEq(refundPercent, feePercent);
        assertEq(period, refundPeriod);
    }

    function testRevertRefundingWhenClaimedTGE()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).min)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).min)
        periodsSet(30 days * 8, participationEndsAt + 2 days, 10 days)
        idoTokenSet
        idoTokenFilled(false)
        tgeClaimed(walletInTiers)
    {
        vm.startPrank(walletInTiers);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Unauthorized.selector, "Not refundable"));
        ido.getRefund();
        vm.stopPrank();
    }

    function testRevertRefundingBeforeVestingPeriod()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).min)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).min)
        periodsSet(30 days * 8, participationEndsAt + 2 days, 10 days)
        idoTokenSet
        idoTokenFilled(false)
    {
        vm.warp(vestingAt - 1 days);
        vm.startPrank(walletInTiers);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Unauthorized.selector, "Not refundable"));
        ido.getRefund();
        vm.stopPrank();
    }

    function testRevertRefundingAfterRefundPeriod()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).min)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).min)
        periodsSet(30 days * 8, participationEndsAt + 2 days, 10 days)
        idoTokenSet
        idoTokenFilled(false)
    {
        (,, uint256 period) = ido.refund();
        vm.warp(vestingAt + period + 1 hours);
        vm.startPrank(walletInTiers);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Unauthorized.selector, "Not refundable"));
        ido.getRefund();
        vm.stopPrank();
    }

    function testCanBeRefundable()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).min)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).min)
        periodsSet(30 days * 8, participationEndsAt + 2 days, 10 days)
        idoTokenSet
        idoTokenFilled(false)
    {
        (,, uint256 period) = ido.refund();
        vm.warp(vestingAt + period - 3 hours);
        (uint256 refundableAmount, uint256 refundingFees) = ido.previewRefunding(walletInTiers);

        uint256 balance = walletInTiers.balance;

        vm.startPrank(walletInTiers);
        emit IIDO.Refunded(walletInTiers, refundableAmount);
        ido.getRefund();
        vm.stopPrank();

        uint256 balanceEnd = walletInTiers.balance;
        assertEq(balanceEnd, balance + refundableAmount);
        assertEq(ido.fees(), refundingFees);
    }

    function testCanClaimTGEPlusLinearVestedInPeriod()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).min)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).min)
        periodsSet(30 days * 8, participationEndsAt + 2 days, 10 days)
        idoTokenSet
        idoTokenFilled(false)
    {
        vm.warp(vestingAt + 1 days);

        uint256 expectedTGEAmount = ido.previewTGETokens(walletInTiers);
        uint256 walletBalance = ERC20(ido.token()).balanceOf(walletInTiers);

        vm.warp(ido.cliffEndsAt() + 100 days);

        uint256 expectedVestedTokens = ido.previewClaimableTokens(walletInTiers);
        assertTrue(expectedVestedTokens > expectedTGEAmount);

        vm.startPrank(walletInTiers);
        ido.claim();
        vm.stopPrank();

        uint256 walletBalanceAfter = ERC20(ido.token()).balanceOf(walletInTiers);
        assertEq(walletBalanceAfter, walletBalance + expectedVestedTokens);
    }

    function testCanClaimVestedTokensAfterTGEClaim()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).min)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).min)
        periodsSet(30 days * 8, participationEndsAt + 2 days, 10 days)
        idoTokenSet
        idoTokenFilled(false)
    {
        vm.warp(vestingAt + 1 days);

        uint256 expectedTGEAmount = ido.previewTGETokens(walletInTiers);
        uint256 walletBalance = ERC20(ido.token()).balanceOf(walletInTiers);

        uint256 expectedVestedTokens = ido.previewClaimableTokens(walletInTiers);
        assertEq(expectedVestedTokens, expectedTGEAmount);

        vm.startPrank(walletInTiers);
        ido.claim();
        vm.stopPrank();

        uint256 walletBalanceAfterTGEClaim = ERC20(ido.token()).balanceOf(walletInTiers);
        assertEq(walletBalanceAfterTGEClaim, walletBalance + expectedTGEAmount);

        vm.warp(ido.cliffEndsAt() + 10 days);

        uint256 expectedVestedTokensAfterTGE = ido.previewClaimableTokens(walletInTiers);

        vm.startPrank(walletInTiers);
        ido.claim();
        vm.stopPrank();

        uint256 walletBalanceAfter = ERC20(ido.token()).balanceOf(walletInTiers);

        assertEq(walletBalanceAfter, walletBalanceAfterTGEClaim + expectedVestedTokensAfterTGE);
    }

    function testCanClaimAllVestedTokens()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).min)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).min)
        periodsSet(30 days * 8, participationEndsAt + 2 days, 10 days)
        idoTokenSet
        idoTokenFilled(false)
    {
        vm.warp(vestingAt + cliff + 1 hours);

        uint256 claimableAmount = ido.previewClaimableTokens(walletInTiers);

        while (claimableAmount > 0) {
            vm.startPrank(walletInTiers);
            ido.claim();
            vm.stopPrank();

            vm.warp(ido.lastClaimTimestamps(walletInTiers) + 15 days);
            claimableAmount = ido.previewClaimableTokens(walletInTiers);
        }

        uint256 allocation = ido.allocations(walletInTiers);
        uint256 totalTokens = ido.tokenAmountByParticipation(allocation);
        uint256 totalClaimed = ido.tokensClaimed(walletInTiers);

        assertEq(totalTokens, totalClaimed);
    }

    // EMERGENCY WITHDRAW FOR SPECIFIC WALLET

    function testRevertEmergencyWithdrawByWalletWhenTokenNotSet() external {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Unauthorized.selector, "Token not set"));
        ido.emergencyWithdrawByWallet(walletInTiers);
        vm.stopPrank();
    }

    function testRevertEmergencyWithdrawByWalletWhenVesingIsOngoing()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).min)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).min)
        isPublic
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).max)
        participated(walletInTiers, ido.getWalletRange(walletInTiers).max - ido.getWalletRange(walletInTiers).min)
        periodsSet(30 days * 8, participationEndsAt + 2 days, 100 days)
        idoTokenSet
        idoTokenFilled(false)
    {
        (,,, uint256 _vestingDuration, uint256 _vestingAt,) = ido.periods();
        vm.warp(_vestingAt + _vestingDuration - 1 days);
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Unauthorized.selector, "Vesting is ongoing"));
        ido.emergencyWithdrawByWallet(walletInTiers);
        vm.stopPrank();
    }

    function testRevertEmergencyWithdrawByWalletWhenHasNoAllocation()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).min)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).min)
        periodsSet(30 days * 8, participationEndsAt + 2 days, 100 days)
        idoTokenSet
        idoTokenFilled(false)
    {
        (,,, uint256 _vestingDuration, uint256 _vestingAt,) = ido.periods();
        vm.warp(_vestingAt + _vestingDuration + 1 hours);
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Unauthorized.selector, "Wallet has no allocation"));
        ido.emergencyWithdrawByWallet(bob);
        vm.stopPrank();
    }

    function testCanEmergencyWithdrawByWallet()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).min)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).min)
        isPublic
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).max)
        participated(walletInTiers, ido.getWalletRange(walletInTiers).max - ido.getWalletRange(walletInTiers).min)
        periodsSet(30 days * 8, participationEndsAt + 2 days, 100 days)
        idoTokenSet
        idoTokenFilled(false)
    {
        uint256 expectedAmountToWithdraw = ido.tokenAmountByParticipation(ido.allocations(walletInTiers));
        (,,, uint256 _vestingDuration, uint256 _vestingAt,) = ido.periods();
        vm.warp(_vestingAt + _vestingDuration + 1 hours);
        vm.startPrank(owner);
        vm.expectEmit(true, true, true, false);
        emit IIDO.Claimed(walletInTiers, expectedAmountToWithdraw);
        ido.emergencyWithdrawByWallet(walletInTiers);
        vm.stopPrank();
    }

    // EMERGENCY WITHDRAW

    function testRevertEmergencyWithdrawtWhenTokenNotSet() external {
        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IIDO.IIDO__Unauthorized.selector, "Token not set"));
        ido.emergencyWithdraw();
        vm.stopPrank();
    }

    function testCanEmergencyWithdraw()
        external
        walletLinked(walletInTiers)
        isWhitelisted(walletInTiers)
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).min)
        inParticipationPeriod
        participated(walletInTiers, ido.getWalletRange(walletInTiers).min)
        isPublic
        hasBalance(walletInTiers, ido.getWalletRange(walletInTiers).max)
        participated(walletInTiers, ido.getWalletRange(walletInTiers).max - ido.getWalletRange(walletInTiers).min)
        periodsSet(30 days * 8, participationEndsAt + 2 days, 100 days)
        idoTokenSet
        idoTokenFilled(false)
    {
        assertTrue(ido.token() != address(0));

        uint256 expectedAmountToWithdraw = ERC20(ido.token()).balanceOf(address(ido));
        assertTrue(expectedAmountToWithdraw > 0);

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IIDO.RemainingTokensWithdrawal(expectedAmountToWithdraw);
        ido.emergencyWithdraw();
        vm.stopPrank();
    }
}
