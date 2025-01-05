// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {DeployedVesting} from "../../../src/DeployedVesting.sol";
import {DeployVesting} from "../../../script/DeployVesting.s.sol";
import {ERC20Mock} from "../../../src/mocks/ERC20Mock.sol";
import {IVesting} from "../../../src/interfaces/IVesting.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";
import {BokkyPooBahsDateTimeLibrary} from "@BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";
import {console} from "forge-std/console.sol";

contract xxxTest is Test {
    uint256 fork;
    string public RPC_URL;

    DeployedVesting vesting;

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        vesting = DeployedVesting(0xCFe4E1e1dDB2c5AcaF57Af30271FA2996Bc1aF9F);
    }

    function testBasic() public view {
        address wallet = 0x614550C16857b11a66548d65aA45805659814c93;

        (uint256 vestingDuration, uint256 vestingAt, uint256 cliff) = vesting.periods();

        if (block.timestamp < vestingAt) console.log("Vesting not started"); // Vesting not started
        if (vesting.purchases(wallet) == 0) console.log("Wallet has no purchases"); // Wallet has no purchases
        if (vesting.askedRefund(wallet)) console.log("Asked refund");

        UD60x18 max = ud(vesting.purchases(wallet));
        UD60x18 claimed = ud(vesting.tokensClaimed(wallet));

        /// User already claimed all tokens vested
        if (claimed == max) console.log("Claimed everything");

        uint256 _cliffEndsAt = vesting.cliffEndsAt();
        bool isTgeClaimed = vesting.hasClaimedTGE(wallet);

        /// Only TGE is vested during cliff period
        if (block.timestamp <= _cliffEndsAt) {
            if (isTgeClaimed) console.log("claimed tge - zero");
            else console.log("tge tokens - ", vesting.previewTGETokens(wallet));
        }

        UD60x18 balance = max.sub(claimed);

        /// All tokens were vested -> return all balance remaining
        if (block.timestamp > vesting.vestingEndsAt()) console.log("code return balance - ", balance.intoUint256());

        /// CALCS  ================================================

        /// CLIFF VESTING
        if (vesting.vestingType() == IVesting.VestingType.CliffVesting) {
            console.log("code return balance - ", balance.intoUint256());
        }

        console.log("WILL BEGIN CALCS");

        /// LINEAR VESTING & PERIODIC VESTING
        UD60x18 total = ud(vesting.totalPurchased());
        console.log("total", total.intoUint256());
        uint256 vested = vesting.previewVestedTokens();
        console.log("vested", vested);
        UD60x18 totalVestedPercentage = ud(vested).mul(convert(100)).div(total);
        console.log("totalVestedPercentage", totalVestedPercentage.intoUint256());
        UD60x18 walletSharePercentage = max.mul(convert(100)).div(total);
        console.log("walletSharePercentage", walletSharePercentage.intoUint256());
        UD60x18 walletVestedPercentage = walletSharePercentage.mul(totalVestedPercentage).div(convert(100));
        console.log("walletVestedPercentage", walletVestedPercentage.intoUint256());
        UD60x18 walletVested = total.mul(walletVestedPercentage).div(convert(100));
        console.log("walletVested", walletVested.intoUint256());
        console.log("claimed", claimed.intoUint256());
        // UD60x18 walletClaimable = walletVested.sub(claimed);

        // console.log("walletClaimable", walletClaimable.intoUint256());
    }
}
