// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {MissingPoints} from "../src/MissingPoints.sol";
import {SamuraiPoints} from "../src/SamuraiPoints.sol";
import {IPoints} from "../src/interfaces/IPoints.sol";

contract DeployMissingPoints is Script {
    function run() external returns (MissingPoints missingPoints, address points, address lock) {
        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");

        points = 0xDf0fDc572849f01CdaB35b80cA41Ce67051C8Dfe;
        // lock chirppad 0xD450D58A1B61132FF867ca8e6BB878C3669AC292
        // lock v2 0xA5c6584d6115cC26C956834849B4051bd200973a
        lock = 0xA5c6584d6115cC26C956834849B4051bd200973a;

        vm.startBroadcast(privateKey);

        missingPoints = new MissingPoints(points, lock);
        vm.stopBroadcast();

        return (missingPoints, points, lock);
    }

    function runForTests(address _lock) external returns (MissingPoints missingPoints, address points, address lock) {
        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");

        points = 0xDf0fDc572849f01CdaB35b80cA41Ce67051C8Dfe;
        lock = _lock;

        vm.startBroadcast(privateKey);

        missingPoints = new MissingPoints(points, lock);
        vm.stopBroadcast();

        return (missingPoints, points, lock);
    }
}
