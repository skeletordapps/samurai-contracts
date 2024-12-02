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
        address idoToken = address(0x888F2E45d3c27d9CaE72AcA93174C530dFB3D4d8); // SKR TOKEN
        address points = address(0xDf0fDc572849f01CdaB35b80cA41Ce67051C8Dfe); // SPS TOKEN
        uint256 tgeReleasePercent = 0.3e18;
        uint256 pointsPerToken = 0.315e18;
        IVesting.VestingType vestingType = IVesting.VestingType.LinearVesting;
        IVesting.Periods memory periods = IVesting.Periods({vestingDuration: 5, vestingAt: 1733238000, cliff: 1});
        (address[] memory wallets, uint256[] memory tokensPurchased) = loadWallets();

        vm.startBroadcast(privateKey);
        vesting = new Vesting(
            idoToken, points, tgeReleasePercent, pointsPerToken, vestingType, periods, wallets, tokensPurchased
        );
        vm.stopBroadcast();

        return vesting;
    }

    function runForTests(IVesting.VestingType _vestingType) external returns (Vesting vesting) {
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
            idoToken, points, tgeReleasePercent, pointsPerToken, _vestingType, periods, wallets, tokensPurchased
        );

        sp.grantRole(IPoints.Roles.MINTER, address(vesting));
        loadWallets();
        vm.stopBroadcast();

        return vesting;
    }

    function runForFuzzTests(
        IVesting.VestingType _vestingType,
        uint256 _tgeReleasePercent,
        IVesting.Periods memory _periods
    ) external returns (Vesting vesting) {
        uint256 privateKey = block.chainid == 31337 ? vm.envUint("FOUNDRY_PRIVATE_KEY") : vm.envUint("PRIVATE_KEY");
        ERC20Mock newToken = new ERC20Mock("IDO TOKEN 2", "IDT2");
        address idoToken = address(newToken);
        uint256 tgeReleasePercent = _tgeReleasePercent;
        uint256 pointsPerToken = 100;
        IVesting.Periods memory periods = _periods;
        (address[] memory wallets, uint256[] memory tokensPurchased) = loadWalletsForTests();

        vm.startBroadcast(privateKey);
        SamuraiPoints sp = new SamuraiPoints();
        address points = address(sp);

        vesting = new Vesting(
            idoToken, points, tgeReleasePercent, pointsPerToken, _vestingType, periods, wallets, tokensPurchased
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

    function loadWalletsSimple() internal pure returns (address[] memory wallets, uint256[] memory tokensPurchased) {
        wallets = new address[](1);
        tokensPurchased = new uint256[](1);

        wallets[0] = address(0x38b7EF909DD8E85be3e63a917B9ac4C208FC59e5);
        tokensPurchased[0] = 3199.37 ether;
    }

    function loadWallets() internal pure returns (address[] memory wallets, uint256[] memory tokensPurchased) {
        wallets = new address[](139);
        tokensPurchased = new uint256[](139);

        wallets[0] = address(0xcaE8cF1e2119484D6CC3B6EFAad2242aDBDB1Ea8);
        tokensPurchased[0] = 3199.37 ether;
        wallets[1] = address(0xa5f22DAdBe1BfbCf9bb4001f419387Ad1086d631);
        tokensPurchased[1] = 28571.43 ether;
        wallets[2] = address(0x98843D6baAa4ca7F956aB51F795a666490E15Df8);
        tokensPurchased[2] = 28571.43 ether;
        wallets[3] = address(0x1273162B4fE3424Bf03d74c88181714Bbd263393);
        tokensPurchased[3] = 28571.43 ether;
        wallets[4] = address(0xe4CA74A41694707E19584480f8429A5073B930E2);
        tokensPurchased[4] = 95238.1 ether;
        wallets[5] = address(0x5d9F3079CB204aBA84AB34FdA277f37A6ef42EFd);
        tokensPurchased[5] = 57142.86 ether;
        wallets[6] = address(0xBD53cda492cc4D008c1Ed0B7223B674FF0c60F39);
        tokensPurchased[6] = 28571.43 ether;
        wallets[7] = address(0xA0F9BDe4Da8495Bdc24C8184A5D931fd1e142578);
        tokensPurchased[7] = 47619.05 ether;
        wallets[8] = address(0xeF4da186884C213Be62b136F30F81c498018A1F8);
        tokensPurchased[8] = 28571.43 ether;
        wallets[9] = address(0x5e5a47069dD0C8C78428Be27E180acbA37e8e622);
        tokensPurchased[9] = 28571.43 ether;
        wallets[10] = address(0x2B92423fDB70c166c7fad664493Cda07337e40Fd);
        tokensPurchased[10] = 342857.14 ether;
        wallets[11] = address(0x9D26624e43d84C11D9451b7e2d93745095eD9898);
        tokensPurchased[11] = 133333.33 ether;
        wallets[12] = address(0x19A0491be8714eC7661eD41910E3630C3D8AB1A7);
        tokensPurchased[12] = 476190.48 ether;
        wallets[13] = address(0x29E433A7Da5Ed6CdB2678BB0B4bdA234eA2703fA);
        tokensPurchased[13] = 66666.67 ether;
        wallets[14] = address(0x6F0093Ac51CF3ba423Ae0db1298Bc0131f0bAB76);
        tokensPurchased[14] = 266666.67 ether;
        wallets[15] = address(0x276f90535DaDD16C42F15886eEEAA2864128803e);
        tokensPurchased[15] = 170000 ether;
        wallets[16] = address(0x857bb773e87b12977a392Fd32d24B3A83e3cB7e2);
        tokensPurchased[16] = 252380.95 ether;
        wallets[17] = address(0x6846576A9F362fB4b23AEB0779A8Ce455f253D8D);
        tokensPurchased[17] = 28571.43 ether;
        wallets[18] = address(0x6FD8b5C58ACf7F98dD84C047CB099dA1fcc75613);
        tokensPurchased[18] = 28571.43 ether;
        wallets[19] = address(0x6B1Cbd651a51C25f07B1F0fCf776E1050d1c2c98);
        tokensPurchased[19] = 19047.62 ether;
        wallets[20] = address(0x64DEeCB9f372aCf9C388Ca9f045Cf211A202F329);
        tokensPurchased[20] = 28571.43 ether;
        wallets[21] = address(0xaCd50015d9A7fbA1F53F2771307759b28f5f8B9B);
        tokensPurchased[21] = 28571.43 ether;
        wallets[22] = address(0xB1686bF52BF8A58d88fDCf7e9624A23C732bA4bb);
        tokensPurchased[22] = 28571.43 ether;
        wallets[23] = address(0x8FF4c4d45b703CcFF3b6D985E9bba9d89aF6942b);
        tokensPurchased[23] = 28571.43 ether;
        wallets[24] = address(0x276c3195bb657335c6Bf8e39eB1Cb01Dd36Ba547);
        tokensPurchased[24] = 28571.43 ether;
        wallets[25] = address(0x3d1E7D80e7357BBd450Ef1E722b4d87674bab2B0);
        tokensPurchased[25] = 28571.43 ether;
        wallets[26] = address(0xb020F0FeD0878ea7489f2456b482557723C6D62B);
        tokensPurchased[26] = 57142.86 ether;
        wallets[27] = address(0x5374883897Cb3d7a2129413710708318a0b39A9D);
        tokensPurchased[27] = 28571.43 ether;
        wallets[28] = address(0x95263BAc044453E7d63347a399f8Cdea99f0d531);
        tokensPurchased[28] = 28571.43 ether;
        wallets[29] = address(0x34831fc3c805459FF099924A5E8Dcb036ee8e4d5);
        tokensPurchased[29] = 28571.43 ether;
        wallets[30] = address(0x42D14dAc314f7bd4948C92b2f03a36BEfE0Ce14F);
        tokensPurchased[30] = 28571.43 ether;
        wallets[31] = address(0x895f18A11948D49c4D455cCFBe94CE0a75319273);
        tokensPurchased[31] = 28571.43 ether;
        wallets[32] = address(0xD2895e8732d550D0A32ad1cdA749a07ad1281b8e);
        tokensPurchased[32] = 28571.43 ether;
        wallets[33] = address(0x20fA1852fe0809CBd0566888F81d12B1521Cf94C);
        tokensPurchased[33] = 28571.43 ether;
        wallets[34] = address(0x4b229c24894c134aC9eAeD34b72D5Fb2D2945aB4);
        tokensPurchased[34] = 28571.43 ether;
        wallets[35] = address(0x1A5C1a74d274b318fc93D91ccF72B9e368341Cb2);
        tokensPurchased[35] = 28571.43 ether;
        wallets[36] = address(0xA8370cc0A1CeC097538cB44F6358da193170AD41);
        tokensPurchased[36] = 28571.43 ether;
        wallets[37] = address(0x6625C700f800ce4764eDF91C2C7E6Bc0feAe4ab2);
        tokensPurchased[37] = 28571.43 ether;
        wallets[38] = address(0xBAD73848c943D908c8ED748c54ab6Cd5C90D4f79);
        tokensPurchased[38] = 77597.46 ether;
        wallets[39] = address(0x697f56598DBD4A3E1f71D03e7e12B9A696264578);
        tokensPurchased[39] = 28571.43 ether;
        wallets[40] = address(0xeDD011efCE6f8c8b92493cF84AbC445b8e0992DC);
        tokensPurchased[40] = 28571.43 ether;
        wallets[41] = address(0xA06c44151E84a85456A1370CC73a23848D1802fF);
        tokensPurchased[41] = 28571.43 ether;
        wallets[42] = address(0x53d55D5410Fa37053c7e6882aF9c693d778db7Ce);
        tokensPurchased[42] = 95238.1 ether;
        wallets[43] = address(0xD50e622e82137f91B6Ae43839d2Cc4C8F879c639);
        tokensPurchased[43] = 28571.43 ether;
        wallets[44] = address(0x076EeaE11E645d27B4a180D74982332A71feB660);
        tokensPurchased[44] = 28571.43 ether;
        wallets[45] = address(0xc8Be6527e44B0db0EB967D21d06C67b85229E606);
        tokensPurchased[45] = 28571.43 ether;
        wallets[46] = address(0x5316133Fdd242c44e68b362571Dda78758fe1177);
        tokensPurchased[46] = 28571.43 ether;
        wallets[47] = address(0x5B72a062bFcdAEFd3ca82639ff6727B6e490C9a2);
        tokensPurchased[47] = 28571.43 ether;
        wallets[48] = address(0x7a9c65966D782dA5EA51C85C950DcA15257A0F20);
        tokensPurchased[48] = 9571.43 ether;
        wallets[49] = address(0xc6e5c7BaBE6a0fD8EA77F2C144c2e5331705E0c3);
        tokensPurchased[49] = 14839.55 ether;
        wallets[50] = address(0x8A7a0294E4b80278D07FaF8839318421735E02be);
        tokensPurchased[50] = 28571.43 ether;
        wallets[51] = address(0xfB9046dEB2bA41fA98744779aD10B3B252d3fcEd);
        tokensPurchased[51] = 219047.62 ether;
        wallets[52] = address(0x194856b0D232821A75Fd572c40F28905028b5613);
        tokensPurchased[52] = 190476.19 ether;
        wallets[53] = address(0xB5D9A773b889d8614C12c9017B018a173Fbc885B);
        tokensPurchased[53] = 28571.43 ether;
        wallets[54] = address(0x238D614EFf8fd24dbB7233B597E2428280eBec48);
        tokensPurchased[54] = 28571.43 ether;
        wallets[55] = address(0x59459c6cD4611C667F8719Ebe6F25f8A9B19e71A);
        tokensPurchased[55] = 28571.43 ether;
        wallets[56] = address(0x75d55B4947AEF358201C131cE34D5e4A495E3043);
        tokensPurchased[56] = 15238.1 ether;
        wallets[57] = address(0x389b8Bd4FAc72ff9Aa5fD888a4B3283Ac4c14b28);
        tokensPurchased[57] = 76190.48 ether;
        wallets[58] = address(0xc4Ff72A7D98222aEE8c5a327e19362Fd9550bA82);
        tokensPurchased[58] = 28571.43 ether;
        wallets[59] = address(0x496Fc41e88e8B40812c426691eE23FAA1B3cb910);
        tokensPurchased[59] = 14095.24 ether;
        wallets[60] = address(0x11F7956B8FA1A1C24d122b0f22F266e0f8c058f2);
        tokensPurchased[60] = 9523.81 ether;
        wallets[61] = address(0x7d9fBd459F1B5462aA8aaC2f6dFd1a85973e1d68);
        tokensPurchased[61] = 28571.43 ether;
        wallets[62] = address(0x170D2eA8f593FCAbDB353DBf92fC9E4a417D688C);
        tokensPurchased[62] = 28571.43 ether;
        wallets[63] = address(0x15EA6F3c3e4F190ab72e86B9d3d75F75D3485C7C);
        tokensPurchased[63] = 28571.43 ether;
        wallets[64] = address(0xcab2AaDD8b875F74d5b04f1453D9a9cAd2F395CD);
        tokensPurchased[64] = 23826.35 ether;
        wallets[65] = address(0x587Efe35Bb3a77F4c644ba485B7f8b4ab3B8c498);
        tokensPurchased[65] = 28571.43 ether;
        wallets[66] = address(0x16b04DD860cB316E861051C4d7e8740183C969e9);
        tokensPurchased[66] = 28571.43 ether;
        wallets[67] = address(0xD4C4C02214C765Cd485154e8aa3eD6FE9ea6F447);
        tokensPurchased[67] = 28571.43 ether;
        wallets[68] = address(0x2Ca2ae442e68aE80d8A4F5e2C57566f7C36e2075);
        tokensPurchased[68] = 28571.43 ether;
        wallets[69] = address(0x1E781A4538a932e628C37d468e53Cad749425207);
        tokensPurchased[69] = 366666.67 ether;
        wallets[70] = address(0xC3D4FEd7ad9976fb210a85Ffeb122E2141050133);
        tokensPurchased[70] = 28571.43 ether;
        wallets[71] = address(0x964F14D320519B4Ec81a3037E79F56fcaC732353);
        tokensPurchased[71] = 9934.02 ether;
        wallets[72] = address(0x1193448fd3d2EC0Ac5587501C81096076D3172D2);
        tokensPurchased[72] = 28571.43 ether;
        wallets[73] = address(0x136f52Ee1E47152b163945a8f515924B9718E161);
        tokensPurchased[73] = 28571.43 ether;
        wallets[74] = address(0x60a5b71677d690022F0c0D69069382B9b1c4D849);
        tokensPurchased[74] = 476190.48 ether;
        wallets[75] = address(0x5Db8EFF3Bd353f7F676f3444d4dA359c97F554F5);
        tokensPurchased[75] = 409523.81 ether;
        wallets[76] = address(0xE09B073a057cE89e33eedeaD97F0c4a132Ca0c73);
        tokensPurchased[76] = 28571.43 ether;
        wallets[77] = address(0xc505B6FCB0E4693A1dB21E861d8341FcC346175C);
        tokensPurchased[77] = 28557.14 ether;
        wallets[78] = address(0xd49ca496615643f70c80785Ef10e0b9837368a9e);
        tokensPurchased[78] = 28571.43 ether;
        wallets[79] = address(0xC5119F19620EeA91b29E9Ef55ea1D387A0D05A06);
        tokensPurchased[79] = 28571.43 ether;
        wallets[80] = address(0x8D1a855F95834AD9f3B6805B44D305FC5f902Ae8);
        tokensPurchased[80] = 28571.43 ether;
        wallets[81] = address(0x6a8f1dC16F297249015104bC92A646C1A479c32d);
        tokensPurchased[81] = 28571.43 ether;
        wallets[82] = address(0x464B3C2e6E4aae8E3e6BD0e73ebeaE33d057Aea8);
        tokensPurchased[82] = 28571.43 ether;
        wallets[83] = address(0xaa2c7dc97a2C90410D2916886e29DFBe3c82c843);
        tokensPurchased[83] = 100000 ether;
        wallets[84] = address(0x7F6118314Aa6a69a908ac0BAB7e5cf24A5Eb2af3);
        tokensPurchased[84] = 28571.43 ether;
        wallets[85] = address(0x454e4ce649E5b6d2dcF7268d737567653B018080);
        tokensPurchased[85] = 28571.43 ether;
        wallets[86] = address(0x591e3216Cc9429123A3f455C0E1425aB827f3310);
        tokensPurchased[86] = 28571.43 ether;
        wallets[87] = address(0xFA4D7b553b1Db8E4a126DB4cd074dF198e2657E8);
        tokensPurchased[87] = 28571.43 ether;
        wallets[88] = address(0x4CE268F49EF0726d602a8b0f22FcC543aa23bb51);
        tokensPurchased[88] = 9523.81 ether;
        wallets[89] = address(0x02F60fEF631AC1691fe3d38191b8E3430930d2f4);
        tokensPurchased[89] = 28571.43 ether;
        wallets[90] = address(0x43E3946b8AD45251232aFa860de45f1044cbA516);
        tokensPurchased[90] = 28571.43 ether;
        wallets[91] = address(0x2D1f7d7A9cCa2fD8ea4b1A46f261a79972452563);
        tokensPurchased[91] = 47619.05 ether;
        wallets[92] = address(0x428232Eaeacb6105Ec9b4481f6E156cC7817CF65);
        tokensPurchased[92] = 14071.84 ether;
        wallets[93] = address(0xfc0cA4f2534603123a557140a24695D906C18FAA);
        tokensPurchased[93] = 319476.19 ether;
        wallets[94] = address(0x843cD8C36328cF18f9C1F1e11f0aCF88d99762aC);
        tokensPurchased[94] = 436519.05 ether;
        wallets[95] = address(0x916Ab8f0f48096E7C5C6aB2F0537f98376F73131);
        tokensPurchased[95] = 28571.43 ether;
        wallets[96] = address(0xC2E6a15f8b1016942e8Af2325446351429182668);
        tokensPurchased[96] = 28571.43 ether;
        wallets[97] = address(0xC7BAe2455A6aDE972C5647849ABaaF72f94A4E5B);
        tokensPurchased[97] = 47619.05 ether;
        wallets[98] = address(0x668cc58E6B704b7dBEF30607664599435e6854A9);
        tokensPurchased[98] = 28571.43 ether;
        wallets[99] = address(0xD836D8Cd28EaC6a8D90923C4e0C9a942e1221C9e);
        tokensPurchased[99] = 14190.48 ether;
        wallets[100] = address(0xc7D77A35Ba4316cc1da44feaF82Fd6de3172fCcC);
        tokensPurchased[100] = 28571.43 ether;
        wallets[101] = address(0xe74B3696c6d93716ce01472125Be3b9C74aA378B);
        tokensPurchased[101] = 476190.48 ether;
        wallets[102] = address(0xF3b375a2bcebDef5878E52B29eb2fEDC564f1d21);
        tokensPurchased[102] = 28557.12 ether;
        wallets[103] = address(0xa6473CcE13F11614745e6Bf9caD704646616A9b8);
        tokensPurchased[103] = 28571.43 ether;
        wallets[104] = address(0xe81A37c7b4537F854a4f974A715802218309Dd8C);
        tokensPurchased[104] = 9523.81 ether;
        wallets[105] = address(0x246a9b7EE043cA431968FEbD33917bB3AF804921);
        tokensPurchased[105] = 9523.81 ether;
        wallets[106] = address(0x43B513c90cb8A32d34ee213ED94F9655F10550fe);
        tokensPurchased[106] = 476190.48 ether;
        wallets[107] = address(0x173143e501030f4bcdCD1238E69823e5276bB3cd);
        tokensPurchased[107] = 9523.81 ether;
        wallets[108] = address(0x48A881c6c2fF0C962D017B2c4FB9701aFBE3c5f4);
        tokensPurchased[108] = 9523.81 ether;
        wallets[109] = address(0xbd5622C171B879920D79D5BD7346C547FC7D4aDA);
        tokensPurchased[109] = 28571.43 ether;
        wallets[110] = address(0xCADA5a36EEA0bE9bF125D6FF1f713Ad5e1B2d665);
        tokensPurchased[110] = 19047.62 ether;
        wallets[111] = address(0x51E02F63fb09D00DBFb6867660E014D8d21efdAE);
        tokensPurchased[111] = 19047.62 ether;
        wallets[112] = address(0x6C529cE2bdd778E8C9D36c75a434e626a583cAa9);
        tokensPurchased[112] = 28571.43 ether;
        wallets[113] = address(0x7031e568C911605c14Ce9a8f2E9A63a5246748C4);
        tokensPurchased[113] = 9523.81 ether;
        wallets[114] = address(0xd0d2a5966836C2084a89631C5A9835c5AF30511a);
        tokensPurchased[114] = 85714.29 ether;
        wallets[115] = address(0x0752Adfe7C42D89Bf2Fb3c22fFa18B7d0871C807);
        tokensPurchased[115] = 21904.76 ether;
        wallets[116] = address(0xC7CdE949574112861c81d64a70CA7d4375ef33bf);
        tokensPurchased[116] = 19047.62 ether;
        wallets[117] = address(0x2fcCB6f43e9a470440573E514D1CEe0296da1D48);
        tokensPurchased[117] = 19238.1 ether;
        wallets[118] = address(0x19775E1817BC7a1e41060F80E0d00EabAE2959A7);
        tokensPurchased[118] = 23809.52 ether;
        wallets[119] = address(0x3669Dce51dD32165A5749419049457944f48bb35);
        tokensPurchased[119] = 9523.81 ether;
        wallets[120] = address(0x93E467D56bb04fC64A978d584E12dA1eA4Dc4cE0);
        tokensPurchased[120] = 95238.1 ether;
        wallets[121] = address(0x0a2d3Dd46E44AcEC0DA085268502880bB384bCC0);
        tokensPurchased[121] = 28571.43 ether;
        wallets[122] = address(0x8310D0Ea5DA5A94e0ADec01F9Ba5C0d6D81E7359);
        tokensPurchased[122] = 95238.1 ether;
        wallets[123] = address(0xfdeC0AAbcd16F5e3953aa479D6d1dff298483c1e);
        tokensPurchased[123] = 28571.43 ether;
        wallets[124] = address(0xbfad818EdB25DC4eebac8Cc44a7533bE4652AD6C);
        tokensPurchased[124] = 95238.1 ether;
        wallets[125] = address(0x148AFbce5CE5417e966E92D2c04Bd81D8cB0e04e);
        tokensPurchased[125] = 28571.43 ether;
        wallets[126] = address(0xc3939C3043aB077F254F576B2f4B2f1f0E54D1cc);
        tokensPurchased[126] = 28571.43 ether;
        wallets[127] = address(0x5bb35d290ecc0f00A8C84b03E66D974b01D64AfB);
        tokensPurchased[127] = 301469.52 ether;
        wallets[128] = address(0x431b5DDB0AcE97eBC3d936403ea25831BaD832B6);
        tokensPurchased[128] = 28571.43 ether;
        wallets[129] = address(0x65D69652D9276f75474945f475bC4C62A7bAf84B);
        tokensPurchased[129] = 114285.71 ether;
        wallets[130] = address(0x614550C16857b11a66548d65aA45805659814c93);
        tokensPurchased[130] = 14285.71 ether;
        wallets[131] = address(0x62C5d2ec2722BE908c9aDA4C783D1116a240F2dA);
        tokensPurchased[131] = 28571.43 ether;
        wallets[132] = address(0x9951c9Ecf194eBc191Ca166Dc7327cf458cF866A);
        tokensPurchased[132] = 28571.43 ether;
        wallets[133] = address(0xCBD25a2F3f443640f4906AAf4E3c45fcEAacBaFc);
        tokensPurchased[133] = 28571.43 ether;
        wallets[134] = address(0x69eed0DA450Ce194DCea4317f688315973Dcba31);
        tokensPurchased[134] = 158666.67 ether;
        wallets[135] = address(0xb3E72703F98A30b22a15bE2cC439cC2E1f9B64Be);
        tokensPurchased[135] = 123809.52 ether;
        wallets[136] = address(0x259E9949c46975C3B250A78D25a4d998e5401a44);
        tokensPurchased[136] = 476190.48 ether;
        wallets[137] = address(0xb8121D3CD32432fbe17A031a212A600C070E8176);
        tokensPurchased[137] = 95238.1 ether;
        wallets[138] = address(0xd3cdb8e773f72F7FF06a52B1650b76B9e2912C2A);
        tokensPurchased[138] = 28571.43 ether;

        return (wallets, tokensPurchased);
    }

    function testMock() public {}
}
