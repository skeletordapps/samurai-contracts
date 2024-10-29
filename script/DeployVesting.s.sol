// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

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
        address idoToken = address(0x0);
        address points = address(0x0);
        uint256 totalPurchased = 1_000_000 ether;
        uint256 tgeReleasePercent = 0.15e18;
        uint256 pointsPerToken = 100 ether;
        IVesting.VestingType vestingType = IVesting.VestingType.LinearVesting;
        IVesting.Periods memory periods = IVesting.Periods({vestingDuration: 0, vestingAt: 0, cliff: 0});
        (address[] memory wallets, uint256[] memory tokensPurchased) = loadWallets();

        vm.startBroadcast();
        vesting = new Vesting(
            idoToken,
            points,
            totalPurchased,
            tgeReleasePercent,
            pointsPerToken,
            vestingType,
            periods,
            wallets,
            tokensPurchased
        );
        vm.stopBroadcast();

        return vesting;
    }

    function runForTests(IVesting.VestingType _vestingType) external returns (Vesting vesting) {
        ERC20Mock newToken = new ERC20Mock("IDO TOKEN 2", "IDT2");
        address idoToken = address(newToken);
        SamuraiPoints sp = new SamuraiPoints();
        address points = address(sp);
        uint256 totalPurchased = 1_000_000 ether;
        uint256 tgeReleasePercent = 0.15 ether;
        uint256 pointsPerToken = 100 ether;
        IVesting.Periods memory periods = IVesting.Periods({vestingDuration: 3, vestingAt: block.timestamp, cliff: 2});
        (address[] memory wallets, uint256[] memory tokensPurchased) = loadWallets();

        // address _token,
        // address _points,
        // uint256 _totalPurchased,
        // uint256 _tgeReleasePercent,
        // uint256 _pointsPerToken,
        // IVesting.VestingType _vestingType,
        // IVesting.Periods memory _periods,
        // address[] memory _wallets,
        // uint256[] memory _tokensPurchased

        vm.startBroadcast();
        vesting = new Vesting(
            idoToken,
            points,
            totalPurchased,
            tgeReleasePercent,
            pointsPerToken,
            _vestingType,
            periods,
            wallets,
            tokensPurchased
        );

        // sp.grantRole(IPoints.Roles.MINTER, address(vesting));
        loadWallets();
        vm.stopBroadcast();

        return vesting;
    }

    function runForFuzzTests(
        IVesting.VestingType _vestingType,
        uint256 _totalPurchased,
        uint256 _tgeReleasePercent,
        IVesting.Periods memory _periods
    ) external returns (Vesting vesting) {
        ERC20Mock newToken = new ERC20Mock("IDO TOKEN 2", "IDT2");
        SamuraiPoints sp = new SamuraiPoints();
        address points = address(sp);
        address idoToken = address(newToken);
        uint256 totalPurchased = _totalPurchased;
        uint256 tgeReleasePercent = _tgeReleasePercent;
        uint256 pointsPerToken = 100 ether;
        IVesting.Periods memory periods = _periods;
        (address[] memory wallets, uint256[] memory tokensPurchased) = loadWallets();

        vm.startBroadcast();
        vesting = new Vesting(
            idoToken,
            points,
            totalPurchased,
            tgeReleasePercent,
            pointsPerToken,
            _vestingType,
            periods,
            wallets,
            tokensPurchased
        );

        sp.grantRole(IPoints.Roles.MINTER, address(vesting));
        loadWallets();
        vm.stopBroadcast();

        return vesting;
    }

    function loadWallets() internal pure returns (address[] memory wallets, uint256[] memory tokensPurchased) {
        wallets = new address[](2);
        tokensPurchased = new uint256[](2);

        wallets[0] = vm.addr(1);
        tokensPurchased[0] = 500_000 ether;

        wallets[1] = vm.addr(2);
        tokensPurchased[1] = 500_000 ether;

        return (wallets, tokensPurchased);
    }

    function testMock() public {}
}
