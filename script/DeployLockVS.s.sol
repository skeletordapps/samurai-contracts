// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {SamLockVS} from "../src/SamLockVS.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SamuraiPoints} from "../src/SamuraiPoints.sol";
import {IPoints} from "../src/interfaces/IPoints.sol";
import {console} from "forge-std/console.sol";

contract DeployLockVS is Script {
    function run() external returns (SamLockVS lock, address sam) {
        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");
        uint256 minToLock = 1 ether;

        sam = 0xCC5D9cc0d781d7F41F6809c0E8356C15942b775E;

        vm.startBroadcast(privateKey);
        lock = new SamLockVS(sam, minToLock);
        vm.stopBroadcast();

        return (lock, sam);
    }

    function runForTests() external returns (SamLockVS lock, address sam) {
        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");
        uint256 minToLock = 30_000 ether;

        sam = 0xCC5D9cc0d781d7F41F6809c0E8356C15942b775E;

        vm.startBroadcast(privateKey);

        lock = new SamLockVS(sam, minToLock);

        vm.stopBroadcast();

        return (lock, sam);
    }

    function testMock() public {}
}
