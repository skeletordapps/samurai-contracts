// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {SamLock} from "../src/SamLock.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SamuraiPoints} from "../src/SamuraiPoints.sol";
import {IPoints} from "../src/interfaces/IPoints.sol";
import {console} from "forge-std/console.sol";

contract DeployLock is Script {
    function run() external returns (SamLock lock, address pastLock, address sam, address points) {
        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");
        uint256 minToLock = 1 ether;

        pastLock = 0xfb691697BDAf1857C748C004cC7dab3d234E062E;
        sam = 0xed1779845520339693CDBffec49a74246E7D671b;
        points = 0xDf0fDc572849f01CdaB35b80cA41Ce67051C8Dfe;

        vm.startBroadcast(privateKey);

        lock = new SamLock(sam, pastLock, points, minToLock);
        vm.stopBroadcast();

        return (lock, pastLock, sam, points);
    }

    function runForTests() external returns (SamLock lock, address pastLock, address sam, address points) {
        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");
        uint256 minToLock = 30_000 ether;
        pastLock = 0xfb691697BDAf1857C748C004cC7dab3d234E062E;
        sam = 0xed1779845520339693CDBffec49a74246E7D671b;
        points = 0xDf0fDc572849f01CdaB35b80cA41Ce67051C8Dfe;

        vm.startBroadcast(privateKey);

        lock = new SamLock(sam, pastLock, points, minToLock);

        vm.stopBroadcast();

        return (lock, pastLock, sam, points);
    }

    function testMock() public {}
}
