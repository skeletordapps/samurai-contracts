// // SPDX-License-Identifier: UNLINCENSED
// pragma solidity 0.8.28;

// import {Test} from "forge-std/Test.sol";
// import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
// import {Vesting} from "../src/Vesting.sol";
// import {DeployVesting} from "../script/DeployVesting.s.sol";
// import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
// import {IVesting} from "../src/interfaces/IVesting.sol";
// import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";
// import {BokkyPooBahsDateTimeLibrary} from "@BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";

// contract VestingCliff2Test is Test {
//     uint256 fork;
//     string public RPC_URL;

//     DeployVesting deployer;
//     Vesting vesting;

//     address owner;
//     address bob;
//     address mary;
//     address paul;

//     uint256 totalPurchased;
//     uint256 tgeReleasePercent;
//     uint256 vestingDuration;
//     uint256 vestingAt;
//     uint256 cliff;

//     function setUp() public virtual {
//         RPC_URL = vm.envString("BASE_RPC_URL");
//         fork = vm.createFork(RPC_URL);
//         vm.selectFork(fork);

//         deployer = new DeployVesting();
//         vesting = deployer.runForNoCliffNoVesting();
//         owner = vesting.owner();

//         bob = vm.addr(1);
//         vm.label(bob, "bob");

//         mary = vm.addr(2);
//         vm.label(mary, "mary");

//         paul = vm.addr(3);
//         vm.label(paul, "paul");

//         totalPurchased = vesting.totalPurchased();
//         tgeReleasePercent = vesting.tgeReleasePercent();
//         (vestingDuration, vestingAt, cliff) = vesting.periods();
//     }

//     function testConstructor() public view {
//         assertEq(vestingDuration, 0);
//         assertEq(vestingAt, block.timestamp);
//         assertEq(cliff, 0);
//     }

//     modifier idoTokenFilled(bool sendHalf) {
//         vm.warp(block.timestamp + 30 minutes);
//         address idoToken = vesting.token();
//         uint256 expectedAmountOfTokens = 1_000_000 ether;

//         if (sendHalf) expectedAmountOfTokens = expectedAmountOfTokens / 2;

//         deal(idoToken, owner, expectedAmountOfTokens);

//         vm.startPrank(owner);
//         ERC20(idoToken).approve(address(vesting), expectedAmountOfTokens);
//         vesting.fillIDOToken(expectedAmountOfTokens);
//         vm.stopPrank();
//         _;
//     }
// }
