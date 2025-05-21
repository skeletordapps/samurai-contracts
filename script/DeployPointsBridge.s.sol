// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {PointsBridge} from "../src/PointsBridge.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract DeployPointsBridge is Script {
    function run() external returns (PointsBridge pointsBridge) {
        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");

        address points = 0xDf0fDc572849f01CdaB35b80cA41Ce67051C8Dfe;

        vm.startBroadcast(privateKey);

        pointsBridge = new PointsBridge(points);
        vm.stopBroadcast();

        return pointsBridge;
    }

    function runForTests() external returns (PointsBridge pointsBridge, address points) {
        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");

        points = 0xDf0fDc572849f01CdaB35b80cA41Ce67051C8Dfe;

        vm.startBroadcast(privateKey);

        pointsBridge = new PointsBridge(points);

        vm.stopBroadcast();

        return (pointsBridge, points);
    }

    function testMock() public {}
}
