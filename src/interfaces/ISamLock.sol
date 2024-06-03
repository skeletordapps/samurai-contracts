//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {UD60x18} from "@prb/math/src/UD60x18.sol";

interface ISamLock {
    struct LockInfo {
        uint256 lockIndex;
        uint256 lockedAmount;
        uint256 withdrawnAmount;
        uint256 lockedAt;
        uint256 unlockTime;
        uint256 lockPeriod;
    }

    event Locked(address indexed wallet, uint256 amount, uint256 lockIndex);
    event Withdrawn(address indexed wallet, uint256 amount, uint256 lockIndex);
    event MultipliersUpdated(uint256 multiplier3x, uint256 multiplier6x, uint256 multiplier9x, uint256 multiplier12x);

    error SamLock__NotFound();
    error SamLock__InsufficientAmount();
    error SamLock__Invalid_Period();
    error SamLock__InvalidLockIndex();
    error SamLock__Cannot_Unlock_Before_Period();
    error SamLock__InvalidMultiplier();
    error SamLock__InvalidAddress();
}
