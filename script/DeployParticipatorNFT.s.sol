// SPDX-License-Identifier: UNLINCENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {ParticipatorNFT} from "../src/ParticipatorNFT.sol";
import {USDCMock} from "../src/mocks/USDCMock.sol";
import {console2} from "forge-std/console2.sol";

contract DeployParticipatorNFT is Script {
    function run() external returns (ParticipatorNFT participatorNFT) {
        address[] memory acceptedTokens;

        uint256 minA = 1;
        uint256 maxA = 1;
        uint256 minB = 1;
        uint256 maxB = 3;
        uint256 minPublic = 1;
        uint256 maxPublic = 5;
        uint256 pricePerToken = 620 * 1e6;
        uint256 maxAllocations = 200;

        vm.startBroadcast();

        acceptedTokens = new address[](2);
        acceptedTokens[0] = vm.envAddress("BASE_USDC_ADDRESS");
        acceptedTokens[1] = vm.envAddress("BASE_USDC_BASE_ADDRESS");

        participatorNFT = new ParticipatorNFT(
            acceptedTokens, minA, maxA, minB, maxB, minPublic, maxPublic, pricePerToken, maxAllocations
        );
        vm.stopBroadcast();

        return participatorNFT;
    }

    function testMock() public {}
}
