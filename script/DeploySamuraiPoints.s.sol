// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {SamuraiPoints} from "../src/SamuraiPoints.sol";
import {DeployIDO} from "../script/DeployIDO.s.sol";
import {console} from "forge-std/console.sol";

contract DeploySamuraiPoints is Script {
    function run() external returns (SamuraiPoints samuraiPoints) {
        vm.startBroadcast();
        samuraiPoints = new SamuraiPoints();
        vm.stopBroadcast();

        return samuraiPoints;
    }

    function testMock() public {}
}
