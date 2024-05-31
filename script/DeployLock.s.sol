// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {SamLock} from "../src/SamLock.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SamMock} from "../src/mocks/SamMock.sol";
import {console2} from "forge-std/console2.sol";

contract DeployLock is Script {
    function run() external returns (SamLock lock, address sam) {
        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");
        uint256 minToLock = 30_000 ether;
        address samurai = 0xed1779845520339693CDBffec49a74246E7D671b;

        vm.startBroadcast(privateKey);

        lock = new SamLock(samurai, minToLock);
        vm.stopBroadcast();

        return (lock, samurai);
    }

    function testMock() public {}
}
