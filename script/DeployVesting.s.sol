// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {Vesting} from "../src/Vesting.sol";
import {IVesting} from "../src/interfaces/IVesting.sol";
import {console} from "forge-std/console.sol";
import {SamuraiTiers} from "../src/SamuraiTiers.sol";
import {ISamuraiTiers} from "../src/interfaces/ISamuraiTiers.sol";

contract DeployVesting is Script {
    function run() external returns (Vesting vesting) {
        uint256 totalPurchased = 1_000_000 ether;
        uint256 tgeReleasePercent = 0.15e18;
        IVesting.VestingType vestingType = IVesting.VestingType.LinearVesting;
        IVesting.Periods memory periods = IVesting.Periods({vestingDuration: 0, vestingAt: 0, cliff: 0});

        vm.startBroadcast();
        vesting = new Vesting(totalPurchased, tgeReleasePercent, vestingType, periods);
        vm.stopBroadcast();

        return vesting;
    }

    function runForTests(IVesting.VestingType _vestingType) external returns (Vesting vesting) {
        uint256 totalPurchased = 1_000_000 ether;
        uint256 tgeReleasePercent = 0.15e18;
        IVesting.Periods memory periods = IVesting.Periods({vestingDuration: 0, vestingAt: 0, cliff: 0});

        vm.startBroadcast();
        vesting = new Vesting(totalPurchased, tgeReleasePercent, _vestingType, periods);
        vm.stopBroadcast();

        return vesting;
    }

    function testMock() public {}
}
