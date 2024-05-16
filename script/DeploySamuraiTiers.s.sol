// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {SamuraiTiers} from "../src/SamuraiTiers.sol";
import {ISamuraiTiers} from "../src/interfaces/ISamuraiTiers.sol";

contract DeploySamuraiTiers is Script {
    function run() external returns (SamuraiTiers samuraiTiers) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);

        samuraiTiers = new SamuraiTiers();
        addInitialTiers(samuraiTiers);

        vm.stopBroadcast();

        return samuraiTiers;
    }

    function runForTests() external returns (SamuraiTiers samuraiTiers) {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        samuraiTiers = new SamuraiTiers();
        vm.stopBroadcast();

        return samuraiTiers;
    }

    function addInitialTiers(SamuraiTiers samuraiTiers) public {
        ISamuraiTiers.Tier memory Ronin =
            ISamuraiTiers.Tier("Ronin", 0, 15_000 ether, 29_999 ether, 20 ether, 44 ether, 15_000);
        ISamuraiTiers.Tier memory Gokenin =
            ISamuraiTiers.Tier("Gokenin", 0, 30_000 ether, 59_999 ether, 45 ether, 90 ether, 30_000);
        ISamuraiTiers.Tier memory Goshi =
            ISamuraiTiers.Tier("Goshi", 0, 60_000 ether, 99_999 ether, 91 ether, 150 ether, 60_000);
        ISamuraiTiers.Tier memory Hatamoto =
            ISamuraiTiers.Tier("Hatamoto", 0, 100_000 ether, 199_999 ether, 151 ether, 300 ether, 100_000);
        ISamuraiTiers.Tier memory Shogun =
            ISamuraiTiers.Tier("Shogun", 1, 200_000 ether, 999_999_999 ether, 301 ether, 999_999_999 ether, 200_000);

        samuraiTiers.addTier(
            Ronin.name,
            Ronin.numOfSamNfts,
            Ronin.minLocking,
            Ronin.maxLocking,
            Ronin.minLPStaking,
            Ronin.maxLPStaking,
            Ronin.samuraiPoints
        );

        samuraiTiers.addTier(
            Gokenin.name,
            Gokenin.numOfSamNfts,
            Gokenin.minLocking,
            Gokenin.maxLocking,
            Gokenin.minLPStaking,
            Gokenin.maxLPStaking,
            Gokenin.samuraiPoints
        );

        samuraiTiers.addTier(
            Goshi.name,
            Goshi.numOfSamNfts,
            Goshi.minLocking,
            Goshi.maxLocking,
            Goshi.minLPStaking,
            Goshi.maxLPStaking,
            Goshi.samuraiPoints
        );

        samuraiTiers.addTier(
            Hatamoto.name,
            Hatamoto.numOfSamNfts,
            Hatamoto.minLocking,
            Hatamoto.maxLocking,
            Hatamoto.minLPStaking,
            Hatamoto.maxLPStaking,
            Hatamoto.samuraiPoints
        );

        samuraiTiers.addTier(
            Shogun.name,
            Shogun.numOfSamNfts,
            Shogun.minLocking,
            Shogun.maxLocking,
            Shogun.minLPStaking,
            Shogun.maxLPStaking,
            Shogun.samuraiPoints
        );
    }

    function testMock() public {}
}
