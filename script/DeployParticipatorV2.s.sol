// SPDX-License-Identifier: UNLINCENSED
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {ParticipatorV2} from "../src/ParticipatorV2.sol";
import {IParticipator} from "../src/interfaces/IParticipator.sol";
import {USDCMock} from "../src/mocks/USDCMock.sol";
import {console2} from "forge-std/console2.sol";
import {SamuraiTiers} from "../src/SamuraiTiers.sol";
import {ISamuraiTiers} from "../src/interfaces/ISamuraiTiers.sol";

contract DeployParticipatorV2 is Script {
    function run() external returns (ParticipatorV2 participator) {
        address samuraiTiers = address(0);
        address[] memory acceptedTokens;
        uint256 totalMax = 200_000 * 1e6;

        IParticipator.WalletRange[] memory ranges = new IParticipator.WalletRange[](6);

        IParticipator.WalletRange memory range1 = IParticipator.WalletRange("Ronin", 10 * 1e6, 20 * 1e6);
        IParticipator.WalletRange memory range2 = IParticipator.WalletRange("Gokenin", 30 * 1e6, 40 * 1e6);
        IParticipator.WalletRange memory range3 = IParticipator.WalletRange("Goshi", 50 * 1e6, 60 * 1e6);
        IParticipator.WalletRange memory range4 = IParticipator.WalletRange("Hatamoto", 70 * 1e6, 80 * 1e6);
        IParticipator.WalletRange memory range5 = IParticipator.WalletRange("Shogun", 90 * 1e6, 100 * 1e6);
        IParticipator.WalletRange memory range6 = IParticipator.WalletRange("Public", 10 * 1e6, 200 * 1e6);

        ranges[0] = range1;
        ranges[1] = range2;
        ranges[2] = range3;
        ranges[3] = range4;
        ranges[4] = range5;
        ranges[5] = range6;

        vm.startBroadcast();
        if (block.chainid == 31337) {
            acceptedTokens = new address[](1);
            USDCMock usdcMock = new USDCMock("USDC Mock", "USDM");
            acceptedTokens[0] = address(usdcMock);
        } else {
            acceptedTokens = new address[](1);
            acceptedTokens[0] = vm.envAddress("BASE_USDC_ADDRESS");
        }
        participator = new ParticipatorV2(samuraiTiers, acceptedTokens, totalMax, ranges);
        vm.stopBroadcast();

        return participator;
    }

    // Deploys the Samurai tiers for tests
    function runForTests() external returns (ParticipatorV2 participator) {
        address[] memory acceptedTokens;
        uint256 totalMax = 200_000 * 1e6;

        IParticipator.WalletRange[] memory ranges = new IParticipator.WalletRange[](6);

        IParticipator.WalletRange memory range1 = IParticipator.WalletRange("Ronin", 10 * 1e6, 20 * 1e6);
        IParticipator.WalletRange memory range2 = IParticipator.WalletRange("Gokenin", 30 * 1e6, 40 * 1e6);
        IParticipator.WalletRange memory range3 = IParticipator.WalletRange("Goshi", 50 * 1e6, 60 * 1e6);
        IParticipator.WalletRange memory range4 = IParticipator.WalletRange("Hatamoto", 70 * 1e6, 80 * 1e6);
        IParticipator.WalletRange memory range5 = IParticipator.WalletRange("Shogun", 90 * 1e6, 100 * 1e6);
        IParticipator.WalletRange memory range6 = IParticipator.WalletRange("Public", 10 * 1e6, 200 * 1e6);

        ranges[0] = range1;
        ranges[1] = range2;
        ranges[2] = range3;
        ranges[3] = range4;
        ranges[4] = range5;
        ranges[5] = range6;

        vm.startBroadcast();
        SamuraiTiers samuraiTiers = new SamuraiTiers();
        addInitialTiers(samuraiTiers);

        if (block.chainid == 31337) {
            acceptedTokens = new address[](1);
            USDCMock usdcMock = new USDCMock("USDC Mock", "USDM");
            acceptedTokens[0] = address(usdcMock);
        } else {
            acceptedTokens = new address[](1);
            acceptedTokens[0] = vm.envAddress("BASE_USDC_ADDRESS");
        }
        participator = new ParticipatorV2(address(samuraiTiers), acceptedTokens, totalMax, ranges);
        vm.stopBroadcast();

        return participator;
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
