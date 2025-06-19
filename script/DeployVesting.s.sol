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
        address idoToken = address(0x6a72d3A87f97a0fEE2c2ee4233BdAEBc32813D7a); // ESX
        address points = address(0x5f5f2D8C61a507AA6C47f30cc4f76B937C10a8e1); // SPS TOKEN
        uint256 tgeReleasePercent = 0.05e18; // 5% on TGE
        uint256 pointsPerToken = 0.08e18; // 0.08 per token
        uint256 refundPeriod = 0;
        bool isRefundable = false;
        IVesting.VestingType vestingType = IVesting.VestingType.PeriodicVesting;
        IVesting.PeriodType vestingPeriodType = IVesting.PeriodType.Days;
        IVesting.Periods memory periods = IVesting.Periods({vestingDuration: 9, vestingAt: 1750343400, cliff: 3});
        (address[] memory wallets, uint256[] memory tokensPurchased) = loadWallets();

        vm.startBroadcast();
        vesting = new Vesting(
            idoToken,
            points,
            tgeReleasePercent,
            pointsPerToken,
            refundPeriod,
            isRefundable,
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
            48 hours,
            true,
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
        uint256 pointsPerToken = 0.08e18;
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
            48 hours,
            true,
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
            48 hours,
            true,
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
            48 hours,
            true,
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

        wallets[0] = address(0x0A32A9237aa5165377717082408907aca255A575);
        tokensPurchased[0] = 55126.79162 ether;

        wallets[1] = address(0xdb836337cBbF4481a46e99116590696514C78404);
        tokensPurchased[1] = 183755.9721 ether;

        return (wallets, tokensPurchased);
    }

    function loadWallets() internal pure returns (address[] memory wallets, uint256[] memory tokensPurchased) {
        wallets = new address[](114);
        tokensPurchased = new uint256[](114);

        wallets[0] = address(0x0A32A9237aa5165377717082408907aca255A575);
        tokensPurchased[0] = 55126.79162 ether;
        wallets[1] = address(0xdb836337cBbF4481a46e99116590696514C78404);
        tokensPurchased[1] = 183755.9721 ether;
        wallets[2] = address(0xf6d476f812e1E823184D6949F5B0ECd28bA1014a);
        tokensPurchased[2] = 183755.9721 ether + 1653803.749 ether;
        wallets[3] = address(0x6Df137e629792DF6A1D728cB9069389Ef2f63587);
        tokensPurchased[3] = 183755.9721 ether;
        wallets[4] = address(0x6FD8b5C58ACf7F98dD84C047CB099dA1fcc75613);
        tokensPurchased[4] = 183755.9721 ether + 1029033.444 ether;
        wallets[5] = address(0xE7B06d0fE751818B1FF7DffB0376602fC286B972);
        tokensPurchased[5] = 183755.9721 ether + 257258.3609 ether + 808526.2771 ether;
        wallets[6] = address(0x4dA551d7ad2328039c8e734A4b0beb9Bdde35406);
        tokensPurchased[6] = 147004.7777 ether;
        wallets[7] = address(0x1E781A4538a932e628C37d468e53Cad749425207);
        tokensPurchased[7] = 183755.9721 ether;
        wallets[8] = address(0x95263BAc044453E7d63347a399f8Cdea99f0d531);
        tokensPurchased[8] = 183755.9721 ether;
        wallets[9] = address(0xA0F9BDe4Da8495Bdc24C8184A5D931fd1e142578);
        tokensPurchased[9] = 183755.9721 ether;

        wallets[10] = address(0x9D26624e43d84C11D9451b7e2d93745095eD9898);
        tokensPurchased[10] = 183755.9721 ether;
        wallets[11] = address(0x02F60fEF631AC1691fe3d38191b8E3430930d2f4);
        tokensPurchased[11] = 183755.9721 ether;
        wallets[12] = address(0xBBbdd423f84Da939e0D9a0c2d45D29a463b3C27B);
        tokensPurchased[12] = 114663.7266 ether;
        wallets[13] = address(0x3a2299fAf77dBC1f45c20361585ab59d63a2059d);
        tokensPurchased[13] = 183755.9721 ether;
        wallets[14] = address(0x0D358949F53f5CF5989f1c72892169eDE93ebDd3);
        tokensPurchased[14] = 183755.9721 ether;
        wallets[15] = address(0xdFfcaF4Ed2fb0D7db022CD7856527bd0000D6c99);
        tokensPurchased[15] = 183755.9721 ether;
        wallets[16] = address(0xe4CA74A41694707E19584480f8429A5073B930E2);
        tokensPurchased[16] = 183755.9721 ether;
        wallets[17] = address(0x43E3946b8AD45251232aFa860de45f1044cbA516);
        tokensPurchased[17] = 183755.9721 ether;
        wallets[18] = address(0xCBD25a2F3f443640f4906AAf4E3c45fcEAacBaFc);
        tokensPurchased[18] = 183755.9721 ether;
        wallets[19] = address(0xfc0cA4f2534603123a557140a24695D906C18FAA);
        tokensPurchased[19] = 183755.9721 ether;

        wallets[20] = address(0x81409E4C1a55C034EC86F64A75d18D911A8B0071);
        tokensPurchased[20] = 183755.9721 ether;
        wallets[21] = address(0xfB9046dEB2bA41fA98744779aD10B3B252d3fcEd);
        tokensPurchased[21] = 183755.9721 ether;
        wallets[22] = address(0xC3D4FEd7ad9976fb210a85Ffeb122E2141050133);
        tokensPurchased[22] = 183755.9721 ether;
        wallets[23] = address(0xeDD011efCE6f8c8b92493cF84AbC445b8e0992DC);
        tokensPurchased[23] = 183755.9721 ether;
        wallets[24] = address(0xc7D77A35Ba4316cc1da44feaF82Fd6de3172fCcC);
        tokensPurchased[24] = 183755.9721 ether;
        wallets[25] = address(0x54E067DF58a559b5b6602736D36a8c0CE92B553e);
        tokensPurchased[25] = 36751.19441 ether + 36751.19441 ether;
        wallets[26] = address(0x4b229c24894c134aC9eAeD34b72D5Fb2D2945aB4);
        tokensPurchased[26] = 183755.9721 ether;
        wallets[27] = address(0x3646F36a60B112074391Ff720E89B2b1bBc0B8eC);
        tokensPurchased[27] = 183755.9721 ether;
        wallets[28] = address(0xFEeDfe9c2aCb949Ef80b0fa714E282D66Bd2f955);
        tokensPurchased[28] = 55126.79162 ether;
        wallets[29] = address(0x99559Af00d2F43cE773b84316CCE6f47C908f076);
        tokensPurchased[29] = 183755.9721 ether;
        wallets[30] = address(0x53d55D5410Fa37053c7e6882aF9c693d778db7Ce);
        tokensPurchased[30] = 183755.9721 ether;

        wallets[31] = address(0x5082a9A2707621a83643F1D450FEe403ECF5f928);
        tokensPurchased[31] = 183755.9721 ether;
        wallets[32] = address(0xE52e043D5476bD4be1881a07aeDE7eDBE06B5f24);
        tokensPurchased[32] = 183755.9721 ether;
        wallets[33] = address(0x048FF88aCF734e8Fd68b67B785f1294D57C94cB7);
        tokensPurchased[33] = 91877.98603 ether;
        wallets[34] = address(0xd5b2A7613967445B79Edf3d123d5fD4AB5aA80C8);
        tokensPurchased[34] = 183755.9721 ether;
        wallets[35] = address(0xc8Be6527e44B0db0EB967D21d06C67b85229E606);
        tokensPurchased[35] = 183755.9721 ether;
        wallets[36] = address(0xD8CD45494F87DdC548D1945197C686e92519419b);
        tokensPurchased[36] = 183755.9721 ether;
        wallets[37] = address(0x076EeaE11E645d27B4a180D74982332A71feB660);
        tokensPurchased[37] = 183755.9721 ether;
        wallets[38] = address(0xe359aF39cfeAB65cb3eEa34277D9FCe5bD2Af22a);
        tokensPurchased[38] = 36751.19441 ether;
        wallets[39] = address(0x1193448fd3d2EC0Ac5587501C81096076D3172D2);
        tokensPurchased[39] = 183755.9721 ether;

        wallets[40] = address(0x3669Dce51dD32165A5749419049457944f48bb35);
        tokensPurchased[40] = 91877.98603 ether;
        wallets[41] = address(0x843cD8C36328cF18f9C1F1e11f0aCF88d99762aC);
        tokensPurchased[41] = 183755.9721 ether;
        wallets[42] = address(0x230aC1564A4e09c72B38B7407a9a6D5197928DfA);
        tokensPurchased[42] = 81220.13965 ether;
        wallets[43] = address(0xD59D2967ff47F8f258a9fc16D153d3C3935b423F);
        tokensPurchased[43] = 183755.9721 ether;
        wallets[44] = address(0x23777a214Af90185FA59fE692DafF609dd02Ab90);
        tokensPurchased[44] = 50133.47593 ether;
        wallets[45] = address(0x5E0b1f370C47cffa0e7A87137E9b8036e79Caa2a);
        tokensPurchased[45] = 73502.38883 ether;
        wallets[46] = address(0xcab2AaDD8b875F74d5b04f1453D9a9cAd2F395CD);
        tokensPurchased[46] = 183755.9721 ether;
        wallets[47] = address(0x5d9F3079CB204aBA84AB34FdA277f37A6ef42EFd);
        tokensPurchased[47] = 183755.9721 ether;
        wallets[48] = address(0xBc013857FA476BE28A30c31D548D3cfcE09bfb3E);
        tokensPurchased[48] = 183755.9721 ether;
        wallets[49] = address(0x4CFf1E41B10dEC09f0Ac615Ed2E5138E91b75f24);
        tokensPurchased[49] = 36751.19441 ether;

        wallets[50] = address(0x843fdD402952dA6E170497e40bCaDCCf704E1320);
        tokensPurchased[50] = 183755.9721 ether + 1360529.217 ether;
        wallets[51] = address(0xD4C4C02214C765Cd485154e8aa3eD6FE9ea6F447);
        tokensPurchased[51] = 183755.9721 ether;
        wallets[52] = address(0x7a4AAB3452f132878a7dC993e14cF4Aa5A49cF38);
        tokensPurchased[52] = 183755.9721 ether;
        wallets[53] = address(0x547004Fee05B116010D9c188533CB8Be4B9027bB);
        tokensPurchased[53] = 36751.19441 ether;
        wallets[54] = address(0xa6473CcE13F11614745e6Bf9caD704646616A9b8);
        tokensPurchased[54] = 80852.62771 ether;
        wallets[55] = address(0x67B1eB19DbB2d95004BefB043b051eB720248157);
        tokensPurchased[55] = 110253.5832 ether;
        wallets[56] = address(0xFed2096261641E3efafeefDaB71d09b603ddC38a);
        tokensPurchased[56] = 183388.4601 ether;
        wallets[57] = address(0xe8Dda554B61f32b81C2C164928f472d2Bb888e48);
        tokensPurchased[57] = 73502.38883 ether;
        wallets[58] = address(0xaF8e755d9C1031b63465FB143174350220b8bdf8);
        tokensPurchased[58] = 183755.9721 ether;
        wallets[59] = address(0xdbEC81b4Eab0B5234dBd9ff7c456BF750d7a9086);
        tokensPurchased[59] = 183755.9721 ether + 275633.9581 ether + 91877.98603 ether;

        wallets[60] = address(0x93E467D56bb04fC64A978d584E12dA1eA4Dc4cE0);
        tokensPurchased[60] = 183755.9721 ether;
        wallets[61] = address(0x2093d87807a430Ca7F4f3BAE983152E5527028c2);
        tokensPurchased[61] = 183755.9721 ether;
        wallets[62] = address(0xfF4966AEB06E7f1038bd812e4205703Ae69AE2C3);
        tokensPurchased[62] = 110253.5832 ether;
        wallets[63] = address(0x0393954EE63cF32cb53149D6bd55433D6523a707);
        tokensPurchased[63] = 183755.9721 ether;
        wallets[64] = address(0xcCc8530C0F21f8A3Eeb247d183a2F6C23cD96218);
        tokensPurchased[64] = 183755.9721 ether;
        wallets[65] = address(0x1d7FC9739A39E2B3c2FE20349847b49dA3DC3DCd);
        tokensPurchased[65] = 36923.36567 ether;
        wallets[66] = address(0x3bF124372c36A8a946010E4899dD45586D82c481);
        tokensPurchased[66] = 183755.9721 ether + 1646085.998 ether;
        wallets[67] = address(0x0DA56e6EC31366774Ad2D081b1539b7e7353A3DA);
        tokensPurchased[67] = 55494.30356 ether + 88768.83499 ether;
        wallets[68] = address(0xcEd29BA48490C51E4348e654C313AC97762beCCC);
        tokensPurchased[68] = 73502.38883 ether;
        wallets[69] = address(0xbfA55361c4433311764Aead045815fcf87Ed746F);
        tokensPurchased[69] = 183755.9721 ether;

        wallets[70] = address(0x5CD8CB99dDB5c672767087565B883f942fAA5924);
        tokensPurchased[70] = 183755.9721 ether;
        wallets[71] = address(0x62C5d2ec2722BE908c9aDA4C783D1116a240F2dA);
        tokensPurchased[71] = 147004.7777 ether;
        wallets[72] = address(0xB1686bF52BF8A58d88fDCf7e9624A23C732bA4bb);
        tokensPurchased[72] = 183755.9721 ether;
        wallets[73] = address(0x833A49e676bfCd4a4Ea766C63DB46243d90527C4);
        tokensPurchased[73] = 147004.7777 ether;
        wallets[74] = address(0x170D2eA8f593FCAbDB353DBf92fC9E4a417D688C);
        tokensPurchased[74] = 183755.9721 ether;
        wallets[75] = address(0x25ebE14A2fBC820562a3fF92C75007493fbB8448);
        tokensPurchased[75] = 147004.7777 ether;
        wallets[76] = address(0x389b8Bd4FAc72ff9Aa5fD888a4B3283Ac4c14b28);
        tokensPurchased[76] = 183755.9721 ether + 551267.9162 ether;
        wallets[77] = address(0xe81A37c7b4537F854a4f974A715802218309Dd8C);
        tokensPurchased[77] = 110253.5832 ether;
        wallets[78] = address(0x16D6eA53520E751a99295718ee50c7756313DdB8);
        tokensPurchased[78] = 36751.19441 ether;
        wallets[79] = address(0xF0Bf51330309C6d75370e06e91ff8cbe71E688CD);
        tokensPurchased[79] = 183755.9721 ether;

        wallets[80] = address(0xF6673C931ba7F8D97158bE11869660992F9FFE00);
        tokensPurchased[80] = 183755.9721 ether;
        wallets[81] = address(0x1F9cd2544004a659707CAbF3FeF49bAB93e8184C);
        tokensPurchased[81] = 183755.9721 ether;
        wallets[82] = address(0xaa2c7dc97a2C90410D2916886e29DFBe3c82c843);
        tokensPurchased[82] = 183755.9721 ether;
        wallets[83] = address(0xaf9b18D07C791257222A5C1F47000A9955b96e65);
        tokensPurchased[83] = 183755.9721 ether;
        wallets[84] = address(0xb64d63df30a55371af32B85b981154d18fc61718);
        tokensPurchased[84] = 183755.9721 ether;
        wallets[85] = address(0x60A6A9b401eC11677506344D4deD9Bfac3608D2a);
        tokensPurchased[85] = 183755.9721 ether;
        wallets[86] = address(0xb020F0FeD0878ea7489f2456b482557723C6D62B);
        tokensPurchased[86] = 165380.3749 ether;
        wallets[87] = address(0x7E53769606642a6E7719dc2eBC9Ff156b7f19532);
        tokensPurchased[87] = 183755.9721 ether;
        wallets[88] = address(0xeF4da186884C213Be62b136F30F81c498018A1F8);
        tokensPurchased[88] = 183755.9721 ether;
        wallets[89] = address(0x5E7c1E0Ca95f212685177f1136B3e6B3C1F863b6);
        tokensPurchased[89] = 183755.9721 ether;

        wallets[90] = address(0x6e5B935Ac926E11DeC812eb0A5425ec5e4c96355);
        tokensPurchased[90] = 183755.9721 ether;
        wallets[91] = address(0xEDE97e60c2A20cD8946b296813Ea073748CAD6B4);
        tokensPurchased[91] = 183755.9721 ether;
        wallets[92] = address(0x646Cf1df8654B47A4A839dF3C27767348CFcC811);
        tokensPurchased[92] = 183755.9721 ether + 1401846.075 ether;
        wallets[93] = address(0x57b3c68cAf0Ebea2d9173bDB013655fD8Da31AA4);
        tokensPurchased[93] = 183755.9721 ether;
        wallets[94] = address(0xC8FFa49DAeD557f5f4b2Fa2593Bb14593dCc81BA);
        tokensPurchased[94] = 73502.38883 ether + 110253.5832 ether + 771775.0827 ether + 882028.6659 ether;
        wallets[95] = address(0x6C529cE2bdd778E8C9D36c75a434e626a583cAa9);
        tokensPurchased[95] = 183755.9721 ether;
        wallets[96] = address(0x29E433A7Da5Ed6CdB2678BB0B4bdA234eA2703fA);
        tokensPurchased[96] = 183755.9721 ether;
        wallets[97] = address(0x211955a2BBF636330E777350840b6ebc366a4Ef2);
        tokensPurchased[97] = 91877.98603 ether;
        wallets[98] = address(0x8f7Bccb4cE8b0e088727573fEab19aD557924550);
        tokensPurchased[98] = 735023.8883 ether;
        wallets[99] = address(0x0a2d3Dd46E44AcEC0DA085268502880bB384bCC0);
        tokensPurchased[99] = 38897.4491 ether;

        wallets[100] = address(0x3E0e00541bD811e2d307aeCa886a426e1f004226);
        tokensPurchased[100] = 1102535.832 ether;
        wallets[101] = address(0x431b5DDB0AcE97eBC3d936403ea25831BaD832B6);
        tokensPurchased[101] = 183755.9721 ether;
        wallets[102] = address(0x93CF3ADBbc12a28b9D0E0ea749235a396C5B22A9);
        tokensPurchased[102] = 147188.5336 ether + 222735.0239 ether;
        wallets[103] = address(0x8EA501Fa332dFd3E0bf82F419f2f1ba834f2442F);
        tokensPurchased[103] = 91877.98603 ether;
        wallets[104] = address(0x8B63eE013C840380391e6b0b4d5983C741C7252e);
        tokensPurchased[104] = 1470047.777 ether;
        wallets[105] = address(0x1c60a3B03EE47A53B4f649F43d73CA25aFAc648c);
        tokensPurchased[105] = 439945.5083 ether + 294744.5792 ether;
        wallets[106] = address(0x938c26E078640d5369DD18Fc4550fE1049E80Bc3);
        tokensPurchased[106] = 1837559.721 ether;
        wallets[107] = address(0xA27cC4a180b0c46DDD3B13F44FEeD08826a442Fe);
        tokensPurchased[107] = 367511.9441 ether;
        wallets[108] = address(0x9d760948a3ac118dFb67538cCB55db10f0637783);
        tokensPurchased[108] = 735023.8883 ether;
        wallets[109] = address(0x37C021f4F9703d5D53dAE3Fc1A42c308f1aD7fc0);
        tokensPurchased[109] = 735023.8883 ether;

        wallets[110] = address(0xabD356ff5bC3c76EC273170FC60Eb7356c4d33Db);
        tokensPurchased[110] = 735023.8883 ether;
        wallets[111] = address(0x89F7f2710d6484b8dBEb7bF3260697D55Ce5B480);
        tokensPurchased[111] = 735023.8883 ether;
        wallets[112] = address(0x824CD0925dd842b2C3d5155f448c291534Ea7053);
        tokensPurchased[112] = 661521.4994 ether;
        wallets[113] = address(0xcaE8cF1e2119484D6CC3B6EFAad2242aDBDB1Ea8);
        tokensPurchased[113] = 22660.78648 ether;

        return (wallets, tokensPurchased);
    }

    function testMock() public {}
}
