// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {USDCMock} from "../src/mocks/USDCMock.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {console} from "forge-std/console.sol";

contract DeployERC20 is Script {
    function run() external returns (ERC20Mock erc20Mock) {
        uint256 privateKey = block.chainid == 8453 ? vm.envUint("PRIVATE_KEY") : vm.envUint("DEV_HOT_PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        // usdcMock = new USDCMock("FakeUSDC", "fUSDC");
        erc20Mock = new ERC20Mock("Skywalker", "SKR");
        vm.stopBroadcast();

        return (erc20Mock);
    }

    function testMock() public {}
}
