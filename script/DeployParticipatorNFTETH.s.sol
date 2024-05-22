// SPDX-License-Identifier: UNLINCENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {ParticipatorNFTETH} from "../src/ParticipatorNFTETH.sol";

contract DeployParticipatorNFTETH is Script {
    function run() external returns (ParticipatorNFTETH participatorNFTETH) {
        vm.startBroadcast();
        participatorNFTETH = new ParticipatorNFTETH({
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

        return participatorNFTETH;
    }

    function runForTests() external returns (ParticipatorNFTETH participatorNFTETH) {
        vm.startBroadcast();
        participatorNFTETH = new ParticipatorNFTETH({
            _minA: 2,
            _maxA: 5,
            _minB: 0,
            _maxB: 0,
            _minPublic: 0,
            _maxPublic: 0,
            _pricePerToken: 0.065 ether,
            _maxAllocations: 500
        });
        vm.stopBroadcast();

        return participatorNFTETH;
    }

    function testMock() public {}
}
