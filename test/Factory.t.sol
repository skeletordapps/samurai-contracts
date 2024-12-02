// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IFactory} from "../src/interfaces/IFactory.sol";
import {IIDO} from "../src/interfaces/IIDO.sol";
import {ISamuraiTiers} from "../src/interfaces/ISamuraiTiers.sol";
import {Factory} from "../src/Factory.sol";
import {DeployFactory} from "../script/DeployFactory.s.sol";
import {SamuraiTiers} from "../src/SamuraiTiers.sol";
import {IDO} from "../src/IDO.sol";
import {USDCMock} from "../src/mocks/USDCMock.sol";

contract FactoryTest is Test {
    uint256 fork;
    string public RPC_URL;
    DeployFactory deployer;

    Factory factory;
    address owner;

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployFactory();

        factory = deployer.run();
        owner = factory.owner();
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

    function setUpInitialConfig(
        bool _usingETH,
        bool _usingLinkedWallet,
        uint256 _price,
        uint256 _totalMax,
        uint256 _tgePercentage,
        bool _refundable,
        uint256 _refundPercent,
        uint256 _refundPeriod,
        IIDO.VestingType _vestingType
    ) public returns (IFactory.InitialConfig memory) {
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
            IIDO.Amounts({tokenPrice: _price, maxAllocations: _totalMax, tgeReleasePercent: _tgePercentage});

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

        IIDO.Refund memory refund =
            IIDO.Refund({active: _refundable, feePercent: _refundPercent, period: _refundPeriod});

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

        IFactory.InitialConfig memory initialConfig = IFactory.InitialConfig({
            samuraiTiers: address(samuraiTiers),
            acceptedToken: _acceptedToken,
            usingETH: _usingETH,
            usingLinkedWallet: _usingLinkedWallet,
            vestingType: _vestingType,
            amounts: amounts,
            periods: periods,
            ranges: ranges,
            refund: refund
        });

        return initialConfig;
    }

    function testConstructor() public {
        assertEq(factory.totalIDOs(), 0);
    }

    function testRevertIdoCreation() external {
        IFactory.InitialConfig memory initialConfig;

        vm.startPrank(owner);
        vm.expectRevert();
        factory.createIDO(initialConfig);
        vm.stopPrank();
    }

    function testCanCreateNewIDO() external {
        IFactory.InitialConfig memory initialConfig = setUpInitialConfig(
            false, true, 10e6, 50_000e6, 0.1e18, true, 0.01e18, 24 hours, IIDO.VestingType.LinearVesting
        );

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IFactory.IDOCreated(block.chainid, initialConfig);
        IDO ido = factory.createIDO(initialConfig);
        vm.stopPrank();

        (uint256 tokenPrice, uint256 maxAllocations, uint256 tgeReleasePercent) = ido.amounts();
        uint256 numberOfRanges = ido.rangesLength();
        (
            uint256 registrationAt,
            uint256 participationStartsAt,
            uint256 participationEndsAt,
            uint256 vestingDuration,
            uint256 vestingAt,
            uint256 cliff
        ) = ido.periods();

        uint256 rightNow = block.timestamp;
        assertFalse(ido.usingETH());
        assertEq(ido.owner(), owner);
        assertEq(ido.acceptedToken(), vm.envAddress("BASE_USDC_ADDRESS"));
        assertFalse(ido.samuraiTiers() == address(0));
        assertTrue(maxAllocations > 0);
        assertTrue(ido.rangesLength() == 6);
        assertEq(tokenPrice, 10e6);
        assertEq(maxAllocations, 50_000e6);
        assertEq(tgeReleasePercent, 0.1e18);
        assertEq(registrationAt, rightNow);
        assertEq(participationStartsAt, rightNow + 1 days);
        assertEq(participationEndsAt, rightNow + 2 days);
        assertEq(vestingAt, 0);
        assertEq(vestingDuration, 0);
        assertEq(cliff, 0);
        assertEq(numberOfRanges, 6);

        (bool active, uint256 feePercent, uint256 period) = ido.refund();

        assertEq(active, true);
        assertEq(feePercent, 0.01e18);
        assertEq(period, 24 hours);

        assertEq(factory.totalIDOs(), 1);
        assertEq(factory.idos(0), address(ido));
    }
}
