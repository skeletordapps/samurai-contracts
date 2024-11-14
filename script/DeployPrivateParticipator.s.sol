// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Script} from "forge-std/Script.sol";
import {PrivateParticipator} from "../src/PrivateParticipator.sol";

contract DeployPrivateParticipator is Script {
    function run() external returns (PrivateParticipator participator) {
        uint256 maxAllocations = 25_000e6;
        uint256 pricePerToken = 145e6;
        uint256 minPerWallet = 100e6;
        (address[] memory wallets, uint256[] memory purchases) = loadWallets();

        vm.startBroadcast();
        participator = new PrivateParticipator(
            vm.envAddress("BASE_USDC_ADDRESS"), maxAllocations, pricePerToken, minPerWallet, wallets, purchases
        );
        vm.stopBroadcast();

        return participator;
    }

    function loadWallets() internal pure returns (address[] memory wallets, uint256[] memory purchases) {
        wallets = new address[](57);
        purchases = new uint256[](57);

        wallets[0] = 0xcaE8cF1e2119484D6CC3B6EFAad2242aDBDB1Ea8;
        purchases[0] = 3;
        wallets[1] = 0xcab2AaDD8b875F74d5b04f1453D9a9cAd2F395CD;
        purchases[1] = 1;
        wallets[2] = 0xb3E72703F98A30b22a15bE2cC439cC2E1f9B64Be;
        purchases[2] = 5;
        wallets[3] = 0xb020F0FeD0878ea7489f2456b482557723C6D62B;
        purchases[3] = 2;
        wallets[4] = 0x75A08B77D325B0252ef6dEbD91b8832496a3D61F;
        purchases[4] = 3;
        wallets[5] = 0xE9131F2A8952c91dDDa2bA63E5aEEd98568EC5Af;
        purchases[5] = 3;
        wallets[6] = 0x526f78b26436A1A627C9e82880eD9b7afb470B5D;
        purchases[6] = 3;
        wallets[7] = 0x43E3946b8AD45251232aFa860de45f1044cbA516;
        purchases[7] = 2;
        wallets[8] = 0xeF4da186884C213Be62b136F30F81c498018A1F8;
        purchases[8] = 3;
        wallets[9] = 0x964F14D320519B4Ec81a3037E79F56fcaC732353;
        purchases[9] = 3;
        wallets[10] = 0x3e1fADF5DC02cCac42f23A756ecD8889C2134126;
        purchases[10] = 1;
        wallets[11] = 0x34831fc3c805459FF099924A5E8Dcb036ee8e4d5;
        purchases[11] = 3;
        wallets[12] = 0x6F0093Ac51CF3ba423Ae0db1298Bc0131f0bAB76;
        purchases[12] = 3;
        wallets[13] = 0x223312fc85C6C5a9e46B26b5eA857c4ef0071E9D;
        purchases[13] = 2;
        wallets[14] = 0x496Fc41e88e8B40812c426691eE23FAA1B3cb910;
        purchases[14] = 4;
        wallets[15] = 0xf5477598DFfFb6EC1f9057C6141d2D84630e30bF;
        purchases[15] = 3;
        wallets[16] = 0xF17546f6274Cc52b669285C6fA14E1AEeB296e02;
        purchases[16] = 3;
        wallets[17] = 0x6Df137e629792DF6A1D728cB9069389Ef2f63587;
        purchases[17] = 1;
        wallets[18] = 0x148AFbce5CE5417e966E92D2c04Bd81D8cB0e04e;
        purchases[18] = 20;
        wallets[19] = 0xFe70E1BE7a3D5263F8521019f339133a8448FfE8;
        purchases[19] = 3;
        wallets[20] = 0xaFE163f57960b946597c9b36B39718C6dD989EE4;
        purchases[20] = 3;
        wallets[21] = 0x290cd04a35a80481A0F78AcA91466128dDbC088F;
        purchases[21] = 3;
        wallets[22] = 0xabadf6B6a0f176D9D67879B6F744B0301f4B5007;
        purchases[22] = 3;
        wallets[23] = 0x15220634c3F1b994576CB7DCB8684938Ace8F2d4;
        purchases[23] = 3;
        wallets[24] = 0xce538B15E77358ade315d2191B042cEb75f0469B;
        purchases[24] = 3;
        wallets[25] = 0x95263BAc044453E7d63347a399f8Cdea99f0d531;
        purchases[25] = 1;
        wallets[26] = 0xE7B06d0fE751818B1FF7DffB0376602fC286B972;
        purchases[26] = 3;
        wallets[27] = 0x0DA56e6EC31366774Ad2D081b1539b7e7353A3DA;
        purchases[27] = 1;
        wallets[28] = 0xCBD25a2F3f443640f4906AAf4E3c45fcEAacBaFc;
        purchases[28] = 3;
        wallets[29] = 0xFAeFcb66EaAdaA24B98DE173FBEcDeF03E6B6bdC;
        purchases[29] = 18;
        wallets[30] = 0x758a60e064B7B606eCE9e8E70c75C83b11BB8e79;
        purchases[30] = 3;
        wallets[31] = 0x5d9F3079CB204aBA84AB34FdA277f37A6ef42EFd;
        purchases[31] = 3;
        wallets[32] = 0x431b5DDB0AcE97eBC3d936403ea25831BaD832B6;
        purchases[32] = 3;
        wallets[33] = 0x6028bD1405463Bc5F2339d81f894AB276768d1b4;
        purchases[33] = 3;
        wallets[34] = 0xcEd29BA48490C51E4348e654C313AC97762beCCC;
        purchases[34] = 1;
        wallets[35] = 0x7F4c44602F7C8860869AeE8e03f257A6dAd9310E;
        purchases[35] = 1;
        wallets[36] = 0x589708188395686E05E69ED2c9182ec1504B2343;
        purchases[36] = 3;
        wallets[37] = 0x2B92423fDB70c166c7fad664493Cda07337e40Fd;
        purchases[37] = 3;
        wallets[38] = 0xbfad818EdB25DC4eebac8Cc44a7533bE4652AD6C;
        purchases[38] = 2;
        wallets[39] = 0xF3b375a2bcebDef5878E52B29eb2fEDC564f1d21;
        purchases[39] = 2;
        wallets[40] = 0x3d1E7D80e7357BBd450Ef1E722b4d87674bab2B0;
        purchases[40] = 3;
        wallets[41] = 0x42D14dAc314f7bd4948C92b2f03a36BEfE0Ce14F;
        purchases[41] = 3;
        wallets[42] = 0x194856b0D232821A75Fd572c40F28905028b5613;
        purchases[42] = 1;
        wallets[43] = 0x93E467D56bb04fC64A978d584E12dA1eA4Dc4cE0;
        purchases[43] = 3;
        wallets[44] = 0x3669Dce51dD32165A5749419049457944f48bb35;
        purchases[44] = 1;
        wallets[45] = 0xe81A37c7b4537F854a4f974A715802218309Dd8C;
        purchases[45] = 1;
        wallets[46] = 0xd8401789734C1E18bd707997dB2275380712cF30;
        purchases[46] = 1;
        wallets[47] = 0xc505B6FCB0E4693A1dB21E861d8341FcC346175C;
        purchases[47] = 1;
        wallets[48] = 0xE52e043D5476bD4be1881a07aeDE7eDBE06B5f24;
        purchases[48] = 1;
        wallets[49] = 0x5AD17A1A013E6dc9356fa5E047e70d1B5D490BbA;
        purchases[49] = 2;
        wallets[50] = 0xe74B3696c6d93716ce01472125Be3b9C74aA378B;
        purchases[50] = 3;
        wallets[51] = 0x6FD8b5C58ACf7F98dD84C047CB099dA1fcc75613;
        purchases[51] = 3;
        wallets[52] = 0xBD53cda492cc4D008c1Ed0B7223B674FF0c60F39;
        purchases[52] = 3;
        wallets[53] = 0xC3D4FEd7ad9976fb210a85Ffeb122E2141050133;
        purchases[53] = 3;
        wallets[54] = 0x53d55D5410Fa37053c7e6882aF9c693d778db7Ce;
        purchases[54] = 3;
        wallets[55] = 0x62C5d2ec2722BE908c9aDA4C783D1116a240F2dA;
        purchases[55] = 1;
        wallets[56] = 0xc8Be6527e44B0db0EB967D21d06C67b85229E606;
        purchases[56] = 3;

        return (wallets, purchases);
    }

    function testMock() public {}
}
