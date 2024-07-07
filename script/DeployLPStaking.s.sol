// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {LPStaking} from "../src/LPStaking.sol";
import {console} from "forge-std/console.sol";

contract DeployLPStaking is Script {
    function run(bool isFork)
        external
        returns (LPStaking staking, address lpToken, address rewardsToken, address gauge)
    {
        lpToken = isFork ? vm.envAddress("BASE_TEST_LP_TOKEN_ADDRESS") : vm.envAddress("BASE_LP_TOKEN_ADDRESS");
        rewardsToken = vm.envAddress("BASE_REWARDS_TOKEN_ADDRESS");
        gauge = vm.envAddress("BASE_GAUGE_ADDRESS");

        vm.startBroadcast();
        staking = new LPStaking(lpToken, rewardsToken, gauge);
        vm.stopBroadcast();

        return (staking, lpToken, rewardsToken, gauge);
    }

    function testMock() public {}
}
