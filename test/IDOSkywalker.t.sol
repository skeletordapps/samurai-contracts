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

// Project SKYWALKER ($SKR): 30% at TGE, 1 month cliff, MONTHLY vesting for three months (33.33% unlocked each month)

// TGE: August 5th, 2024 at 12 UTC - 1722859200
// (means tokens unlock on October 5, November 5, and December 5 at 12 UTC)

// Today's date: November 10th, 2024

// User A: Has not claimed any tokens yet.
// User B: Claimed TGE unlock but hasn't made a claim since TGE
// User C: Claimed TGE unlock and claimed tokens on October 5 - 1728129600 and November 5 - 1730808000

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
        // uint256 _tgePercentage,
        // bool _refundable,
        // uint256 _refundPercent,
        // uint256 _refundPeriod
        // VestingType

        ido = deployer.runForTestsWithOptions(
            false, false, 10e6, 200_000e6, 0.3e18, true, 0.01e18, 24 hours, IIDO.VestingType.PeriodicVesting
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
        console.log("$SKR contract balance - ", expectedAmountOfTokens);

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

    function testSkywalker1()
        external
        isWhitelisted(walletA)
        isWhitelisted(walletB)
        isWhitelisted(walletC)
        hasBalance(walletA, 1_000e6)
        hasBalance(walletB, 1_000e6)
        hasBalance(walletC, 1_000e6)
        inParticipationPeriod
        participated(walletA, acceptedToken, 1_000e6)
        participated(walletB, acceptedToken, 1_000e6)
        participated(walletC, acceptedToken, 1_000e6)
        isPublic
        periodsSet(30 days * 3, 1722859200, 30 days) // 3 months vesting, 1 month cliff
        idoTokenSet
        idoTokenFilled
    {
        // PHASE 1

        // uint256 allocationA = ido.allocations(walletA);
        // uint256 totalOfTokensA = ido.tokenAmountByParticipation(allocationA);

        // uint256 allocationB = ido.allocations(walletB);
        // uint256 totalOfTokensB = ido.tokenAmountByParticipation(allocationB);

        // uint256 allocationC = ido.allocations(walletC);
        // uint256 totalOfTokensC = ido.tokenAmountByParticipation(allocationC);

        // uint256 cliffEndsAt = ido.cliffEndsAt();

        // uint256 amountClaimableA = ido.previewClaimableTokens(walletA);
        // uint256 amountClaimableB = ido.previewClaimableTokens(walletB);
        // uint256 amountClaimableC = ido.previewClaimableTokens(walletC);

        // PHASE 2

        vm.warp(vestingAt);
        // TGE: August 5th, 2024 at 12 UTC - 1722859200
        // (means tokens unlock on October 5, November 5, and December 5 at 12 UTC)
        console.log("TGE: August 5th, 2024 at 12 UTC - ", block.timestamp);
        console.log(" ");

        vm.startPrank(walletB);
        ido.claim();
        vm.stopPrank();
        console.log("User B: Claimed TGE unlock");
        console.log(
            "Total Claimed - $SKR",
            ido.tokensClaimed(walletB),
            "Total Claimable - $SKR",
            ido.previewClaimableTokens(walletB)
        );
        console.log(" ");

        vm.startPrank(walletC);
        ido.claim();
        vm.stopPrank();
        console.log("User C: Claimed TGE unlock");
        console.log(
            "Total Claimed - $SKR",
            ido.tokensClaimed(walletC),
            "Total Claimable - $SKR",
            ido.previewClaimableTokens(walletC)
        );
        console.log(" ");
        uint256 cliffEndsAt = ido.cliffEndsAt();
        console.log("Cliff started and goes until - September 4, 2024 12 UTC ", cliffEndsAt);
        console.log(" ");

        // User C: Claimed TGE unlock and claimed tokens on October 5 - 1728129600 and November 5 - 1730808000

        vm.warp(1728129600);
        console.log(ido.calculateMonths(vestingAt, block.timestamp), "months later after TGE");
        console.log(ido.calculateMonths(cliffEndsAt, block.timestamp), "months later after CLIFF");
        console.log("Today's date: October 5th, 2024 - ", block.timestamp);
        vm.startPrank(walletC);
        ido.claim();
        vm.stopPrank();
        console.log("User C: Claimed");
        console.log(
            "Total Claimed - $SKR",
            ido.tokensClaimed(walletC),
            "Total Claimable - $SKR",
            ido.previewClaimableTokens(walletC)
        );
        console.log(" ");

        vm.warp(1730808000);
        console.log(ido.calculateMonths(vestingAt, block.timestamp), "months later after TGE");
        console.log(ido.calculateMonths(cliffEndsAt, block.timestamp), "months later after CLIFF");
        console.log("Today's date: November 5th, 2024 - ", block.timestamp);
        vm.startPrank(walletC);
        ido.claim();
        vm.stopPrank();
        console.log("User C: Claimed");
        console.log(
            "Total Claimed - $SKR",
            ido.tokensClaimed(walletC),
            "Total Claimable - $SKR",
            ido.previewClaimableTokens(walletC)
        );
        console.log(" ");

        // Today's date: November 10th, 2024 - 1731240000
        vm.warp(1731240000);
        console.log(ido.calculateMonths(vestingAt, block.timestamp), "months later after TGE");
        console.log(ido.calculateMonths(cliffEndsAt, block.timestamp), "months later after CLIFF");
        console.log("Today's date: November 10th, 2024 - ", block.timestamp);
        console.log(" ");

        console.log("User A: Has not claimed any tokens yet.");
        console.log(
            "Total Claimed - $SKR",
            ido.tokensClaimed(walletA),
            "Total Claimable - $SKR",
            ido.previewClaimableTokens(walletA)
        );
        console.log(" ");

        console.log("User B: Claimed TGE unlock but hasn't made a claim since TGE");
        console.log(
            "Total Claimed - $SKR",
            ido.tokensClaimed(walletB),
            "Total Claimable - $SKR",
            ido.previewClaimableTokens(walletB)
        );
        console.log(" ");

        console.log("User C: Claimed TGE unlock and claimed tokens on October 5 and November");
        console.log(
            "Total Claimed - $SKR",
            ido.tokensClaimed(walletC),
            "Total Claimable - $SKR",
            ido.previewClaimableTokens(walletC)
        );
        console.log(" ");

        // Today's date: November 10th, 2024 - 1731240000
        vm.warp(ido.vestingEndsAt() + 1 days);
        console.log(ido.calculateMonths(vestingAt, block.timestamp), "months later after TGE");
        console.log(ido.calculateMonths(cliffEndsAt, block.timestamp), "months later after CLIFF");
        console.log("Today's date: December 4, 2024 12 UTC - ", block.timestamp);
        console.log(" ");

        console.log("User A: Has not claimed any tokens yet.");
        console.log(
            "Total Claimed - $SKR",
            ido.tokensClaimed(walletA),
            "Total Claimable - $SKR",
            ido.previewClaimableTokens(walletA)
        );
        console.log(" ");

        console.log("User B: Claimed TGE unlock but hasn't made a claim since TGE");
        console.log(
            "Total Claimed - $SKR",
            ido.tokensClaimed(walletB),
            "Total Claimable - $SKR",
            ido.previewClaimableTokens(walletB)
        );
        console.log(" ");

        console.log("User C: Claimed TGE unlock and claimed tokens on October 5 and November");
        console.log(
            "Total Claimed - $SKR",
            ido.tokensClaimed(walletC),
            "Total Claimable - $SKR",
            ido.previewClaimableTokens(walletC)
        );
        console.log(" ");
    }
}
