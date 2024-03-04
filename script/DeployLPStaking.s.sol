// SPDX-License-Identifier: UNLINCENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {LPStaking} from "../src/LPStaking.sol";
import {console2} from "forge-std/console2.sol";

contract DeployLPStaking is Script {
    function run(bool isFork)
        external
        returns (LPStaking staking, address lpToken, address rewardsToken, address gauge)
    {
        lpToken = isFork ? vm.envAddress("TEST_LP_TOKEN_ADDRESS") : vm.envAddress("SAM_LP_TOKEN_ADDRESS");
        rewardsToken = vm.envAddress("REWARDS_TOKEN_ADDRESS");
        gauge = vm.envAddress("GAUGE_TOKEN_ADDRESS");

        vm.startBroadcast();
        staking = new LPStaking(lpToken, rewardsToken, gauge);
        vm.stopBroadcast();

        return (staking, lpToken, rewardsToken, gauge);
    }

    function testMock() public {}
}
