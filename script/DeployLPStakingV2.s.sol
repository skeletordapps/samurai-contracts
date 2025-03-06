// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {LPStakingV2} from "../src/LPStakingV2.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SamMock} from "../src/mocks/SamMock.sol";
import {SamuraiPoints} from "../src/SamuraiPoints.sol";
import {IPoints} from "../src/interfaces/IPoints.sol";
import {console} from "forge-std/console.sol";

contract DeployLPStakingV2 is Script {
    function run()
        external
        returns (LPStakingV2 lpStaking, address lpToken, address rewardsToken, address gauge, address points)
    {
        lpToken = vm.envAddress("BASE_LP_TOKEN_ADDRESS");
        rewardsToken = vm.envAddress("BASE_GAUGE_REWARDS_TOKEN_ADDRESS");
        gauge = vm.envAddress("BASE_GAUGE_ADDRESS");

        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");
        uint256 pointsPerToken = 1071 ether;
        points = address(0xDf0fDc572849f01CdaB35b80cA41Ce67051C8Dfe);

        vm.startBroadcast(privateKey);

        lpStaking = new LPStakingV2(lpToken, rewardsToken, gauge, points, pointsPerToken);
        vm.stopBroadcast();

        return (lpStaking, lpToken, rewardsToken, gauge, points);
    }

    function runForTests()
        external
        returns (LPStakingV2 lpStaking, address lpToken, address rewardsToken, address gauge, address points)
    {
        lpToken = vm.envAddress("BASE_LP_TOKEN_ADDRESS");
        rewardsToken = vm.envAddress("BASE_GAUGE_REWARDS_TOKEN_ADDRESS");
        gauge = vm.envAddress("BASE_GAUGE_ADDRESS");

        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");

        uint256 pointsPerToken = 1071 ether;

        vm.startBroadcast(privateKey);

        SamuraiPoints sp = new SamuraiPoints();
        points = address(sp);

        lpStaking = new LPStakingV2(lpToken, rewardsToken, gauge, points, pointsPerToken);
        sp.grantRole(IPoints.Roles.MINTER, address(lpStaking));

        vm.stopBroadcast();

        return (lpStaking, lpToken, rewardsToken, gauge, points);
    }

    function runForInvariantTests()
        external
        returns (LPStakingV2 lpStaking, address lpToken, address rewardsToken, address gauge, address points)
    {
        lpToken = vm.envAddress("BASE_LP_TOKEN_ADDRESS");
        rewardsToken = vm.envAddress("BASE_GAUGE_REWARDS_TOKEN_ADDRESS");
        gauge = vm.envAddress("BASE_GAUGE_ADDRESS");

        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");

        uint256 pointsPerToken = 1071 ether;

        vm.startBroadcast(privateKey);

        SamuraiPoints sp = new SamuraiPoints();
        points = address(sp);

        lpStaking = new LPStakingV2(lpToken, rewardsToken, gauge, points, pointsPerToken);
        sp.grantRole(IPoints.Roles.MINTER, address(lpStaking));

        vm.stopBroadcast();

        return (lpStaking, lpToken, rewardsToken, gauge, points);
    }

    function testMock() public {}
}
