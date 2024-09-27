// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {LPStaking} from "../src/LPStaking.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SamMock} from "../src/mocks/SamMock.sol";
import {SamuraiPoints} from "../src/SamuraiPoints.sol";
import {IPoints} from "../src/interfaces/IPoints.sol";
import {console} from "forge-std/console.sol";

contract DeployLPStaking is Script {
    function run()
        external
        returns (LPStaking lpStaking, address lpToken, address rewardsToken, address gauge, address points)
    {
        lpToken = vm.envAddress("BASE_LP_TOKEN_ADDRESS");
        rewardsToken = vm.envAddress("BASE_REWARDS_TOKEN_ADDRESS");
        gauge = vm.envAddress("BASE_GAUGE_ADDRESS");

        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");
        uint256 minToStake = 30_000 ether;
        points = address(0);

        vm.startBroadcast(privateKey);

        lpStaking = new LPStaking(lpToken, rewardsToken, gauge, points, minToStake);
        vm.stopBroadcast();

        return (lpStaking, lpToken, rewardsToken, gauge, points);
    }

    function runForTests()
        external
        returns (LPStaking lpStaking, address lpToken, address rewardsToken, address gauge, address points)
    {
        lpToken = vm.envAddress("BASE_LP_TOKEN_ADDRESS");
        rewardsToken = vm.envAddress("BASE_REWARDS_TOKEN_ADDRESS");
        gauge = vm.envAddress("BASE_GAUGE_ADDRESS");

        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");
        uint256 minToStake = 30_000 ether;

        vm.startBroadcast(privateKey);

        SamuraiPoints sp = new SamuraiPoints();
        points = address(sp);

        lpStaking = new LPStaking(lpToken, rewardsToken, gauge, points, minToStake);
        sp.grantRole(IPoints.Roles.MINTER, address(lpStaking));

        vm.stopBroadcast();

        return (lpStaking, lpToken, rewardsToken, gauge, points);
    }

    function testMock() public {}
}
