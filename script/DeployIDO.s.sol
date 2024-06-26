// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {IDO} from "../src/IDO.sol";
import {IIDO} from "../src/interfaces/IIDO.sol";
import {USDCMock} from "../src/mocks/USDCMock.sol";
import {console2} from "forge-std/console2.sol";
import {SamuraiTiers} from "../src/SamuraiTiers.sol";
import {ISamuraiTiers} from "../src/interfaces/ISamuraiTiers.sol";

contract DeployIDO is Script {
    function run() external returns (IDO ido) {
        address samuraiTiers = 0xdB0Ee72eD5190e9ef7eEC288a92f73c5cf3B3c74;
        bool usingETH = false;
        bool usingLinkedWallet = true;
        IIDO.VestingType vestingType = IIDO.VestingType.LinearVesting;
        uint256 DECIMALS = usingETH ? 1e18 : 1e6;
        uint256 totalMax = 50_000 * DECIMALS;
        uint256 price = usingETH ? 0.15e18 : 0.15e6;

        IIDO.WalletRange[] memory ranges = new IIDO.WalletRange[](6);

        IIDO.WalletRange memory range1 = IIDO.WalletRange("Public", 100 * DECIMALS, 5_000 * DECIMALS);
        IIDO.WalletRange memory range2 = IIDO.WalletRange("Ronin", 100 * DECIMALS, 100 * DECIMALS);
        IIDO.WalletRange memory range3 = IIDO.WalletRange("Gokenin", 100 * DECIMALS, 200 * DECIMALS);
        IIDO.WalletRange memory range4 = IIDO.WalletRange("Goshi", 100 * DECIMALS, 400 * DECIMALS);
        IIDO.WalletRange memory range5 = IIDO.WalletRange("Hatamoto", 100 * DECIMALS, 800 * DECIMALS);
        IIDO.WalletRange memory range6 = IIDO.WalletRange("Shogun", 100 * DECIMALS, 1_500 * DECIMALS);

        ranges[0] = range1;
        ranges[1] = range2;
        ranges[2] = range3;
        ranges[3] = range4;
        ranges[4] = range5;
        ranges[5] = range6;

        IIDO.Amounts memory amounts = IIDO.Amounts({tokenPrice: price, maxAllocations: totalMax, tgeReleasePercent: 8});

        uint256 rightNow = block.timestamp;

        IIDO.Periods memory periods = IIDO.Periods({
            registrationAt: rightNow,
            participationStartsAt: rightNow + 1 days, // 24 hours
            participationEndsAt: rightNow + 2 days, // 48 hours
            vestingAt: rightNow + 10 days,
            cliff: 30 days,
            releaseSchedule: IIDO.ReleaseSchedule.None
        });

        vm.startBroadcast();
        ido = new IDO(samuraiTiers, usingETH, usingLinkedWallet, vestingType, amounts, periods, ranges);
        if (!usingETH) setTokens(ido);
        vm.stopBroadcast();

        return ido;
    }

    // Deploys the Samurai tiers for tests
    function runForTests(bool _usingETH, bool _usingLinkedWallet) external returns (IDO ido) {
        IIDO.VestingType vestingType = IIDO.VestingType.LinearVesting;
        uint256 DECIMALS = _usingETH ? 1e18 : 1e6;
        uint256 totalMax = 50_000 * DECIMALS;
        uint256 price = _usingETH ? 0.013e18 : 0.013e6;

        IIDO.WalletRange[] memory ranges = new IIDO.WalletRange[](6);

        IIDO.WalletRange memory range1 = IIDO.WalletRange("Public", 100 * DECIMALS, 5_000 * DECIMALS);
        IIDO.WalletRange memory range2 = IIDO.WalletRange("Ronin", 100 * DECIMALS, 100 * DECIMALS);
        IIDO.WalletRange memory range3 = IIDO.WalletRange("Gokenin", 100 * DECIMALS, 200 * DECIMALS);
        IIDO.WalletRange memory range4 = IIDO.WalletRange("Goshi", 100 * DECIMALS, 400 * DECIMALS);
        IIDO.WalletRange memory range5 = IIDO.WalletRange("Hatamoto", 100 * DECIMALS, 800 * DECIMALS);
        IIDO.WalletRange memory range6 = IIDO.WalletRange("Shogun", 100 * DECIMALS, 1_500 * DECIMALS);

        ranges[0] = range1;
        ranges[1] = range2;
        ranges[2] = range3;
        ranges[3] = range4;
        ranges[4] = range5;
        ranges[5] = range6;

        IIDO.Amounts memory amounts = IIDO.Amounts({tokenPrice: price, maxAllocations: totalMax, tgeReleasePercent: 8});

        uint256 rightNow = block.timestamp;

        IIDO.Periods memory periods = IIDO.Periods({
            registrationAt: rightNow,
            participationStartsAt: rightNow + 1 days, // 24 hours
            participationEndsAt: rightNow + 2 days, // 48 hours
            vestingAt: rightNow + 10 days,
            cliff: 30 days,
            releaseSchedule: IIDO.ReleaseSchedule.None
        });

        address _nft = 0x519eD34150300dC0D04d50a5Ff401177A92b4406;
        address _lock = 0xfb691697BDAf1857C748C004cC7dab3d234E062E;
        address _lpGauge = 0xf96Bc096dd1E52dcE4d595B6C4B8c5d2200db1E5;

        vm.startBroadcast();
        SamuraiTiers samuraiTiers = new SamuraiTiers(_nft, _lock, _lpGauge);
        addInitialTiers(samuraiTiers);

        ido = new IDO(address(samuraiTiers), _usingETH, _usingLinkedWallet, vestingType, amounts, periods, ranges);
        if (!_usingETH) setTokens(ido);
        vm.stopBroadcast();

        return ido;
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

    function setTokens(IDO ido) public {
        address[] memory acceptedTokens;
        if (block.chainid == 31337) {
            acceptedTokens = new address[](1);
            USDCMock usdcMock = new USDCMock("USDC Mock", "USDM");
            acceptedTokens[0] = address(usdcMock);
        } else {
            acceptedTokens = new address[](1);
            acceptedTokens[0] = vm.envAddress("BASE_USDC_ADDRESS");
        }

        ido.setTokens(acceptedTokens);
    }

    function testMock() public {}
}
