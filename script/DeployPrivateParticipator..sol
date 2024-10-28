// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {PrivateParticipator} from "../src/PrivateParticipator.sol";

contract DeployPrivateParticipator is Script {
    function run() external returns (PrivateParticipator participator) {
        uint256 maxAllocations = 200_000 * 1e6;
        (address[] memory wallets, uint256[] memory ranges) = loadWallets();

        vm.startBroadcast();
        participator = new PrivateParticipator(vm.envAddress("BASE_USDC_ADDRESS"), maxAllocations, wallets, ranges);
        vm.stopBroadcast();

        return participator;
    }

    function loadWallets() internal pure returns (address[] memory wallets, uint256[] memory ranges) {
        wallets = new address[](2);
        ranges = new uint256[](2);

        wallets[0] = vm.addr(1);
        ranges[0] = 500_000 ether;

        wallets[1] = vm.addr(2);
        ranges[1] = 500_000 ether;

        return (wallets, ranges);
    }

    function testMock() public {}
}
