// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {IDO} from "../src/IDO.sol";
import {IIDO} from "../src/interfaces/IIDO.sol";
import {USDCMock} from "../src/mocks/USDCMock.sol";
import {console} from "forge-std/console.sol";
import {SamuraiTiers} from "../src/SamuraiTiers.sol";
import {ISamuraiTiers} from "../src/interfaces/ISamuraiTiers.sol";

contract DeployIDO is Script {
    function run() external returns (IDO ido) {
        // address samuraiTiers = 0xdB0Ee72eD5190e9ef7eEC288a92f73c5cf3B3c74; // wrong
        address samuraiTiers = 0x2Bb8Fc0196becd84bac853E32c9c252343699186; // new
        // address acceptedToken = vm.envAddress("BASE_USDC_ADDRESS"); // use address(0) if using ether
        address acceptedToken = vm.envAddress("BASE_FUSDC_ADDRESS");
        bool usingETH = false;
        bool usingLinkedWallet = false;
        IIDO.VestingType vestingType = IIDO.VestingType.LinearVesting;
        uint256 totalMax = usingETH ? 100_000 ether : 100_000e6;
        uint256 price = usingETH ? 0.15 ether : 0.008e6;
        bool refundable = true;
        uint256 refundPercent = 0.01e18;
        uint256 refundPeriod = 24 hours;

        IIDO.WalletRange[] memory ranges = new IIDO.WalletRange[](6);

        if (usingETH) {
            ranges[0] = IIDO.WalletRange("Public", 0.1 ether, 5 ether);
            ranges[1] = IIDO.WalletRange("Ronin", 0.1 ether, 0.1 ether);
            ranges[2] = IIDO.WalletRange("Gokenin", 0.1 ether, 0.5 ether);
            ranges[3] = IIDO.WalletRange("Goshi", 0.1 ether, 0.7 ether);
            ranges[4] = IIDO.WalletRange("Hatamoto", 0.1 ether, 1.4 ether);
            ranges[5] = IIDO.WalletRange("Shogun", 0.1 ether, 2 ether);
        } else {
            ranges[0] = IIDO.WalletRange("Public", 100e6, 5_000e6);
            ranges[1] = IIDO.WalletRange("Ronin", 100e6, 100e6);
            ranges[2] = IIDO.WalletRange("Gokenin", 100e6, 200e6);
            ranges[3] = IIDO.WalletRange("Goshi", 100e6, 400e6);
            ranges[4] = IIDO.WalletRange("Hatamoto", 100e6, 800e6);
            ranges[5] = IIDO.WalletRange("Shogun", 100e6, 1_500e6);
        }

        IIDO.Amounts memory amounts =
            IIDO.Amounts({tokenPrice: price, maxAllocations: totalMax, tgeReleasePercent: 0.15e18});

        uint256 rightNow = block.timestamp;

        IIDO.Periods memory periods = IIDO.Periods({
            registrationAt: rightNow,
            participationStartsAt: rightNow + 1 days, // 24 hours
            participationEndsAt: rightNow + 2 days, // 48 hours
            vestingDuration: 0,
            vestingAt: 0,
            cliff: 0
        });

        IIDO.Refund memory refund = IIDO.Refund({active: refundable, feePercent: refundPercent, period: refundPeriod});

        vm.startBroadcast();
        ido = new IDO(
            samuraiTiers, acceptedToken, usingETH, usingLinkedWallet, vestingType, amounts, periods, ranges, refund
        );

        vm.stopBroadcast();

        return ido;
    }

    // Deploys the Samurai tiers for tests
    function runForTests(bool _usingETH, bool _usingLinkedWallet) external returns (IDO ido) {
        IIDO.VestingType vestingType = IIDO.VestingType.LinearVesting;
        uint256 totalMax = _usingETH ? 50_000 ether : 50_000e6;
        uint256 price = _usingETH ? 0.013 ether : 0.013e6;
        bool refundable = true;
        uint256 refundPercent = 0.01e18;
        uint256 refundPeriod = 24 hours;

        IIDO.WalletRange[] memory ranges = new IIDO.WalletRange[](6);

        if (_usingETH) {
            ranges[0] = IIDO.WalletRange("Public", 0.1 ether, 5 ether);
            ranges[1] = IIDO.WalletRange("Ronin", 0.1 ether, 0.1 ether);
            ranges[2] = IIDO.WalletRange("Gokenin", 0.1 ether, 0.5 ether);
            ranges[3] = IIDO.WalletRange("Goshi", 0.1 ether, 0.7 ether);
            ranges[4] = IIDO.WalletRange("Hatamoto", 0.1 ether, 1.4 ether);
            ranges[5] = IIDO.WalletRange("Shogun", 0.1 ether, 2 ether);
        } else {
            ranges[0] = IIDO.WalletRange("Public", 100e6, 5_000e6);
            ranges[1] = IIDO.WalletRange("Ronin", 100e6, 100e6);
            ranges[2] = IIDO.WalletRange("Gokenin", 100e6, 200e6);
            ranges[3] = IIDO.WalletRange("Goshi", 100e6, 400e6);
            ranges[4] = IIDO.WalletRange("Hatamoto", 100e6, 800e6);
            ranges[5] = IIDO.WalletRange("Shogun", 100e6, 1_500e6);
        }

        IIDO.Amounts memory amounts =
            IIDO.Amounts({tokenPrice: price, maxAllocations: totalMax, tgeReleasePercent: 0.08e18});

        uint256 rightNow = block.timestamp;

        IIDO.Periods memory periods = IIDO.Periods({
            registrationAt: rightNow,
            participationStartsAt: rightNow + 1 days, // 24 hours
            participationEndsAt: rightNow + 2 days, // 48 hours
            vestingDuration: 0,
            vestingAt: 0,
            cliff: 0
        });

        address _nft = 0x519eD34150300dC0D04d50a5Ff401177A92b4406;
        address _lock = 0xfb691697BDAf1857C748C004cC7dab3d234E062E;
        address _lpGauge = 0xf96Bc096dd1E52dcE4d595B6C4B8c5d2200db1E5;

        IIDO.Refund memory refund = IIDO.Refund({active: refundable, feePercent: refundPercent, period: refundPeriod});

        vm.startBroadcast();
        SamuraiTiers samuraiTiers = new SamuraiTiers(_nft, _lock, _lpGauge);
        addInitialTiers(samuraiTiers);

        address _acceptedToken;
        if (_usingETH) {
            _acceptedToken = address(0);
        } else if (block.chainid == 31337) {
            USDCMock usdcMock = new USDCMock("USDC Mock", "USDM");
            _acceptedToken = address(usdcMock);
        } else {
            _acceptedToken = vm.envAddress("BASE_USDC_ADDRESS");
        }

        ido = new IDO(
            address(samuraiTiers),
            _acceptedToken,
            _usingETH,
            _usingLinkedWallet,
            vestingType,
            amounts,
            periods,
            ranges,
            refund
        );
        vm.stopBroadcast();

        return ido;
    }

    function runForTestsWithOptions(
        bool _usingETH,
        bool _usingLinkedWallet,
        uint256 _price,
        uint256 _totalMax,
        uint256 _tgePercentage,
        bool _refundable,
        uint256 _refundPercent,
        uint256 _refundPeriod,
        IIDO.VestingType _vestingType
    ) external returns (IDO ido) {
        IIDO.VestingType vestingType = _vestingType;
        uint256 price = _price;
        uint256 totalMax = _totalMax;
        bool refundable = _refundable;
        uint256 refundPercent = _refundPercent;
        uint256 refundPeriod = _refundPeriod;

        IIDO.WalletRange[] memory ranges = new IIDO.WalletRange[](6);

        if (_usingETH) {
            ranges[0] = IIDO.WalletRange("Public", 0.1 ether, 5 ether);
            ranges[1] = IIDO.WalletRange("Ronin", 0.1 ether, 0.1 ether);
            ranges[2] = IIDO.WalletRange("Gokenin", 0.1 ether, 0.5 ether);
            ranges[3] = IIDO.WalletRange("Goshi", 0.1 ether, 0.7 ether);
            ranges[4] = IIDO.WalletRange("Hatamoto", 0.1 ether, 1.4 ether);
            ranges[5] = IIDO.WalletRange("Shogun", 0.1 ether, 2 ether);
        } else {
            ranges[0] = IIDO.WalletRange("Public", 100e6, 5_000e6);
            ranges[1] = IIDO.WalletRange("Ronin", 100e6, 100e6);
            ranges[2] = IIDO.WalletRange("Gokenin", 100e6, 200e6);
            ranges[3] = IIDO.WalletRange("Goshi", 100e6, 400e6);
            ranges[4] = IIDO.WalletRange("Hatamoto", 100e6, 800e6);
            ranges[5] = IIDO.WalletRange("Shogun", 100e6, 1_500e6);
        }

        IIDO.Amounts memory amounts =
            IIDO.Amounts({tokenPrice: price, maxAllocations: totalMax, tgeReleasePercent: _tgePercentage});

        uint256 rightNow = block.timestamp;

        IIDO.Periods memory periods = IIDO.Periods({
            registrationAt: rightNow,
            participationStartsAt: rightNow + 1 days, // 24 hours
            participationEndsAt: rightNow + 2 days, // 48 hours
            vestingDuration: 0,
            vestingAt: 0,
            cliff: 0
        });

        address _nft = 0x519eD34150300dC0D04d50a5Ff401177A92b4406;
        address _lock = 0xfb691697BDAf1857C748C004cC7dab3d234E062E;
        address _lpGauge = 0xf96Bc096dd1E52dcE4d595B6C4B8c5d2200db1E5;

        IIDO.Refund memory refund = IIDO.Refund({active: refundable, feePercent: refundPercent, period: refundPeriod});

        vm.startBroadcast();
        SamuraiTiers samuraiTiers = new SamuraiTiers(_nft, _lock, _lpGauge);
        addInitialTiers(samuraiTiers);

        address _acceptedToken;
        if (_usingETH) {
            _acceptedToken = address(0);
        } else if (block.chainid == 31337) {
            USDCMock usdcMock = new USDCMock("USDC Mock", "USDM");
            _acceptedToken = address(usdcMock);
        } else {
            _acceptedToken = vm.envAddress("BASE_USDC_ADDRESS");
        }

        ido = new IDO(
            address(samuraiTiers),
            _acceptedToken,
            _usingETH,
            _usingLinkedWallet,
            vestingType,
            amounts,
            periods,
            ranges,
            refund
        );
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

    function testMock() public {}
}
