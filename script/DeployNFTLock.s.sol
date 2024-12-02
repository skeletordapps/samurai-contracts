// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {NFTLock} from "../src/NFTLock.sol";
import {SamuraiPoints} from "../src/SamuraiPoints.sol";
import {IPoints} from "../src/interfaces/IPoints.sol";
import {console} from "forge-std/console.sol";

contract DeployNFTLock is Script {
    function run() external returns (NFTLock nftLock) {
        address samNFT = 0x519eD34150300dC0D04d50a5Ff401177A92b4406;
        address samuraiPoints = address(0);
        vm.startBroadcast();
        nftLock = new NFTLock(samNFT, samuraiPoints);
        vm.stopBroadcast();

        return nftLock;
    }

    function runForTests() external returns (NFTLock nftLock, address samuraiPoints) {
        address samNFT = 0x519eD34150300dC0D04d50a5Ff401177A92b4406;

        vm.startBroadcast();
        SamuraiPoints sp = new SamuraiPoints();

        nftLock = new NFTLock(samNFT, address(sp));
        sp.grantRole(IPoints.Roles.BOOSTER, address(nftLock));
        vm.stopBroadcast();

        return (nftLock, address(sp));
    }

    function testMock() public {}
}
