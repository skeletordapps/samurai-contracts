//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {UD60x18} from "@prb/math/src/UD60x18.sol";

interface ILock {
    struct LockInfo {
        uint256 lockIndex;
        uint256 lockedAmount;
        uint256 withdrawnAmount;
        uint256 lockedAt;
        uint256 unlockTime;
        uint256 lockPeriod;
        uint256 claimedPoints;
    }

    event Locked(address indexed wallet, uint256 amount, uint256 lockIndex);
    event Withdrawn(address indexed wallet, uint256 amount, uint256 lockIndex);
    event MultipliersUpdated(uint256 multiplier3x, uint256 multiplier6x, uint256 multiplier9x, uint256 multiplier12x);
    event PointsClaimed(address indexed wallet, uint256 amount);

    error ILock__Error(string message);
}
