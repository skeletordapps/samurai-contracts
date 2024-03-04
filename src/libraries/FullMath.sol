// SPDX-License-Identifier: CC-BY-4.0
pragma solidity ^0.8.23;

// taken from https://medium.com/coinmonks/math-in-solidity-part-3-percents-and-proportions-4db014e080b1
// license is CC-BY-4.0
library FullMath {
    function fullMul(uint256 x, uint256 y) internal pure returns (uint256 l, uint256 h) {
        uint256 mm = mulmod(x, y, type(uint256).max); // Use max value instead of -1
        l = x * y;
        h = mm - l;
        if (l > mm) h -= 1; // Check for overflow (l > mm instead of l < mm)
    }

    function fullDiv(uint256 l, uint256 h, uint256 d) private pure returns (uint256) {
        uint256 pow2 = d & 1; // Isolate least significant bit (LSB)
        d /= pow2;
        l /= pow2;
        l += h * ((pow2) / pow2 + 1);
        uint256 r = 1;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        r *= 2 - d * r;
        return l * r;
    }

    function mulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256) {
        (uint256 l, uint256 h) = fullMul(x, y);

        uint256 mm = mulmod(x, y, d);
        if (mm > l) h -= 1;
        l -= mm;

        if (h == 0) return l / d;

        require(h < d, "FullMath: FULLDIV_OVERFLOW");
        return fullDiv(l, h, d);
    }
}
