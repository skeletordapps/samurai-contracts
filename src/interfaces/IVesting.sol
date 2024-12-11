// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IVesting {
    /// Errors

    error IVesting__Unauthorized(string message);
    error IVesting__Invalid(string message);

    /// Events

    event TokensSet(address[] acceptedTokens);
    event PeriodsSet(Periods periods);
    event TokensFilled(address indexed wallet, uint256 amount);
    event NeedRefund(address[] walletsToRefund);
    event Claimed(address indexed wallet, uint256 claimedAmount);
    event IDOTokenSet(address indexed token);
    event RemainingTokensWithdrawal(uint256 amount);
    event PurchasesSet(address[] wallets, uint256[] tokensPurchased);
    event PointsClaimed(address indexed wallet, uint256 amount);
    event RefundsWidrawal(address indexed wallet, uint256 amount);
    event RefundPeriodSet(uint256 refundPeriod);

    /// Enums

    enum VestingType {
        CliffVesting,
        LinearVesting,
        PeriodicVesting
    }

    enum PeriodType {
        None,
        Seconds,
        Days,
        Weeks,
        Months
    }

    /// Structs

    struct Periods {
        uint256 vestingDuration;
        uint256 vestingAt;
        uint256 cliff;
    }
}
