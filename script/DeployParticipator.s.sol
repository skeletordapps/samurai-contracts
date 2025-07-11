// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {Participator} from "../src/Participator.sol";
import {USDCMock} from "../src/mocks/USDCMock.sol";
import {console} from "forge-std/console.sol";

contract DeployParticipator is Script {
    function run() external returns (Participator participator) {
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
        participator = new Participator(acceptedTokens, min, max, totalMax);
        vm.stopBroadcast();

        return participator;
    }

    function testMock() public {}
}
