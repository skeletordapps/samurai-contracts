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
        uint256 privateKey = block.chainid == 8453 ? vm.envUint("PRIVATE_KEY") : vm.envUint("DEV_HOT_PRIVATE_KEY");
        // address idoToken = address(0x888F2E45d3c27d9CaE72AcA93174C530dFB3D4d8); // SKR TOKEN
        address idoToken = address(0xBF3A2340221B9Ead8Fe0B6a1b2990E6E00Dea092); // DYOR
        address points = address(0xDf0fDc572849f01CdaB35b80cA41Ce67051C8Dfe); // SPS TOKEN
        uint256 tgeReleasePercent = 0.3e18;
        uint256 pointsPerToken = 0.315e18;
        IVesting.VestingType vestingType = IVesting.VestingType.PeriodicVesting;
        IVesting.PeriodType vestingPeriodType = IVesting.PeriodType.Months;
        IVesting.Periods memory periods = IVesting.Periods({vestingDuration: 5, vestingAt: 1733238000, cliff: 1});
        (address[] memory wallets, uint256[] memory tokensPurchased) = loadWallets();

        vm.startBroadcast(privateKey);
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
        IVesting.Periods memory periods = IVesting.Periods({vestingDuration: 3, vestingAt: block.timestamp, cliff: 2});
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

    function runForNoCliffNoVesting() external returns (Vesting vesting) {
        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");
        ERC20Mock newToken = new ERC20Mock("IDO TOKEN 2", "IDT2");
        address idoToken = address(newToken);
        uint256 tgeReleasePercent = 0 ether;
        uint256 pointsPerToken = 0.315e18;
        IVesting.Periods memory periods =
            IVesting.Periods({vestingDuration: 0, vestingAt: block.timestamp + 1 hours, cliff: 0});
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
        tokensPurchased[0] = 500_000 ether;

        wallets[1] = vm.addr(2);
        tokensPurchased[1] = 500_000 ether;

        return (wallets, tokensPurchased);
    }

    function loadWallets() internal pure returns (address[] memory wallets, uint256[] memory tokensPurchased) {
        wallets = new address[](1);
        tokensPurchased = new uint256[](1);

        wallets[0] = address(0);
        tokensPurchased[0] = 10 ether;

        return (wallets, tokensPurchased);
    }

    function testMock() public {}
}
