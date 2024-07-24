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

        ido = deployer.runForTestsWithOptions(false, true, 10e6, 50_000e6, 0.1e18, true, 0.01e18, 24 hours);
        owner = ido.owner();

        acceptedToken = ido.acceptedToken();

        (registrationAt, participationStartsAt, participationEndsAt, vestingDuration, vestingAt, cliff) = ido.periods();

        randomUSDCHolder = 0xd0b53D9277642d899DF5C87A3966A349A798F224;
        walletA = 0xC2a96B13a975c656f60f401a5F72851af4717D4A;
        walletB = 0xcaE8cF1e2119484D6CC3B6EFAad2242aDBDB1Ea8;
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

    function testCase1_How_Many_Tokens_UserB_Will_Claim_After_3_Months_Without_Any_Previous_Claims()
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
        uint256 vestingEndsAt = ido.vestingEndsAt();

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
        // console.log("claimed amount - ", ido.tokensClaimed(walletB));
        console.log(" ");

        // PHASE 4

        vm.warp(cliffEndsAt + 30 days);
        console.log("time passed - ", block.timestamp, "30 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        vm.warp(cliffEndsAt + 35 days);
        console.log("time passed - ", block.timestamp, "35 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        vm.warp(cliffEndsAt + 60 days);
        console.log("time passed - ", block.timestamp, "60 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        vm.warp(cliffEndsAt + 90 days);
        console.log("time passed - ", block.timestamp, "90 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        vm.warp(cliffEndsAt + 120 days);
        console.log("time passed - ", block.timestamp, "120 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        vm.warp(cliffEndsAt + 150 days);
        console.log("time passed - ", block.timestamp, "150 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        vm.warp(cliffEndsAt + 180 days);
        console.log("time passed - ", block.timestamp, "180 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        vm.warp(cliffEndsAt + 210 days);
        console.log("time passed - ", block.timestamp, "210 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        vm.warp(cliffEndsAt + 240 days);
        console.log("time passed - ", block.timestamp, "240 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");

        vm.warp(cliffEndsAt + 241 days);
        console.log("time passed - ", block.timestamp, "241 days");
        console.log("amount vested", ido.previewVestedTokens());
        console.log("claimable - ", ido.previewClaimableTokens(walletB));
        console.log(" ");
    }
}
