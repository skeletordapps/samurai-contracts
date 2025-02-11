//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {UD60x18} from "@prb/math/src/UD60x18.sol";

interface IPastLock {
    // 0xE4FeDe2f45E7257d9c269a752c89f6bB1Aa1E5c8

    struct LockInfo {
        uint256 lockIndex;
        uint256 lockedAmount;
        uint256 withdrawnAmount;
        uint256 lockedAt;
        uint256 unlockTime;
        uint256 lockPeriod;
        uint256 multiplier;
    }

    function getLockInfos(address wallet) external view returns (LockInfo[] memory);
    function pointsByLock(address wallet, uint256 lockIndex) external view returns (uint256);
}

interface ILock {
    struct LockInfo {
        uint256 lockedAmount;
        uint256 withdrawnAmount;
        uint256 lockedAt;
        uint256 unlockTime;
        uint256 lockPeriod;
        uint256 claimedPoints;
    }

    event Locked(address indexed wallet, uint256 amount);
    event Withdrawn(address indexed wallet, uint256 amount, uint256 lockIndex);
    event MultipliersUpdated(uint256 multiplier3x, uint256 multiplier6x, uint256 multiplier9x, uint256 multiplier12x);
    event PointsClaimed(address indexed wallet, uint256 amount);
    event PointsMigrated(address indexed wallet, uint256 amount);

    error ILock__Error(string message);
}
