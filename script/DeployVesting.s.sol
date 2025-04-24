// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {Vesting} from "../src/Vesting.sol";
import {IVesting} from "../src/interfaces/IVesting.sol";
import {console} from "forge-std/console.sol";
import {SamuraiTiers} from "../src/SamuraiTiers.sol";
import {ISamuraiTiers} from "../src/interfaces/ISamuraiTiers.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";
import {SamuraiPoints} from "../src/SamuraiPoints.sol";
import {IPoints} from "../src/interfaces/IPoints.sol";

contract DeployVesting is Script {
    function run() external returns (Vesting vesting) {
        console.log("CHAIN - ", block.chainid);
        address idoToken = address(0x2490880B1480Aba52241CE445355798e12ec9c99); // BERA SHIT
        address points = address(0x5f5f2D8C61a507AA6C47f30cc4f76B937C10a8e1); // SPS TOKEN
        uint256 tgeReleasePercent = 0.5e18; // 50% on TGE
        uint256 pointsPerToken = 5.2e18; // 5.2 per token
        IVesting.VestingType vestingType = IVesting.VestingType.PeriodicVesting;
        IVesting.PeriodType vestingPeriodType = IVesting.PeriodType.Months;
        IVesting.Periods memory periods = IVesting.Periods({vestingDuration: 1, vestingAt: 1741618800, cliff: 0});
        (address[] memory wallets, uint256[] memory tokensPurchased) = loadWallets();

        vm.startBroadcast();
        vesting = new Vesting(
            idoToken,
            points,
            tgeReleasePercent,
            pointsPerToken,
            vestingType,
            vestingPeriodType,
            periods,
            wallets,
            tokensPurchased
        );
        vm.stopBroadcast();

        return vesting;
    }

    function runForTests(IVesting.VestingType _vestingType) external returns (Vesting vesting) {
        IVesting.PeriodType vestingPeriodType = IVesting.PeriodType.None; // Assume is "Linear Vesting" or "Cliff Vesting" first

        if (_vestingType == IVesting.VestingType.PeriodicVesting) vestingPeriodType = IVesting.PeriodType.Months;

        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");
        ERC20Mock newToken = new ERC20Mock("IDO TOKEN 2", "IDT2");
        address idoToken = address(newToken);
        uint256 tgeReleasePercent = 0.15 ether;
        uint256 pointsPerToken = 0.315e18;
        IVesting.Periods memory periods =
            IVesting.Periods({vestingDuration: 3, vestingAt: block.timestamp + 1 days, cliff: 2});
        (address[] memory wallets, uint256[] memory tokensPurchased) = loadWalletsForTests();

        vm.startBroadcast(privateKey);
        SamuraiPoints sp = new SamuraiPoints();
        address points = address(sp);

        vesting = new Vesting(
            idoToken,
            points,
            tgeReleasePercent,
            pointsPerToken,
            _vestingType,
            vestingPeriodType,
            periods,
            wallets,
            tokensPurchased
        );

        sp.grantRole(IPoints.Roles.MINTER, address(vesting));
        loadWallets();
        vm.stopBroadcast();

        return vesting;
    }

    function runForPointsTests(IVesting.VestingType _vestingType) external returns (Vesting vesting) {
        IVesting.PeriodType vestingPeriodType = IVesting.PeriodType.None; // Assume is "Linear Vesting" or "Cliff Vesting" first

        if (_vestingType == IVesting.VestingType.PeriodicVesting) vestingPeriodType = IVesting.PeriodType.Months;

        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");
        ERC20Mock newToken = new ERC20Mock("IDO TOKEN 2", "IDT2");
        address idoToken = address(newToken);
        uint256 tgeReleasePercent = 0.15 ether;
        uint256 pointsPerToken = 0.315e18;
        IVesting.Periods memory periods =
            IVesting.Periods({vestingDuration: 3, vestingAt: block.timestamp + 1 days, cliff: 2});
        (address[] memory wallets, uint256[] memory tokensPurchased) = loadWalletsForPointsTests();

        vm.startBroadcast(privateKey);
        address points = address(0xDf0fDc572849f01CdaB35b80cA41Ce67051C8Dfe); // SPS TOKEN

        IPoints sp = IPoints(points);

        vesting = new Vesting(
            idoToken,
            points,
            tgeReleasePercent,
            pointsPerToken,
            _vestingType,
            vestingPeriodType,
            periods,
            wallets,
            tokensPurchased
        );

        sp.grantRole(IPoints.Roles.MINTER, address(vesting));
        loadWallets();
        vm.stopBroadcast();

        return vesting;
    }

    function runForPeriodicTests(IVesting.PeriodType _vestingPeriodType, uint256 _vestingDuration)
        external
        returns (Vesting vesting)
    {
        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");
        ERC20Mock newToken = new ERC20Mock("IDO TOKEN 2", "IDT2");
        address idoToken = address(newToken);
        uint256 tgeReleasePercent = 0.15 ether;
        uint256 pointsPerToken = 0.315e18;
        IVesting.Periods memory periods =
            IVesting.Periods({vestingDuration: _vestingDuration, vestingAt: block.timestamp + 1 days, cliff: 2});
        (address[] memory wallets, uint256[] memory tokensPurchased) = loadWalletsForTests();

        vm.startBroadcast(privateKey);
        SamuraiPoints sp = new SamuraiPoints();
        address points = address(sp);

        vesting = new Vesting(
            idoToken,
            points,
            tgeReleasePercent,
            pointsPerToken,
            IVesting.VestingType.PeriodicVesting,
            _vestingPeriodType,
            periods,
            wallets,
            tokensPurchased
        );

        sp.grantRole(IPoints.Roles.MINTER, address(vesting));
        loadWallets();
        vm.stopBroadcast();

        return vesting;
    }

    function runForNoCliffNoVesting() external returns (Vesting vesting) {
        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");
        ERC20Mock newToken = new ERC20Mock("IDO TOKEN 2", "IDT2");
        address idoToken = address(newToken);
        uint256 tgeReleasePercent = 0 ether;
        uint256 pointsPerToken = 0.315e18;
        IVesting.Periods memory periods =
            IVesting.Periods({vestingDuration: 0, vestingAt: block.timestamp + 1 days, cliff: 0});
        (address[] memory wallets, uint256[] memory tokensPurchased) = loadWalletsForTests();

        vm.startBroadcast(privateKey);
        SamuraiPoints sp = new SamuraiPoints();
        address points = address(sp);

        vesting = new Vesting(
            idoToken,
            points,
            tgeReleasePercent,
            pointsPerToken,
            IVesting.VestingType.CliffVesting,
            IVesting.PeriodType.None,
            periods,
            wallets,
            tokensPurchased
        );

        sp.grantRole(IPoints.Roles.MINTER, address(vesting));
        loadWallets();
        vm.stopBroadcast();

        return vesting;
    }

    function loadWalletsForTests() internal pure returns (address[] memory wallets, uint256[] memory tokensPurchased) {
        wallets = new address[](2);
        tokensPurchased = new uint256[](2);

        wallets[0] = vm.addr(1);
        tokensPurchased[0] += 500_000 ether;

        wallets[1] = vm.addr(2);
        tokensPurchased[1] += 500_000 ether;

        return (wallets, tokensPurchased);
    }

    function loadWalletsForPointsTests()
        internal
        pure
        returns (address[] memory wallets, uint256[] memory tokensPurchased)
    {
        wallets = new address[](2);
        tokensPurchased = new uint256[](2);

        wallets[0] = 0xcaE8cF1e2119484D6CC3B6EFAad2242aDBDB1Ea8;
        tokensPurchased[0] += 500_000 ether;

        wallets[1] = vm.addr(2);
        tokensPurchased[1] += 500_000 ether;

        return (wallets, tokensPurchased);
    }

    function loadWallets() internal pure returns (address[] memory wallets, uint256[] memory tokensPurchased) {
        wallets = new address[](3);
        tokensPurchased = new uint256[](3);
        wallets[0] = address(0x4C757cd2b603c6fc01DD8dFa7c9d7888e3C05AcD);
        tokensPurchased[0] = 3846.153846 ether + 16153.84615 ether;

        wallets[1] = address(0xcDe00Be56479F95b5e33De136AD820FfaE996009);
        tokensPurchased[1] = 3846.153846 ether;

        wallets[2] = address(0x38b7EF909DD8E85be3e63a917B9ac4C208FC59e5);
        tokensPurchased[2] = 1538.461538 ether;

        return (wallets, tokensPurchased);
    }

    function testMock() public {}
}
