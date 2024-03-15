// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {SamLock} from "../src/SamLock.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract DeployLock is Script {
    function run() external returns (SamLock lock, address sam) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        ERC20Mock token = new ERC20Mock();

        lock = new SamLock(address(token));
        vm.stopBroadcast();

        return (lock, address(token));
    }

    function testMock() public {}
}
