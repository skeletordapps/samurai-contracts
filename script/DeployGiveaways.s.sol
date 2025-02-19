// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {Giveaways} from "../src/Giveaways.sol";
import {IGiveaways} from "../src/interfaces/IGiveaways.sol";
import {console} from "forge-std/console.sol";
import {SamuraiPoints} from "../src/SamuraiPoints.sol";
import {IPoints} from "../src/interfaces/IPoints.sol";

contract DeployGiveaways is Script {
    function run() external returns (Giveaways giveaways, address points) {
        uint256 privateKey = block.chainid == 8453 ? vm.envUint("PRIVATE_KEY") : vm.envUint("DEV_HOT_PRIVATE_KEY");
        points = 0xDf0fDc572849f01CdaB35b80cA41Ce67051C8Dfe;
        vm.startBroadcast(privateKey);
        giveaways = new Giveaways(points);
        vm.stopBroadcast();

        return (giveaways, points);
    }

    function testMock() public {}
}
