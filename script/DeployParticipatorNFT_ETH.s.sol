// SPDX-License-Identifier: UNLINCENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {ParticipatorNFT_ETH} from "../src/ParticipatorNFT_ETH.sol";

contract DeployParticipatorNFT_ETH is Script {
    function run() external returns (ParticipatorNFT_ETH participatorNFT_ETH) {
        vm.startBroadcast();
        participatorNFT_ETH = new ParticipatorNFT_ETH({
            _minA: 1,
            _maxA: 5,
            _minB: 0,
            _maxB: 0,
            _minPublic: 0,
            _maxPublic: 0,
            _pricePerToken: 0.065 ether,
            _maxAllocations: 500
        });
        vm.stopBroadcast();

        return participatorNFT_ETH;
    }

    function testMock() public {}
}
