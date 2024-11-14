//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {UD60x18} from "@prb/math/src/UD60x18.sol";

interface ILPStaking {
    struct StakeInfo {
        uint256 stakedAmount;
        uint256 withdrawnAmount;
        uint256 stakedAt;
        uint256 withdrawTime;
        uint256 stakePeriod;
        uint256 claimedPoints;
        uint256 claimedRewards;
        uint256 lastRewardsClaimedAt;
    }

    event Staked(address indexed wallet, uint256 amount, uint256 lockIndex);
    event Withdrawn(address indexed wallet, uint256 amount, uint256 lockIndex);
    event MultipliersUpdated(uint256 multiplier3x, uint256 multiplier6x, uint256 multiplier9x, uint256 multiplier12x);
    event PointsClaimed(address indexed wallet, uint256 amount);
    event RewardsClaimed(address indexed wallet, uint256 amount);
    event FeesWithdrawn(uint256 amount);

    error ILPStaking__Error(string message);
}
