// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";

library Scale {
    function precision(uint256 value, uint256 to) internal pure returns (uint256) {
        return value / to;
    }

    function toPrecision(uint256 value, uint256 with) internal pure returns (uint256) {
        uint256 diff = 1 * 10 ** (21 - with);
        return value / diff;
    }
}

contract BigNumbersTest is Test {
    using Scale for uint256;

    function setUp() public virtual {}

    function testNumbers1() public {
        uint256 price = 0.013e6;
        uint256 paidAmount = 100e6;
        UD60x18 convertedPrice = convert(price);
        UD60x18 convertedAmount = convert(paidAmount);
        UD60x18 amountOfTokens = convertedAmount.div(convertedPrice);

        uint256 tokens = amountOfTokens.intoUint256();
        console.log(tokens);
        // assertEq(tokens, 7692307692307692307);
    }

    function testNumbers2() public {
        uint256 price = 0.013e6;
        uint256 paidAmount = 100e6;
        UD60x18 convertedPrice = convert(price);
        UD60x18 convertedAmount = convert(paidAmount);
        UD60x18 amountOfTokens = convertedAmount.div(convertedPrice);

        uint256 tokens = amountOfTokens.intoUint256().toPrecision(9);
        assertEq(tokens, 7692307692);
    }

    function testNumbers3() public {
        uint256 price = 0.013e9;
        uint256 paidAmount = 100e9;
        UD60x18 convertedPrice = convert(price);
        UD60x18 convertedAmount = convert(paidAmount);
        UD60x18 amountOfTokens = convertedAmount.div(convertedPrice);

        uint256 tokens = amountOfTokens.intoUint256().toPrecision(9);
        assertEq(tokens, 7692307692);
    }

    function testNumbers4() public {
        uint256 price = 0.013 ether;
        uint256 paidAmount = 100 ether;
        UD60x18 convertedPrice = convert(price);
        UD60x18 convertedAmount = convert(paidAmount);
        UD60x18 amountOfTokens = convertedAmount.div(convertedPrice);

        uint256 tokens = amountOfTokens.intoUint256().toPrecision(18);
        assertEq(tokens, 7692307692307692307);
    }

    function testNumbers5() public {
        uint256 price = 0.013 ether;
        uint256 paidAmount = 100 ether;
        UD60x18 convertedPrice = convert(price);
        UD60x18 convertedAmount = convert(paidAmount);
        UD60x18 amountOfTokens = convertedAmount.div(convertedPrice);

        uint256 tokens = amountOfTokens.intoUint256().toPrecision(18);
        assertEq(tokens, 7692307692307692307);

        uint256 percentage = 0.08e18;

        UD60x18 convertedPercentage = ud(percentage);

        uint256 tgeTokens = amountOfTokens.mul(convertedPercentage).intoUint256().toPrecision(18);
        console.log(tgeTokens);
    }

    function testNumbers6() public {
        console.log("TESTING NUMBERS");

        uint256 price = 0.013 ether;
        uint256 paidAmount = 0.4523 ether;
        uint256 lastTimestamp = 1719843918;
        uint256 currentTimestamp = 1720278945;
        uint256 percentage = 0.08e18;
        console.log("paidAmount", paidAmount);
        console.log("lastTimestamp", lastTimestamp);
        console.log("currentTimestamp", currentTimestamp);
        console.log("percentage", percentage);

        UD60x18 convertedPrice = convert(price);
        UD60x18 convertedAmount = convert(paidAmount);
        UD60x18 convertedLastTimestamp = convert(lastTimestamp);
        UD60x18 convertedCurrentTimestamp = convert(currentTimestamp);
        UD60x18 convertedPercentage = convert(percentage);

        UD60x18 elapsed = convertedCurrentTimestamp.sub(convertedLastTimestamp);

        UD60x18 amountOfTokens = convertedAmount.div(convertedPrice);
        console.log("amountOfTokens", amountOfTokens.intoUint256());
        uint256 tokens = amountOfTokens.intoUint256();
        console.log("tokens", tokens);

        // UD60x18 expectedAmountOfTokens = ud(7.6923076923e18);
        // console.log("expectedAmountOfTokens", expectedAmountOfTokens.intoUint256());

        // assertEq(amountOfTokens.intoUint256(), expectedAmountOfTokens.intoUint256());

        // UD60x18 partialAmount = convertedAmount.mul(convertedPercentage);
        // console.log("partialAmount", partialAmount.intoUint256());
    }
}
