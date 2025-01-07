// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Script} from "forge-std/Script.sol";
import {AirdropTGE} from "../src/AirdropTGE.sol";
import {console} from "forge-std/console.sol";
import {ERC20Mock} from "../src/mocks/ERC20Mock.sol";

contract DeployAirdropTGE is Script {
    function run() external returns (AirdropTGE airdrop) {
        uint256 privateKey = block.chainid == 8453 ? vm.envUint("PRIVATE_KEY") : vm.envUint("DEV_HOT_PRIVATE_KEY");
        address token = address(0x3e62fED35c97145e6B445704B8CE74B2544776A9); // EARNM
        (address[] memory wallets, uint256[] memory amounts) = loadWallets();

        vm.startBroadcast(privateKey);
        airdrop = new AirdropTGE(token, wallets, amounts);
        vm.stopBroadcast();

        return airdrop;
    }

    function loadWallets() internal pure returns (address[] memory wallets, uint256[] memory amounts) {
        wallets = new address[](12);
        amounts = new uint256[](12);

        wallets[0] = address(0x5d9F3079CB204aBA84AB34FdA277f37A6ef42EFd);
        amounts[0] = 17142.858 ether;

        wallets[1] = address(0x6846576A9F362fB4b23AEB0779A8Ce455f253D8D);
        amounts[1] = 8571.429 ether;

        wallets[2] = address(0x895f18A11948D49c4D455cCFBe94CE0a75319273);
        amounts[2] = 8571.429 ether;

        wallets[3] = address(0xA06c44151E84a85456A1370CC73a23848D1802fF);
        amounts[3] = 8571.429 ether;

        wallets[4] = address(0xB5D9A773b889d8614C12c9017B018a173Fbc885B);
        amounts[4] = 8571.429 ether;

        wallets[5] = address(0x389b8Bd4FAc72ff9Aa5fD888a4B3283Ac4c14b28);
        amounts[5] = 22857.144 ether;

        wallets[6] = address(0x496Fc41e88e8B40812c426691eE23FAA1B3cb910);
        amounts[6] = 4228.572 ether;

        wallets[7] = address(0x7d9fBd459F1B5462aA8aaC2f6dFd1a85973e1d68);
        amounts[7] = 8571.429 ether;

        wallets[8] = address(0xC7BAe2455A6aDE972C5647849ABaaF72f94A4E5B);
        amounts[8] = 14285.715 ether;

        wallets[9] = address(0x246a9b7EE043cA431968FEbD33917bB3AF804921);
        amounts[9] = 2857.143 ether;

        wallets[10] = address(0x173143e501030f4bcdCD1238E69823e5276bB3cd);
        amounts[10] = 2857.143 ether;

        wallets[11] = address(0xc3939C3043aB077F254F576B2f4B2f1f0E54D1cc);
        amounts[11] = 8571.429 ether;

        return (wallets, amounts);
    }

    function testMock() public {}
}
