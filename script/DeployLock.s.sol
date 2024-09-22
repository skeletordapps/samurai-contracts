// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {SamLock} from "../src/SamLock.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SamMock} from "../src/mocks/SamMock.sol";
import {SamuraiPoints} from "../src/SamuraiPoints.sol";
import {IPoints} from "../src/interfaces/IPoints.sol";
import {console} from "forge-std/console.sol";

contract DeployLock is Script {
    function run() external returns (SamLock lock, address sam, address points) {
        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");
        uint256 minToLock = 30_000 ether;
        sam = 0xed1779845520339693CDBffec49a74246E7D671b;
        points = address(0);

        vm.startBroadcast(privateKey);

        lock = new SamLock(sam, points, minToLock);
        vm.stopBroadcast();

        return (lock, sam, points);
    }

    function runForTests() external returns (SamLock lock, address sam, address points) {
        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");
        uint256 minToLock = 30_000 ether;
        sam = 0xed1779845520339693CDBffec49a74246E7D671b;

        vm.startBroadcast(privateKey);

        SamuraiPoints sp = new SamuraiPoints();
        points = address(sp);

        lock = new SamLock(sam, points, minToLock);
        sp.grantRole(IPoints.Roles.MINTER, address(lock));

        vm.stopBroadcast();

        return (lock, sam, points);
    }

    function testMock() public {}
}
