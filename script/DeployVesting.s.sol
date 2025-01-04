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
        address idoToken = address(0x3e62fED35c97145e6B445704B8CE74B2544776A9); // EARNM
        address points = address(0xDf0fDc572849f01CdaB35b80cA41Ce67051C8Dfe); // SPS TOKEN
        uint256 tgeReleasePercent = 0.15e18; // 15% on TGE
        uint256 pointsPerToken = 0.3e18;
        IVesting.VestingType vestingType = IVesting.VestingType.PeriodicVesting;
        IVesting.PeriodType vestingPeriodType = IVesting.PeriodType.Days;
        IVesting.Periods memory periods = IVesting.Periods({vestingDuration: 7, vestingAt: 1734618600, cliff: 2});
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
        wallets = new address[](117);
        tokensPurchased = new uint256[](117);
        wallets[0] = address(0x6F0093Ac51CF3ba423Ae0db1298Bc0131f0bAB76);
        tokensPurchased[0] = 92533.6275 ether;
        wallets[1] = address(0xcaE8cF1e2119484D6CC3B6EFAad2242aDBDB1Ea8);
        tokensPurchased[1] = 140763 ether;
        wallets[2] = address(0x526f78b26436A1A627C9e82880eD9b7afb470B5D);
        tokensPurchased[2] = 43500 ether;
        wallets[3] = address(0x42D14dAc314f7bd4948C92b2f03a36BEfE0Ce14F);
        tokensPurchased[3] = 73500 ether;
        wallets[4] = address(0xCBD25a2F3f443640f4906AAf4E3c45fcEAacBaFc);
        tokensPurchased[4] = 73500 ether;
        wallets[5] = address(0x496Fc41e88e8B40812c426691eE23FAA1B3cb910);
        tokensPurchased[5] = 88000 ether;
        wallets[6] = address(0xc505B6FCB0E4693A1dB21E861d8341FcC346175C);
        tokensPurchased[6] = 29632.7084 ether;
        wallets[7] = address(0x0DA56e6EC31366774Ad2D081b1539b7e7353A3DA);
        tokensPurchased[7] = 44324.346300000005 ether;
        wallets[8] = address(0x3669Dce51dD32165A5749419049457944f48bb35);
        tokensPurchased[8] = 14500 ether;
        wallets[9] = address(0xabadf6B6a0f176D9D67879B6F744B0301f4B5007);
        tokensPurchased[9] = 73500 ether;
        wallets[10] = address(0xE52e043D5476bD4be1881a07aeDE7eDBE06B5f24);
        tokensPurchased[10] = 14500 ether;
        wallets[11] = address(0xFe70E1BE7a3D5263F8521019f339133a8448FfE8);
        tokensPurchased[11] = 73500 ether;
        wallets[12] = address(0x53d55D5410Fa37053c7e6882aF9c693d778db7Ce);
        tokensPurchased[12] = 73500 ether;
        wallets[13] = address(0xeF4da186884C213Be62b136F30F81c498018A1F8);
        tokensPurchased[13] = 73500 ether;
        wallets[14] = address(0xc8Be6527e44B0db0EB967D21d06C67b85229E606);
        tokensPurchased[14] = 73500 ether;
        wallets[15] = address(0x43E3946b8AD45251232aFa860de45f1044cbA516);
        tokensPurchased[15] = 50000 ether;
        wallets[16] = address(0xb3E72703F98A30b22a15bE2cC439cC2E1f9B64Be);
        tokensPurchased[16] = 102500 ether;
        wallets[17] = address(0x5d9F3079CB204aBA84AB34FdA277f37A6ef42EFd);
        tokensPurchased[17] = 73500 ether;
        wallets[18] = address(0x6FD8b5C58ACf7F98dD84C047CB099dA1fcc75613);
        tokensPurchased[18] = 73500 ether;
        wallets[19] = address(0x62C5d2ec2722BE908c9aDA4C783D1116a240F2dA);
        tokensPurchased[19] = 44500 ether;
        wallets[20] = address(0x2B92423fDB70c166c7fad664493Cda07337e40Fd);
        tokensPurchased[20] = 73500 ether;
        wallets[21] = address(0x3d1E7D80e7357BBd450Ef1E722b4d87674bab2B0);
        tokensPurchased[21] = 73500 ether;
        wallets[22] = address(0x431b5DDB0AcE97eBC3d936403ea25831BaD832B6);
        tokensPurchased[22] = 73500 ether;
        wallets[23] = address(0x34831fc3c805459FF099924A5E8Dcb036ee8e4d5);
        tokensPurchased[23] = 73500 ether;
        wallets[24] = address(0x95263BAc044453E7d63347a399f8Cdea99f0d531);
        tokensPurchased[24] = 14500 ether;
        wallets[25] = address(0xC3D4FEd7ad9976fb210a85Ffeb122E2141050133);
        tokensPurchased[25] = 73300 ether;
        wallets[26] = address(0xF3b375a2bcebDef5878E52B29eb2fEDC564f1d21);
        tokensPurchased[26] = 29000 ether;
        wallets[27] = address(0xE9131F2A8952c91dDDa2bA63E5aEEd98568EC5Af);
        tokensPurchased[27] = 37500 ether;
        wallets[28] = address(0xe81A37c7b4537F854a4f974A715802218309Dd8C);
        tokensPurchased[28] = 14500 ether;
        wallets[29] = address(0x6Df137e629792DF6A1D728cB9069389Ef2f63587);
        tokensPurchased[29] = 14500 ether;
        wallets[30] = address(0x223312fc85C6C5a9e46B26b5eA857c4ef0071E9D);
        tokensPurchased[30] = 20000 ether;
        wallets[31] = address(0xe74B3696c6d93716ce01472125Be3b9C74aA378B);
        tokensPurchased[31] = 73500 ether;
        wallets[32] = address(0x148AFbce5CE5417e966E92D2c04Bd81D8cB0e04e);
        tokensPurchased[32] = 320000 ether;
        wallets[33] = address(0xf5477598DFfFb6EC1f9057C6141d2D84630e30bF);
        tokensPurchased[33] = 43500 ether;
        wallets[34] = address(0xF17546f6274Cc52b669285C6fA14E1AEeB296e02);
        tokensPurchased[34] = 43500 ether;
        wallets[35] = address(0x15220634c3F1b994576CB7DCB8684938Ace8F2d4);
        tokensPurchased[35] = 43500 ether;
        wallets[36] = address(0xce538B15E77358ade315d2191B042cEb75f0469B);
        tokensPurchased[36] = 43500 ether;
        wallets[37] = address(0xaFE163f57960b946597c9b36B39718C6dD989EE4);
        tokensPurchased[37] = 43500 ether;
        wallets[38] = address(0x290cd04a35a80481A0F78AcA91466128dDbC088F);
        tokensPurchased[38] = 43500 ether;
        wallets[39] = address(0xbfad818EdB25DC4eebac8Cc44a7533bE4652AD6C);
        tokensPurchased[39] = 29000 ether;
        wallets[40] = address(0xcab2AaDD8b875F74d5b04f1453D9a9cAd2F395CD);
        tokensPurchased[40] = 25073.2827 ether;
        wallets[41] = address(0x5AD17A1A013E6dc9356fa5E047e70d1B5D490BbA);
        tokensPurchased[41] = 29000 ether;
        wallets[42] = address(0xb020F0FeD0878ea7489f2456b482557723C6D62B);
        tokensPurchased[42] = 59000 ether;
        wallets[43] = address(0xa5f22DAdBe1BfbCf9bb4001f419387Ad1086d631);
        tokensPurchased[43] = 30000 ether;
        wallets[44] = address(0x0A32A9237aa5165377717082408907aca255A575);
        tokensPurchased[44] = 8000 ether;
        wallets[45] = address(0x99559Af00d2F43cE773b84316CCE6f47C908f076);
        tokensPurchased[45] = 28011.4124 ether;
        wallets[46] = address(0xfc0cA4f2534603123a557140a24695D906C18FAA);
        tokensPurchased[46] = 30000 ether;
        wallets[47] = address(0x389b8Bd4FAc72ff9Aa5fD888a4B3283Ac4c14b28);
        tokensPurchased[47] = 200000 ether;
        wallets[48] = address(0x5e5a47069dD0C8C78428Be27E180acbA37e8e622);
        tokensPurchased[48] = 40000 ether;
        wallets[49] = address(0x5374883897Cb3d7a2129413710708318a0b39A9D);
        tokensPurchased[49] = 30000 ether;
        wallets[50] = address(0x16b04DD860cB316E861051C4d7e8740183C969e9);
        tokensPurchased[50] = 80000 ether;
        wallets[51] = address(0x75276752F2332aFfE6351FA8c79F3c9f1153eb87);
        tokensPurchased[51] = 30000 ether;
        wallets[52] = address(0xF948B28207874E5C7EA18fdAde91a11F276ab75a);
        tokensPurchased[52] = 30000 ether;
        wallets[53] = address(0x857bb773e87b12977a392Fd32d24B3A83e3cB7e2);
        tokensPurchased[53] = 30000 ether;
        wallets[54] = address(0x0752Adfe7C42D89Bf2Fb3c22fFa18B7d0871C807);
        tokensPurchased[54] = 20000 ether;
        wallets[55] = address(0x843cD8C36328cF18f9C1F1e11f0aCF88d99762aC);
        tokensPurchased[55] = 30000 ether;
        wallets[56] = address(0x64DEeCB9f372aCf9C388Ca9f045Cf211A202F329);
        tokensPurchased[56] = 30000 ether;
        wallets[57] = address(0x916Ab8f0f48096E7C5C6aB2F0537f98376F73131);
        tokensPurchased[57] = 30000 ether;
        wallets[58] = address(0xc6e03734191B1ec7129427Be86eE6D6034d128Ac);
        tokensPurchased[58] = 30000 ether;
        wallets[59] = address(0xeDD011efCE6f8c8b92493cF84AbC445b8e0992DC);
        tokensPurchased[59] = 30000 ether;
        wallets[60] = address(0x0B5d2F7D8B1CDB0974E3AA056F94Ca98F139f369);
        tokensPurchased[60] = 200000 ether;
        wallets[61] = address(0xC2E6a15f8b1016942e8Af2325446351429182668);
        tokensPurchased[61] = 30000 ether;
        wallets[62] = address(0x170D2eA8f593FCAbDB353DBf92fC9E4a417D688C);
        tokensPurchased[62] = 29271.6692 ether;
        wallets[63] = address(0x3784FC0D91723D13ff57e3Ae19976dA2DE029786);
        tokensPurchased[63] = 30000 ether;
        wallets[64] = address(0x81409E4C1a55C034EC86F64A75d18D911A8B0071);
        tokensPurchased[64] = 30000 ether;
        wallets[65] = address(0x5Db8EFF3Bd353f7F676f3444d4dA359c97F554F5);
        tokensPurchased[65] = 30000 ether;
        wallets[66] = address(0x35f32de5C007d8e24c6Ac0bf4573E73e52FC4602);
        tokensPurchased[66] = 30000 ether;
        wallets[67] = address(0xc7D77A35Ba4316cc1da44feaF82Fd6de3172fCcC);
        tokensPurchased[67] = 10000 ether;
        wallets[68] = address(0x4EE662EEe92FDf81c683d417Ac150aF20AA5c1E6);
        tokensPurchased[68] = 10992.2085 ether;
        wallets[69] = address(0xBBbdd423f84Da939e0D9a0c2d45D29a463b3C27B);
        tokensPurchased[69] = 6500 ether;
        wallets[70] = address(0x60a5b71677d690022F0c0D69069382B9b1c4D849);
        tokensPurchased[70] = 30000 ether;
        wallets[71] = address(0xD8CD45494F87DdC548D1945197C686e92519419b);
        tokensPurchased[71] = 30000 ether;
        wallets[72] = address(0xE09B073a057cE89e33eedeaD97F0c4a132Ca0c73);
        tokensPurchased[72] = 30000 ether;
        wallets[73] = address(0xd49ca496615643f70c80785Ef10e0b9837368a9e);
        tokensPurchased[73] = 30000 ether;
        wallets[74] = address(0xC5119F19620EeA91b29E9Ef55ea1D387A0D05A06);
        tokensPurchased[74] = 30000 ether;
        wallets[75] = address(0x65D69652D9276f75474945f475bC4C62A7bAf84B);
        tokensPurchased[75] = 30000 ether;
        wallets[76] = address(0x076EeaE11E645d27B4a180D74982332A71feB660);
        tokensPurchased[76] = 20000 ether;
        wallets[77] = address(0x8D1a855F95834AD9f3B6805B44D305FC5f902Ae8);
        tokensPurchased[77] = 30000 ether;
        wallets[78] = address(0xB5D9A773b889d8614C12c9017B018a173Fbc885B);
        tokensPurchased[78] = 5018.6322 ether;
        wallets[79] = address(0x98843D6baAa4ca7F956aB51F795a666490E15Df8);
        tokensPurchased[79] = 30000 ether;
        wallets[80] = address(0x6a8f1dC16F297249015104bC92A646C1A479c32d);
        tokensPurchased[80] = 30000 ether;
        wallets[81] = address(0x464B3C2e6E4aae8E3e6BD0e73ebeaE33d057Aea8);
        tokensPurchased[81] = 30000 ether;
        wallets[82] = address(0xc304b0dA47Ce4786AbDecA7dF1da96532A31f37B);
        tokensPurchased[82] = 10297.7987 ether;
        wallets[83] = address(0x75d55B4947AEF358201C131cE34D5e4A495E3043);
        tokensPurchased[83] = 6000 ether;
        wallets[84] = address(0x1A5C1a74d274b318fc93D91ccF72B9e368341Cb2);
        tokensPurchased[84] = 30000 ether;
        wallets[85] = address(0x7F6118314Aa6a69a908ac0BAB7e5cf24A5Eb2af3);
        tokensPurchased[85] = 30000 ether;
        wallets[86] = address(0x454e4ce649E5b6d2dcF7268d737567653B018080);
        tokensPurchased[86] = 30000 ether;
        wallets[87] = address(0x8A7a0294E4b80278D07FaF8839318421735E02be);
        tokensPurchased[87] = 30000 ether;
        wallets[88] = address(0xfdeC0AAbcd16F5e3953aa479D6d1dff298483c1e);
        tokensPurchased[88] = 15000 ether;
        wallets[89] = address(0x591e3216Cc9429123A3f455C0E1425aB827f3310);
        tokensPurchased[89] = 30000 ether;
        wallets[90] = address(0xFA4D7b553b1Db8E4a126DB4cd074dF198e2657E8);
        tokensPurchased[90] = 30000 ether;
        wallets[91] = address(0x11F7956B8FA1A1C24d122b0f22F266e0f8c058f2);
        tokensPurchased[91] = 10000 ether;
        wallets[92] = address(0xEB541113e84Bc2b2c93Cde40ea942fa09Df2d06b);
        tokensPurchased[92] = 25000 ether;
        wallets[93] = address(0xF1E13e3b92f7e5CbADEAaB20819Fa855028a9726);
        tokensPurchased[93] = 30000 ether;
        wallets[94] = address(0xA8370cc0A1CeC097538cB44F6358da193170AD41);
        tokensPurchased[94] = 30000 ether;
        wallets[95] = address(0xd0d2a5966836C2084a89631C5A9835c5AF30511a);
        tokensPurchased[95] = 30000 ether;
        wallets[96] = address(0x9D26624e43d84C11D9451b7e2d93745095eD9898);
        tokensPurchased[96] = 30000 ether;
        wallets[97] = address(0x6028bD1405463Bc5F2339d81f894AB276768d1b4);
        tokensPurchased[97] = 30000 ether;
        wallets[98] = address(0x07cE780e343D217Af98017eb4268EfB5e2F9CF20);
        tokensPurchased[98] = 15000 ether;
        wallets[99] = address(0x19775E1817BC7a1e41060F80E0d00EabAE2959A7);
        tokensPurchased[99] = 20000 ether;
        wallets[100] = address(0xa6473CcE13F11614745e6Bf9caD704646616A9b8);
        tokensPurchased[100] = 30000 ether;
        wallets[101] = address(0xbFcFF3aA2579219eA47bbdc783d3E5afB2174895);
        tokensPurchased[101] = 30000 ether;
        wallets[102] = address(0x758a60e064B7B606eCE9e8E70c75C83b11BB8e79);
        tokensPurchased[102] = 100000 ether;
        wallets[103] = address(0x5CD8CB99dDB5c672767087565B883f942fAA5924);
        tokensPurchased[103] = 5104.4411 ether;
        wallets[104] = address(0x75A08B77D325B0252ef6dEbD91b8832496a3D61F);
        tokensPurchased[104] = 30000 ether;
        wallets[105] = address(0x6625C700f800ce4764eDF91C2C7E6Bc0feAe4ab2);
        tokensPurchased[105] = 30000 ether;
        wallets[106] = address(0x5316133Fdd242c44e68b362571Dda78758fe1177);
        tokensPurchased[106] = 30000 ether;
        wallets[107] = address(0xF0Bf51330309C6d75370e06e91ff8cbe71E688CD);
        tokensPurchased[107] = 30000 ether;
        wallets[108] = address(0xF6673C931ba7F8D97158bE11869660992F9FFE00);
        tokensPurchased[108] = 30000 ether;
        wallets[109] = address(0x1F9cd2544004a659707CAbF3FeF49bAB93e8184C);
        tokensPurchased[109] = 30000 ether;
        wallets[110] = address(0xaf9b18D07C791257222A5C1F47000A9955b96e65);
        tokensPurchased[110] = 30000 ether;
        wallets[111] = address(0xb64d63df30a55371af32B85b981154d18fc61718);
        tokensPurchased[111] = 30000 ether;
        wallets[112] = address(0x6C529cE2bdd778E8C9D36c75a434e626a583cAa9);
        tokensPurchased[112] = 30000 ether;
        wallets[113] = address(0x7031e568C911605c14Ce9a8f2E9A63a5246748C4);
        tokensPurchased[113] = 5676.4036 ether;
        wallets[114] = address(0x43c0c658423a54d9baD05c694f4828fA5c4B566A);
        tokensPurchased[114] = 10000 ether;
        wallets[115] = address(0x1273162B4fE3424Bf03d74c88181714Bbd263393);
        tokensPurchased[115] = 30000 ether;
        wallets[116] = address(0x2093d87807a430Ca7F4f3BAE983152E5527028c2);
        tokensPurchased[116] = 30000 ether;

        return (wallets, tokensPurchased);
    }

    function testMock() public {}
}
