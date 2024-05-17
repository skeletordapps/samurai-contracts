// SPDX-License-Identifier: UNLINCENSED
pragma solidity ^0.8.23;

import {Script} from "forge-std/Script.sol";
import {ParticipatorV1} from "../src/IDO/ParticipatorV1.sol";
import {USDCMock} from "../src/mocks/USDCMock.sol";
import {console2} from "forge-std/console2.sol";

contract DeployParticipatorV1 is Script {
    function run() external returns (ParticipatorV1 participator) {
        address[] memory acceptedTokens;

        uint256 min = 100 * 1e6;
        uint256 max = 2000 * 1e6;
        uint256 totalMax = 200_000 * 1e6;

        vm.startBroadcast();
        if (block.chainid == 31337) {
            acceptedTokens = new address[](2);
            USDCMock usdcMock = new USDCMock("USDC Mock", "USDM");
            USDCMock usdcBMock = new USDCMock("USDC Base Mock", "USDbCM");
            acceptedTokens[0] = address(usdcMock);
            acceptedTokens[1] = address(usdcBMock);
        } else {
            acceptedTokens = new address[](2);
            acceptedTokens[0] = vm.envAddress("BASE_USDC_ADDRESS");
            acceptedTokens[1] = vm.envAddress("BASE_USDC_BASE_ADDRESS");
        }
        participator = new ParticipatorV1(acceptedTokens, min, max, totalMax);
        vm.stopBroadcast();

        return participator;
    }

    function testMock() public {}
}
