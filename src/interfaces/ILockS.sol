//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {UD60x18} from "@prb/math/src/UD60x18.sol";

interface ILockS {
    struct LockInfo {
        uint256 lockedAmount;
        uint256 withdrawnAmount;
        uint256 lockedAt;
        uint256 unlockTime;
        uint256 lockPeriod;
        uint256 claimedPoints;
    }

    struct Request {
        address wallet;
        uint256 amount;
        uint256 lockIndex;
        bool isFulfilled;
    }

    event Locked(address indexed wallet, uint256 amount);
    event Withdrawn(address indexed wallet, uint256 amount, uint256 lockIndex);
    event MultipliersUpdated(uint256 multiplier3x, uint256 multiplier6x, uint256 multiplier9x, uint256 multiplier12x);
    event PointsRequested(address indexed wallet, uint256 amount);
    event RequestFulfilled(ILockS.Request[] indexed requests);

    error ILock__Error(string message);

    function locksOf(address wallet) external view returns (ILockS.LockInfo[] memory);
    function previewClaimablePoints(address wallet, uint256 lockIndex) external view returns (uint256);
}
