// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {ParticipatorNftOpen} from "../src/ParticipatorNftOpen.sol";
import {USDCMock} from "../src/mocks/USDCMock.sol";

contract DeployParticipatorNftOpen is Script {
    function run() external returns (ParticipatorNftOpen participatorNftOpen) {
        address acceptedToken = vm.envAddress("BASE_USDC_ADDRESS");
        uint256 min = 1;
        uint256 max = 10;
        uint256 pricePerToken = 50e6;
        uint256 maxAllocations = 400;

        vm.startBroadcast();
        participatorNftOpen = new ParticipatorNftOpen(acceptedToken, min, max, pricePerToken, maxAllocations);
        vm.stopBroadcast();

        return participatorNftOpen;
    }

    function testMock() public {}
}
