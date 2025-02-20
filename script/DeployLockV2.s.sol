// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {SamLockV2} from "../src/SamLockV2.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SamuraiPoints} from "../src/SamuraiPoints.sol";
import {IPoints} from "../src/interfaces/IPoints.sol";
import {console} from "forge-std/console.sol";

contract DeployLockV2 is Script {
    function run() external returns (SamLockV2 lock, address sam, address points) {
        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");
        uint256 minToLock = 1 ether;

        sam = 0xed1779845520339693CDBffec49a74246E7D671b;
        points = 0xDf0fDc572849f01CdaB35b80cA41Ce67051C8Dfe;

        vm.startBroadcast(privateKey);

        lock = new SamLockV2(sam, points, minToLock);
        vm.stopBroadcast();

        return (lock, sam, points);
    }

    function runForTests() external returns (SamLockV2 lock, address sam, address points) {
        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");
        uint256 minToLock = 30_000 ether;

        sam = 0xed1779845520339693CDBffec49a74246E7D671b;
        points = 0xDf0fDc572849f01CdaB35b80cA41Ce67051C8Dfe;

        vm.startBroadcast(privateKey);

        lock = new SamLockV2(sam, points, minToLock);

        vm.stopBroadcast();

        return (lock, sam, points);
    }

    function testMock() public {}
}
