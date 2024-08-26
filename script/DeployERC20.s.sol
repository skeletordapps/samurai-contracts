// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {USDCMock} from "../src/mocks/USDCMock.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {console} from "forge-std/console.sol";

contract DeployERC20 is Script {
    function run() external returns (USDCMock usdcMock, ERC20Mock erc20Mock) {
        vm.startBroadcast();
        usdcMock = new USDCMock("FakeUSDC", "fUSDC");
        erc20Mock = new ERC20Mock("Skywalker", "SKR");
        vm.stopBroadcast();

        return (usdcMock, erc20Mock);
    }

    function testMock() public {}
}
