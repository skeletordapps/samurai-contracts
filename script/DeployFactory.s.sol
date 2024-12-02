// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {Factory} from "../src/Factory.sol";
import {IFactory} from "../src/interfaces/IFactory.sol";
import {DeployIDO} from "../script/DeployIDO.s.sol";
import {console} from "forge-std/console.sol";

contract DeployFactory is Script {
    function run() external returns (Factory factory) {
        vm.startBroadcast();
        factory = new Factory();
        vm.stopBroadcast();

        return factory;
    }

    function runForTests() external returns (Factory factory) {
        vm.startBroadcast();
        factory = new Factory();
        vm.stopBroadcast();

        return factory;
    }

    function testMock() public {}
}
