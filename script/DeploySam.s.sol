// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {Sam} from "../src/Sam.sol";

contract DeploySam is Script {
    function run() external returns (Sam sam) {
        string memory name = "SAMURAI";
        string memory symbol = "SAM";
        uint256 supply = 130_000_000 ether;

        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        sam = new Sam(name, symbol, supply);
        vm.stopBroadcast();

        return sam;
    }

    function testMock() public {}
}
