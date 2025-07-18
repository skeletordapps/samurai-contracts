// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {SamuraiTiers} from "../src/SamuraiTiers.sol";
import {ISamuraiTiers} from "../src/interfaces/ISamuraiTiers.sol";
import {console} from "forge-std/console.sol";

contract DeploySamuraiTiers is Script {
    function run() external returns (SamuraiTiers samuraiTiers) {
        address _nftLock = 0x45c085699Fe78873D5C28B02d153CFd90379E424;
        address _lock = 0xfb691697BDAf1857C748C004cC7dab3d234E062E;
        address _lockV2 = 0xD450D58A1B61132FF867ca8e6BB878C3669AC292;
        address _lockV3 = 0xA5c6584d6115cC26C956834849B4051bd200973a;
        address _lpGauge = 0xf96Bc096dd1E52dcE4d595B6C4B8c5d2200db1E5;

        vm.startBroadcast();
        samuraiTiers = new SamuraiTiers(_nftLock, _lock, _lockV2, _lockV3, _lpGauge);
        addInitialTiers(samuraiTiers);

        vm.stopBroadcast();

        return samuraiTiers;
    }

    function runForTests() external returns (SamuraiTiers samuraiTiers) {
        address _nftLock = 0x45c085699Fe78873D5C28B02d153CFd90379E424;
        address _lock = 0xfb691697BDAf1857C748C004cC7dab3d234E062E;
        address _lockV2 = 0xD450D58A1B61132FF867ca8e6BB878C3669AC292;
        address _lockV3 = 0xA5c6584d6115cC26C956834849B4051bd200973a;
        address _lpGauge = 0xf96Bc096dd1E52dcE4d595B6C4B8c5d2200db1E5;

        vm.startBroadcast();
        samuraiTiers = new SamuraiTiers(_nftLock, _lock, _lockV2, _lockV3, _lpGauge);
        vm.stopBroadcast();

        return samuraiTiers;
    }

    function addInitialTiers(SamuraiTiers samuraiTiers) public {
        ISamuraiTiers.Tier memory Ronin = ISamuraiTiers.Tier("Ronin", 0, 15_000 ether, 29_999 ether, 20 ether, 44 ether);
        ISamuraiTiers.Tier memory Gokenin =
            ISamuraiTiers.Tier("Gokenin", 0, 30_000 ether, 59_999 ether, 45 ether, 90 ether);
        ISamuraiTiers.Tier memory Goshi =
            ISamuraiTiers.Tier("Goshi", 0, 60_000 ether, 99_999 ether, 91 ether, 150 ether);
        ISamuraiTiers.Tier memory Hatamoto =
            ISamuraiTiers.Tier("Hatamoto", 0, 100_000 ether, 199_999 ether, 151 ether, 300 ether);
        ISamuraiTiers.Tier memory Shogun =
            ISamuraiTiers.Tier("Shogun", 1, 200_000 ether, 999_999_999 ether, 301 ether, 999_999_999 ether);

        samuraiTiers.addTier(
            Ronin.name, Ronin.numOfSamNfts, Ronin.minLocking, Ronin.maxLocking, Ronin.minLPStaking, Ronin.maxLPStaking
        );

        samuraiTiers.addTier(
            Gokenin.name,
            Gokenin.numOfSamNfts,
            Gokenin.minLocking,
            Gokenin.maxLocking,
            Gokenin.minLPStaking,
            Gokenin.maxLPStaking
        );

        samuraiTiers.addTier(
            Goshi.name, Goshi.numOfSamNfts, Goshi.minLocking, Goshi.maxLocking, Goshi.minLPStaking, Goshi.maxLPStaking
        );

        samuraiTiers.addTier(
            Hatamoto.name,
            Hatamoto.numOfSamNfts,
            Hatamoto.minLocking,
            Hatamoto.maxLocking,
            Hatamoto.minLPStaking,
            Hatamoto.maxLPStaking
        );

        samuraiTiers.addTier(
            Shogun.name,
            Shogun.numOfSamNfts,
            Shogun.minLocking,
            Shogun.maxLocking,
            Shogun.minLPStaking,
            Shogun.maxLPStaking
        );
    }

    function testMock() public {}
}
