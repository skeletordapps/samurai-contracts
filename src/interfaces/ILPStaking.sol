//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

interface ILPStaking {
    struct User {
        uint256 lockedAmount;
        uint256 lastUpdate;
        uint256 rewardsClaimed;
        uint256 rewardsEarned;
    }

    error Staking_Not_Initialized();
    error Staking_Already_Initialized();
    error Staking_Period_Ended();
    error Staking_Max_Limit_Reached();
    error Staking_No_Rewards_Available();
    error Staking_No_Balance_Staked();
    error Staking_Amount_Exceeds_Balance();
    error Staking_Apply_Not_Available_Yet();
    error Staking_Insufficient_Amount();
    error Staking_Exceeds_Farming_Balance(uint256 balance);
    error Staking_Emergency_Withdrawal_Occurred();
    error Staking_Emergency_Withdrawal_Not_Occurred();
}
