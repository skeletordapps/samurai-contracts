// SPDX-License-Identifier: UNLINCENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {LPStakingV2} from "../src/LPStakingV2.sol";
import {console2} from "forge-std/console2.sol";

contract DeployLPStakingV2 is Script {
    function run()
        external
        returns (LPStakingV2 staking, address lpToken, address rewardsToken, address gauge, address gaugeRewardsToken)
    {
        lpToken = vm.envAddress("OPTIMISM_LP_TOKEN_ADDRESS");
        rewardsToken = vm.envAddress("OPTIMISM_REWARDS_TOKEN_ADDRESS");
        gauge = vm.envAddress("OPTIMISM_GAUGE_ADDRESS");
        gaugeRewardsToken = vm.envAddress("OPTIMISM_GAUGE_REWARDS_TOKEN_ADDRESS");

        vm.startBroadcast();
        staking = new LPStakingV2(lpToken, rewardsToken, gauge, gaugeRewardsToken);
        vm.stopBroadcast();

        return (staking, lpToken, rewardsToken, gauge, gaugeRewardsToken);
    }

    function testMock() public {}
}
