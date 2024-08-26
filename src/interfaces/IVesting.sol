// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

interface IVesting {
    /// Errors

    error IVesting__Unauthorized(string message);
    error IVesting__Invalid(string message);

    /// Events

    event TokensSet(address[] acceptedTokens);
    event PeriodsSet(Periods periods);
    event TokensFilled(address indexed wallet, uint256 amount);
    event Refunded(address indexed wallet, uint256 amount);
    event Claimed(address indexed wallet, uint256 claimedAmount);
    event IDOTokenSet(address indexed token);
    event RemainingTokensWithdrawal(uint256 amount);

    /// Enums

    enum VestingType {
        CliffVesting,
        LinearVesting,
        PeriodicVesting
    }

    enum PeriodType {
        Days,
        Month
    }

    /// Structs

    struct Periods {
        uint256 vestingDuration;
        uint256 vestingAt;
        uint256 cliff;
    }
}
