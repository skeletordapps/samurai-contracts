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

    // ACCEPTED TOKEN
    address acceptedToken;

    // PERIODS
    uint256 registrationAt;
    uint256 participationStartsAt;
    uint256 participationEndsAt;
    uint256 vestingDuration;
    uint256 vestingAt;
    uint256 cliff;

    address owner;
    address randomUSDCHolder;
    address walletA;
    address walletB;
    address walletC;

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployIDO();

        // bool _usingETH,
        // bool _usingLinkedWallet,
        // uint256 _price,
        // uint256 _totalMax,
        // bool _refundable,
        // uint256 _refundPercent,
        // uint256 _refundPeriod

        // User B invests 1000 USDC in project B (10% TGE - 2 months cliff - with linear vesting for 9 months)...
        // he doesn't claim at TGE but he also misses the 24-hour deadline for clicking refund - he enters vesting just the same as User A

        ido = deployer.runForTestsWithOptions(
            false, true, 10e6, 50_000e6, 0.1e18, true, 0.01e18, 24 hours, IIDO.VestingType.LinearVesting
        );
        owner = ido.owner();

        acceptedToken = ido.acceptedToken();

        (registrationAt, participationStartsAt, participationEndsAt, vestingDuration, vestingAt, cliff) = ido.periods();

        randomUSDCHolder = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
        walletA = 0xC2a96B13a975c656f60f401a5F72851af4717D4A;
        walletB = 0xcaE8cF1e2119484D6CC3B6EFAad2242aDBDB1Ea8;
        walletC = 0xebf2e0b82F63F4a6F9Bbf95A7523Cd2959CEC815;
    }

    modifier walletLinked(address wallet) {
        vm.startPrank(wallet);
        ido.linkWallet("67aL4e2LBSbPeC9aLuw4y8tqTqKwuHDEhmRPTmYHKytK");
        vm.stopPrank();
        _;
    }

    modifier isWhitelisted(address wallet) {
        vm.startPrank(wallet);
        ido.register();
        vm.stopPrank();
        _;
    }

    modifier hasBalance(address wallet, uint256 amount) {
        if (keccak256(abi.encodePacked(ERC20(acceptedToken).symbol())) == keccak256(abi.encodePacked("USDC"))) {
            vm.startPrank(randomUSDCHolder);
            ERC20(acceptedToken).transfer(wallet, amount);
            vm.stopPrank();
        } else {
            deal(acceptedToken, wallet, amount);
        }
        _;
    }

    modifier inParticipationPeriod() {
        vm.warp(participationStartsAt + 2 hours);
        _;
    }

    modifier participated(address wallet, address token, uint256 amount) {
        vm.startPrank(wallet);
        ERC20(token).approve(address(ido), amount);
        ido.participate(amount);
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

    modifier idoTokenSet() {
        vm.warp(participationEndsAt + 2 hours);
        ERC20Mock newToken = new ERC20Mock("IDO TOKEN", "IDT");
        vm.startPrank(owner);
        ido.setIDOToken(address(newToken));
        vm.stopPrank();
        _;
    }

    modifier idoTokenFilled() {
        vm.warp(participationEndsAt + 30 minutes);
        address idoToken = ido.token();
        uint256 raised = ido.raised();
        uint256 expectedAmountOfTokens = ido.tokenAmountByParticipation(raised);

        deal(idoToken, owner, expectedAmountOfTokens);

        vm.startPrank(owner);
        ERC20(idoToken).approve(address(ido), expectedAmountOfTokens);
        ido.fillIDOToken(expectedAmountOfTokens);
        vm.stopPrank();
        _;
    }

    modifier tgeClaimed(address wallet) {
        vm.warp(vestingAt + 1 days);
        vm.startPrank(wallet);
        ido.claim();
        vm.stopPrank();
        _;
    }

    // User B didn't claim during the two month cliff and didn't claim any during first month of vesting,
    // how many tokens can he claim after month 3 (two months cliff and one month vesting)?

    function testCase1_Check_Tokens_UserB_Will_Claim_Monthly_Without_Any_Previous_Claims()
        external
        walletLinked(walletB)
        isWhitelisted(walletB)
        hasBalance(walletB, 1_000e6)
        inParticipationPeriod
        participated(walletB, acceptedToken, 1_000e6)
        isPublic
        periodsSet(30 days * 8, participationEndsAt + 2 days, 30 days * 2)
        idoTokenSet
        idoTokenFilled
    {
        // PHASE 1

        uint256 allocation = ido.allocations(walletB);
        uint256 totalOfTokens = ido.tokenAmountByParticipation(allocation);
        uint256 amountInTGE = ido.previewTGETokens(walletB);
        uint256 cliffEndsAt = ido.cliffEndsAt();

        console.log("walletB allocated - ", allocation);
        console.log("total in tokens to receive at the end - ", totalOfTokens);
        console.log("10 percent will be available on TGE - ", amountInTGE);
        console.log("vesting duration of ", vestingDuration / 86400, "days");
        console.log("vesting duration of ", vestingDuration / 86400 / 30, "months");
        console.log("tge starts at", vestingAt);
        console.log(" ");

        uint256 amountClaimable = ido.previewClaimableTokens(walletB);
        console.log("amount claimable before TGE should be zero - ", amountClaimable);
        console.log(" ");

        // PHASE 2

        vm.warp(vestingAt);
        amountClaimable = ido.previewClaimableTokens(walletB);
        console.log("amount claimable at TGE date - ", amountClaimable);
        uint256 claimedAmount = ido.tokensClaimed(walletB);
        console.log("claimed amount - ", claimedAmount);
        console.log(" ");

        // PHASE 3

        vm.warp(cliffEndsAt);
        console.log("2 months has passed since TGE date - Cliff Ended - ", cliffEndsAt);
        amountClaimable = ido.previewClaimableTokens(walletB);
        console.log("amount claimable exactly when cliff ends should be the same of TGE (yet) - ", amountClaimable);
        assertTrue(block.timestamp == cliffEndsAt);
        assertEq(ido.previewClaimableTokens(walletB), ido.previewTGETokens(walletB));
        console.log("claimed amount - ", ido.tokensClaimed(walletB));
        console.log(" ");

        // PHASE 4

        uint256 claimableBefore = ido.previewClaimableTokens(walletB);
        uint256 claimableAfter = 0;

        vm.warp(cliffEndsAt + 30 days);
        claimableAfter = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfter > claimableBefore);
        console.log("time passed - ", block.timestamp, "30 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        claimableBefore = claimableAfter;
        vm.warp(cliffEndsAt + 35 days);
        claimableAfter = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfter > claimableBefore);
        console.log("time passed - ", block.timestamp, "35 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        claimableBefore = claimableAfter;
        vm.warp(cliffEndsAt + 60 days);
        claimableAfter = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfter > claimableBefore);
        console.log("time passed - ", block.timestamp, "60 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        claimableBefore = claimableAfter;
        vm.warp(cliffEndsAt + 90 days);
        claimableAfter = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfter > claimableBefore);
        console.log("time passed - ", block.timestamp, "90 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        claimableBefore = claimableAfter;
        vm.warp(cliffEndsAt + 120 days);
        claimableAfter = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfter > claimableBefore);
        console.log("time passed - ", block.timestamp, "120 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        claimableBefore = claimableAfter;
        vm.warp(cliffEndsAt + 150 days);
        claimableAfter = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfter > claimableBefore);
        console.log("time passed - ", block.timestamp, "150 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        claimableBefore = claimableAfter;
        vm.warp(cliffEndsAt + 180 days);
        claimableAfter = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfter > claimableBefore);
        console.log("time passed - ", block.timestamp, "180 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        claimableBefore = claimableAfter;
        vm.warp(cliffEndsAt + 210 days);
        claimableAfter = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfter > claimableBefore);
        console.log("time passed - ", block.timestamp, "210 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        claimableBefore = claimableAfter;
        vm.warp(cliffEndsAt + 240 days);
        claimableAfter = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfter > claimableBefore);
        console.log("time passed - ", block.timestamp, "240 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        claimableBefore = claimableAfter;
        vm.warp(cliffEndsAt + 241 days);
        claimableAfter = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfter > claimableBefore);
        console.log("time passed - ", block.timestamp, "241 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        assertEq(totalOfTokens, ido.previewVestedTokens());
        assertEq(totalOfTokens, ido.previewClaimableTokens(walletB));
    }

    function testCase2_Wallet_A_and_B_should_have_same_amounts_while_vesting_period_without_claim()
        external
        walletLinked(walletA)
        walletLinked(walletB)
        isWhitelisted(walletA)
        isWhitelisted(walletA)
        isWhitelisted(walletB)
        hasBalance(walletA, 1_000e6)
        hasBalance(walletB, 1_000e6)
        inParticipationPeriod
        participated(walletA, acceptedToken, 1_000e6)
        participated(walletB, acceptedToken, 1_000e6)
        isPublic
        periodsSet(30 days * 8, participationEndsAt + 2 days, 30 days * 2)
        idoTokenSet
        idoTokenFilled
    {
        // PHASE 1

        uint256 allocationA = ido.allocations(walletA);
        uint256 totalOfTokensA = ido.tokenAmountByParticipation(allocationA);
        uint256 amountInTgeA = ido.previewTGETokens(walletA);

        uint256 allocationB = ido.allocations(walletB);
        uint256 totalOfTokensB = ido.tokenAmountByParticipation(allocationB);
        uint256 amountInTgeB = ido.previewTGETokens(walletB);

        uint256 cliffEndsAt = ido.cliffEndsAt();

        console.log("walletA allocated - ", allocationA);
        console.log("total in tokens to receive at the end - ", totalOfTokensA);
        console.log("10 percent will be available on TGE - ", amountInTgeA);
        console.log(" ");
        console.log("walletB allocated - ", allocationB);
        console.log("total in tokens to receive at the end - ", totalOfTokensB);
        console.log("10 percent will be available on TGE - ", amountInTgeB);
        console.log(" ");
        console.log("total in tokens for vesting", ido.tokenAmountByParticipation(ido.raised()));
        console.log("vesting duration of ", vestingDuration / 86400, "days");
        console.log("vesting duration of ", vestingDuration / 86400 / 30, "months");
        console.log("tge starts at", vestingAt);
        console.log(" ");

        uint256 amountClaimableA = ido.previewClaimableTokens(walletA);
        console.log("A - amount claimable before TGE should be zero - ", amountClaimableA);

        uint256 amountClaimableB = ido.previewClaimableTokens(walletB);
        console.log("B - amount claimable before TGE should be zero - ", amountClaimableB);
        console.log(" ");

        // PHASE 2

        vm.warp(vestingAt);
        amountClaimableA = ido.previewClaimableTokens(walletA);
        console.log("A - amount claimable at TGE date - ", amountClaimableA);
        uint256 claimedAmountA = ido.tokensClaimed(walletA);
        console.log("claimed amount - ", claimedAmountA);

        amountClaimableB = ido.previewClaimableTokens(walletB);
        console.log("B - amount claimable at TGE date - ", amountClaimableB);
        uint256 claimedAmountB = ido.tokensClaimed(walletB);
        console.log("claimed amount - ", claimedAmountB);
        console.log(" ");

        // PHASE 3

        vm.warp(cliffEndsAt);
        assertTrue(block.timestamp == cliffEndsAt);
        console.log("2 months has passed since TGE date - Cliff Ended - ", cliffEndsAt);
        console.log(" ");
        amountClaimableA = ido.previewClaimableTokens(walletA);
        console.log("amount claimable exactly when cliff ends should be the same of TGE (yet) - ", amountClaimableA);
        assertEq(ido.previewClaimableTokens(walletA), ido.previewTGETokens(walletA));
        console.log("A- claimed amount - ", ido.tokensClaimed(walletA));
        console.log(" ");
        amountClaimableB = ido.previewClaimableTokens(walletB);
        console.log("amount claimable exactly when cliff ends should be the same of TGE (yet) - ", amountClaimableB);
        assertEq(ido.previewClaimableTokens(walletB), ido.previewTGETokens(walletB));
        console.log("B- claimed amount - ", ido.tokensClaimed(walletB));
        console.log(" ");

        // PHASE 4

        uint256 claimableBeforeA = ido.previewClaimableTokens(walletA);
        uint256 claimableAfterA = 0;

        uint256 claimableBeforeB = ido.previewClaimableTokens(walletB);
        uint256 claimableAfterB = 0;

        vm.warp(cliffEndsAt + 30 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfterA > claimableBeforeA);
        assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "30 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable  - ", ido.previewClaimableTokens(walletA));
        console.log("A - claimed    - ", ido.tokensClaimed(walletA));
        console.log("B - claimable  - ", ido.previewClaimableTokens(walletB));
        console.log("B - claimed    - ", ido.tokensClaimed(walletB));
        console.log(" ");

        claimableBeforeA = claimableAfterA;
        claimableBeforeB = claimableAfterB;
        vm.warp(cliffEndsAt + 35 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfterA > claimableBeforeA);
        assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "30 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable - ", ido.previewClaimableTokens(walletA));
        console.log("B - claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        claimableBeforeA = claimableAfterA;
        claimableBeforeB = claimableAfterB;
        vm.warp(cliffEndsAt + 60 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfterA > claimableBeforeA);
        assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "60 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable - ", ido.previewClaimableTokens(walletA));
        console.log("B - claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        claimableBeforeA = claimableAfterA;
        claimableBeforeB = claimableAfterB;
        vm.warp(cliffEndsAt + 90 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfterA > claimableBeforeA);
        assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "90 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable - ", ido.previewClaimableTokens(walletA));
        console.log("B - claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        claimableBeforeA = claimableAfterA;
        claimableBeforeB = claimableAfterB;
        vm.warp(cliffEndsAt + 120 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfterA > claimableBeforeA);
        assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "120 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable - ", ido.previewClaimableTokens(walletA));
        console.log("B - claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        claimableBeforeA = claimableAfterA;
        claimableBeforeB = claimableAfterB;
        vm.warp(cliffEndsAt + 150 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfterA > claimableBeforeA);
        assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "150 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable - ", ido.previewClaimableTokens(walletA));
        console.log("B - claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        claimableBeforeA = claimableAfterA;
        claimableBeforeB = claimableAfterB;
        vm.warp(cliffEndsAt + 180 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfterA > claimableBeforeA);
        assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "180 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable - ", ido.previewClaimableTokens(walletA));
        console.log("B - claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        claimableBeforeA = claimableAfterA;
        claimableBeforeB = claimableAfterB;
        vm.warp(cliffEndsAt + 210 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfterA > claimableBeforeA);
        assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "210 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable - ", ido.previewClaimableTokens(walletA));
        console.log("B - claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        claimableBeforeA = claimableAfterA;
        claimableBeforeB = claimableAfterB;
        vm.warp(cliffEndsAt + 240 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfterA > claimableBeforeA);
        assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "240 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable - ", ido.previewClaimableTokens(walletA));
        console.log("B - claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        claimableBeforeA = claimableAfterA;
        claimableBeforeB = claimableAfterB;
        vm.warp(cliffEndsAt + 241 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfterA > claimableBeforeA);
        assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "241 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable - ", ido.previewClaimableTokens(walletA));
        console.log("B - claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        assertEq(totalOfTokensA, ido.previewVestedTokens() / 2);
        assertEq(totalOfTokensB, ido.previewVestedTokens() / 2);
        assertEq(totalOfTokensA, ido.previewClaimableTokens(walletA));
        assertEq(totalOfTokensB, ido.previewClaimableTokens(walletB));
    }

    function testCase3_Wallet_A_and_B_Can_Claim_Tokens_In_Different_Periods()
        external
        walletLinked(walletA)
        walletLinked(walletB)
        isWhitelisted(walletA)
        isWhitelisted(walletA)
        isWhitelisted(walletB)
        hasBalance(walletA, 1_000e6)
        hasBalance(walletB, 1_000e6)
        inParticipationPeriod
        participated(walletA, acceptedToken, 1_000e6)
        participated(walletB, acceptedToken, 1_000e6)
        isPublic
        periodsSet(30 days * 8, participationEndsAt + 2 days, 30 days * 2)
        idoTokenSet
        idoTokenFilled
    {
        // PHASE 1

        uint256 allocationA = ido.allocations(walletA);
        uint256 totalOfTokensA = ido.tokenAmountByParticipation(allocationA);

        uint256 allocationB = ido.allocations(walletB);
        uint256 totalOfTokensB = ido.tokenAmountByParticipation(allocationB);

        uint256 cliffEndsAt = ido.cliffEndsAt();

        uint256 amountClaimableA = ido.previewClaimableTokens(walletA);
        console.log("A - amount claimable before TGE should be zero - ", amountClaimableA);

        uint256 amountClaimableB = ido.previewClaimableTokens(walletB);
        console.log("B - amount claimable before TGE should be zero - ", amountClaimableB);
        console.log(" ");

        // PHASE 2

        vm.warp(vestingAt);
        amountClaimableA = ido.previewClaimableTokens(walletA);
        console.log("A - amount claimable at TGE date - ", amountClaimableA);
        vm.startPrank(walletA);
        ido.claim();
        vm.stopPrank();
        uint256 claimedAmountA = ido.tokensClaimed(walletA);
        console.log("claimed amount - ", claimedAmountA);

        amountClaimableB = ido.previewClaimableTokens(walletB);
        console.log("B - amount claimable at TGE date - ", amountClaimableB);
        uint256 claimedAmountB = ido.tokensClaimed(walletB);
        console.log("claimed amount - ", claimedAmountB);
        console.log(" ");

        // PHASE 3

        vm.warp(cliffEndsAt);
        assertTrue(block.timestamp == cliffEndsAt);
        console.log("2 months has passed since TGE date - Cliff Ended - ", cliffEndsAt);
        console.log(" ");
        amountClaimableA = ido.previewClaimableTokens(walletA);
        console.log("amount claimable exactly when cliff ends should be zero (tge claimed) - ", amountClaimableA);
        assertEq(ido.previewClaimableTokens(walletA), 0);
        console.log("A- claimed amount - ", ido.tokensClaimed(walletA));
        console.log(" ");
        amountClaimableB = ido.previewClaimableTokens(walletB);
        console.log("amount claimable exactly when cliff ends should be the same of TGE (yet) - ", amountClaimableB);
        assertEq(ido.previewClaimableTokens(walletB), ido.previewTGETokens(walletB));
        console.log("B- claimed amount - ", ido.tokensClaimed(walletB));
        console.log(" ");

        // PHASE 4

        uint256 claimableBeforeA = ido.previewClaimableTokens(walletA);
        uint256 claimableAfterA = 0;

        uint256 claimableBeforeB = ido.previewClaimableTokens(walletB);
        uint256 claimableAfterB = 0;

        vm.warp(cliffEndsAt + 30 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfterA > claimableBeforeA);
        assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "30 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable  - ", ido.previewClaimableTokens(walletA));
        console.log("A - claimed    - ", ido.tokensClaimed(walletA));
        console.log("B - claimable  - ", ido.previewClaimableTokens(walletB));
        console.log("B - claimed    - ", ido.tokensClaimed(walletB));
        console.log(" ");

        claimableBeforeA = claimableAfterA;
        claimableBeforeB = claimableAfterB;
        vm.warp(cliffEndsAt + 35 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfterA > claimableBeforeA);
        assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "30 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable  - ", ido.previewClaimableTokens(walletA));
        console.log("A - claimed    - ", ido.tokensClaimed(walletA));
        console.log("B - claimable  - ", ido.previewClaimableTokens(walletB));
        console.log("B - claimed    - ", ido.tokensClaimed(walletB));
        console.log(" ");

        claimableBeforeA = claimableAfterA;
        claimableBeforeB = claimableAfterB;
        vm.warp(cliffEndsAt + 60 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfterA > claimableBeforeA);
        assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "60 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable  - ", ido.previewClaimableTokens(walletA));
        console.log("A - claimed    - ", ido.tokensClaimed(walletA));
        console.log("B - claimable  - ", ido.previewClaimableTokens(walletB));
        console.log("B - claimed    - ", ido.tokensClaimed(walletB));
        console.log(" ");

        claimableBeforeA = claimableAfterA;
        claimableBeforeB = claimableAfterB;
        vm.warp(cliffEndsAt + 90 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        assertTrue(claimableAfterA > claimableBeforeA);
        assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "90 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable  - ", ido.previewClaimableTokens(walletA));
        console.log("A - claimed    - ", ido.tokensClaimed(walletA));
        console.log("B - claimable  - ", ido.previewClaimableTokens(walletB));
        console.log("B - claimed    - ", ido.tokensClaimed(walletB));
        vm.startPrank(walletB);
        ido.claim();
        vm.stopPrank();
        console.log(" ");

        claimableBeforeA = claimableAfterA;
        claimableBeforeB = claimableAfterB;
        vm.warp(cliffEndsAt + 120 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        // assertTrue(claimableAfterA > claimableBeforeA);
        // assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "120 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable  - ", ido.previewClaimableTokens(walletA));
        console.log("A - claimed    - ", ido.tokensClaimed(walletA));
        console.log("B - claimable  - ", ido.previewClaimableTokens(walletB));
        console.log("B - claimed    - ", ido.tokensClaimed(walletB));
        console.log(" ");

        claimableBeforeA = claimableAfterA;
        claimableBeforeB = claimableAfterB;
        vm.warp(cliffEndsAt + 150 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        // assertTrue(claimableAfterA > claimableBeforeA);
        // assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "150 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable  - ", ido.previewClaimableTokens(walletA));
        console.log("A - claimed    - ", ido.tokensClaimed(walletA));
        console.log("B - claimable  - ", ido.previewClaimableTokens(walletB));
        console.log("B - claimed    - ", ido.tokensClaimed(walletB));
        console.log(" ");

        claimableBeforeA = claimableAfterA;
        claimableBeforeB = claimableAfterB;
        vm.warp(cliffEndsAt + 180 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        // assertTrue(claimableAfterA > claimableBeforeA);
        // assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "180 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable  - ", ido.previewClaimableTokens(walletA));
        console.log("A - claimed    - ", ido.tokensClaimed(walletA));
        console.log("B - claimable  - ", ido.previewClaimableTokens(walletB));
        console.log("B - claimed    - ", ido.tokensClaimed(walletB));
        console.log(" ");

        claimableBeforeA = claimableAfterA;
        claimableBeforeB = claimableAfterB;
        vm.warp(cliffEndsAt + 210 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        // assertTrue(claimableAfterA > claimableBeforeA);
        // assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "210 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable  - ", ido.previewClaimableTokens(walletA));
        console.log("A - claimed    - ", ido.tokensClaimed(walletA));
        console.log("B - claimable  - ", ido.previewClaimableTokens(walletB));
        console.log("B - claimed    - ", ido.tokensClaimed(walletB));
        console.log(" ");

        claimableBeforeA = claimableAfterA;
        claimableBeforeB = claimableAfterB;
        vm.warp(cliffEndsAt + 240 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        // assertTrue(claimableAfterA > claimableBeforeA);
        // assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "240 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable  - ", ido.previewClaimableTokens(walletA));
        console.log("A - claimed    - ", ido.tokensClaimed(walletA));
        console.log("B - claimable  - ", ido.previewClaimableTokens(walletB));
        console.log("B - claimed    - ", ido.tokensClaimed(walletB));
        console.log(" ");

        claimableBeforeA = claimableAfterA;
        claimableBeforeB = claimableAfterB;
        vm.warp(cliffEndsAt + 241 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        // assertTrue(claimableAfterA > claimableBeforeA);
        // assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "241 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable          - ", ido.previewClaimableTokens(walletA));
        console.log("A - claimed            - ", ido.tokensClaimed(walletA));
        console.log("B - claimable          - ", ido.previewClaimableTokens(walletB));
        console.log("B - claimed  so far    - ", ido.tokensClaimed(walletB));
        vm.startPrank(walletB);
        ido.claim();
        vm.stopPrank();
        console.log("B - claimed now        - ", ido.tokensClaimed(walletB));
        console.log("B - claimable after    - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        claimableBeforeA = claimableAfterA;
        claimableBeforeB = claimableAfterB;
        vm.warp(cliffEndsAt + 300 days);
        claimableAfterA = ido.previewClaimableTokens(walletA);
        claimableAfterB = ido.previewClaimableTokens(walletB);
        // assertTrue(claimableAfterA > claimableBeforeA);
        // assertTrue(claimableAfterB > claimableBeforeB);
        console.log("time passed - ", block.timestamp, "300 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("A - claimable          - ", ido.previewClaimableTokens(walletA));
        console.log("A - claimed  so far    - ", ido.tokensClaimed(walletA));
        vm.startPrank(walletA);
        ido.claim();
        vm.stopPrank();
        console.log("A - claimed now        - ", ido.tokensClaimed(walletA));
        console.log("A - claimable after    - ", ido.previewClaimableTokens(walletA));
        console.log("B - claimable          - ", ido.previewClaimableTokens(walletB));
        console.log("B - claimed            - ", ido.tokensClaimed(walletB));
        console.log(" ");
    }
}
