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
        address idoToken = address(0x5032FD03f2645Cd78309ff775318a5Aee8216BE2); // GRIZZY
        address points = address(0x5f5f2D8C61a507AA6C47f30cc4f76B937C10a8e1); // SPS TOKEN
        uint256 tgeReleasePercent = 0.5e18; // 50% on TGE
        uint256 pointsPerToken = 5.2e18; // 5.2 per token
        IVesting.VestingType vestingType = IVesting.VestingType.PeriodicVesting;
        IVesting.PeriodType vestingPeriodType = IVesting.PeriodType.Months;
        IVesting.Periods memory periods = IVesting.Periods({vestingDuration: 1, vestingAt: 1741273200, cliff: 0});
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
        wallets = new address[](42);
        tokensPurchased = new uint256[](42);
        wallets[0] = address(0x25C86f8557D720e6664213BD15f256DbB5C4F53c);
        tokensPurchased[0] = 3846.153846 ether + 16153.84615 ether;

        wallets[1] = address(0x2B92423fDB70c166c7fad664493Cda07337e40Fd);
        tokensPurchased[1] = 3846.153846 ether;

        wallets[2] = address(0xB4c0d2eC8aA2b716f02d5338C0EC777313e4f709);
        tokensPurchased[2] = 1538.461538 ether;

        wallets[3] = address(0xbfad818EdB25DC4eebac8Cc44a7533bE4652AD6C);
        tokensPurchased[3] = 3846.153846 ether;

        wallets[4] = address(0x5AD17A1A013E6dc9356fa5E047e70d1B5D490BbA);
        tokensPurchased[4] = 3846.153846 ether;

        wallets[5] = address(0xb020F0FeD0878ea7489f2456b482557723C6D62B);
        tokensPurchased[5] = 3846.153846 ether + 3849.395054 ether + 1196.769231 ether;

        wallets[6] = address(0x3d1E7D80e7357BBd450Ef1E722b4d87674bab2B0);
        tokensPurchased[6] = 3846.153846 ether;

        wallets[7] = address(0xF3b375a2bcebDef5878E52B29eb2fEDC564f1d21);
        tokensPurchased[7] = 2318.003931 ether;

        wallets[8] = address(0x431b5DDB0AcE97eBC3d936403ea25831BaD832B6);
        tokensPurchased[8] = 2538.461538 ether;

        wallets[9] = address(0x48Fd43531F21C5fE515A64E90ad5142c6084C083);
        tokensPurchased[9] = 1538.461538 ether;

        wallets[10] = address(0xcab2AaDD8b875F74d5b04f1453D9a9cAd2F395CD);
        tokensPurchased[10] = 3207.144246 ether;

        wallets[11] = address(0x16b6B56dCE7fcB581b4D2B0e711Aeb0084169200);
        tokensPurchased[11] = 3846.153846 ether;

        wallets[12] = address(0x1273162B4fE3424Bf03d74c88181714Bbd263393);
        tokensPurchased[12] = 3846.153846 ether;

        wallets[13] = address(0x43E3946b8AD45251232aFa860de45f1044cbA516);
        tokensPurchased[13] = 2307.692308 ether;

        wallets[14] = address(0x6625C700f800ce4764eDF91C2C7E6Bc0feAe4ab2);
        tokensPurchased[14] = 3846.153846 ether;

        wallets[15] = address(0x446924C2C25CA1Bcd5b5eDB49abad9353F82ee61);
        tokensPurchased[15] = 3846.153846 ether;

        wallets[16] = address(0x23777a214Af90185FA59fE692DafF609dd02Ab90);
        tokensPurchased[16] = 3846.153846 ether;

        wallets[17] = address(0x81409E4C1a55C034EC86F64A75d18D911A8B0071);
        tokensPurchased[17] = 3846.153846 ether;

        wallets[18] = address(0x9d79F12e677822C2d3F9745e422Cb1CdBc5A41AA);
        tokensPurchased[18] = 769.2307692 ether;

        wallets[19] = address(0xFeC646017105fA2A4FFDc773e9c539Eda5af724a);
        tokensPurchased[19] = 3846.153846 ether;

        wallets[20] = address(0xeD32E12d57e96b14DCAA0627F856965d08652E99);
        tokensPurchased[20] = 3846.153846 ether + 15055.47346 ether;

        wallets[21] = address(0x0aEBE72642362A644954f5Ea7876Fb71c09C135f);
        tokensPurchased[21] = 3839.489292 ether;

        wallets[22] = address(0xfc0cA4f2534603123a557140a24695D906C18FAA);
        tokensPurchased[22] = 3846.153846 ether + 1776.923077 ether + 800 ether;

        wallets[23] = address(0xa6473CcE13F11614745e6Bf9caD704646616A9b8);
        tokensPurchased[23] = 1746.153846 ether;

        wallets[24] = address(0x964F14D320519B4Ec81a3037E79F56fcaC732353);
        tokensPurchased[24] = 3846.153846 ether;

        wallets[25] = address(0x0D358949F53f5CF5989f1c72892169eDE93ebDd3);
        tokensPurchased[25] = 3846.153846 ether;

        wallets[26] = address(0xcEd29BA48490C51E4348e654C313AC97762beCCC);
        tokensPurchased[26] = 1538.461538 ether;

        wallets[27] = address(0x62C5d2ec2722BE908c9aDA4C783D1116a240F2dA);
        tokensPurchased[27] = 1538.461538 ether;

        wallets[28] = address(0x25ebE14A2fBC820562a3fF92C75007493fbB8448);
        tokensPurchased[28] = 3076.923077 ether;

        wallets[29] = address(0x170D2eA8f593FCAbDB353DBf92fC9E4a417D688C);
        tokensPurchased[29] = 3846.153846 ether;

        wallets[30] = address(0x833A49e676bfCd4a4Ea766C63DB46243d90527C4);
        tokensPurchased[30] = 1153.846154 ether;

        wallets[31] = address(0x8D1DD5e79b4fFD792D632EEfa3eb5c1d10266907);
        tokensPurchased[31] = 1538.461538 ether;

        wallets[32] = address(0xc505B6FCB0E4693A1dB21E861d8341FcC346175C);
        tokensPurchased[32] = 2261.538462 ether;

        wallets[33] = address(0x5bb35d290ecc0f00A8C84b03E66D974b01D64AfB);
        tokensPurchased[33] = 3846.153846 ether + 7686.846154 ether;

        wallets[34] = address(0x614550C16857b11a66548d65aA45805659814c93);
        tokensPurchased[34] = 2302.542069 ether;

        wallets[35] = address(0xe81A37c7b4537F854a4f974A715802218309Dd8C);
        tokensPurchased[35] = 769.2307692 ether;

        wallets[36] = address(0x5363C32D81266cbE7e00E867a11462C3bfc771C9);
        tokensPurchased[36] = 1538.461538 ether;

        wallets[37] = address(0x71EC5ABFc49075e158b0F85575D400D0f5D7d3BE);
        tokensPurchased[37] = 3846.153846 ether;

        wallets[38] = address(0x93E467D56bb04fC64A978d584E12dA1eA4Dc4cE0);
        tokensPurchased[38] = 3269.230769 ether;

        wallets[39] = address(0x26Ba0Ebf96B92891A4504b64136335399A75A10B);
        tokensPurchased[39] = 923.0769231 ether;

        wallets[40] = address(0xcaE8cF1e2119484D6CC3B6EFAad2242aDBDB1Ea8);
        tokensPurchased[40] = 19230.76923 ether;

        wallets[41] = address(0xB4a40C9C4940d3F9703D571319406f38e957924A);
        tokensPurchased[41] = 9915.384615 ether;

        return (wallets, tokensPurchased);
    }

    function testMock() public {}
}
