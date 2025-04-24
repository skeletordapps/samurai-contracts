// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {USDCMock} from "../src/mocks/USDCMock.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {console} from "forge-std/console.sol";

contract DeployERC20 is Script {
    function run() external returns (ERC20Mock erc20Mock, USDCMock usdMock) {
        uint256 privateKey = vm.envUint("DEV_HOT_PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        erc20Mock = new ERC20Mock("BeraShit", "BES");
        usdMock = new USDCMock("BeraUSD", "BDC");

        vm.stopBroadcast();

        return (erc20Mock, usdMock);
    }

    function testMock() public {}
}
