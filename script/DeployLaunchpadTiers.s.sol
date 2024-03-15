// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {LaunchpadTiers} from "../src/LaunchpadTiers.sol";

contract DeployLaunchpadTiers is Script {
    function run() external returns (LaunchpadTiers launchpadTiers) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        launchpadTiers = new LaunchpadTiers();
        vm.stopBroadcast();

        return launchpadTiers;
    }

    function testMock() public {}
}
