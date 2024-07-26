// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

interface IIDO {
    /// Errors

    error IIDO__Unauthorized(string message);
    error IIDO__Invalid(string message);

    /// Events

    event TokensSet(address[] acceptedTokens);
    event AmountsSet(Amounts amounts);
    event RangesSet(WalletRange[] ranges);
    event PeriodsSet(Periods periods);
    event RefundSet(Refund refund);
    event WalletLinked(address indexed wallet, string linkedWallet);
    event Registered(address indexed wallet);
    event Participated(address indexed wallet, address token, uint256 amount);
    event PublicAllowed();
    event IDOTokensFilled(address indexed wallet, uint256 amount);
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
    event Refunded(address indexed wallet, uint256 amount);
    event TGEClaimed(address indexed wallet, uint256 amountInTokens);
    event Claimed(address indexed wallet, uint256 claimedAmount);
    event ParticipationsWithdrawal(uint256 amount);
    event IDOTokenSet(address indexed token);
    event RemainingTokensWithdrawal(uint256 amount);

    /// Enums

    enum VestingType {
        CliffVesting,
        LinearVesting,
        PeriodicVesting
    }

    /// Structs

    struct WalletRange {
        string name;
        uint256 min;
        uint256 max;
    }

    struct Periods {
        uint256 registrationAt;
        uint256 participationStartsAt;
        uint256 participationEndsAt;
        uint256 vestingDuration;
        uint256 vestingAt;
        uint256 cliff;
    }

    struct Amounts {
        uint256 tokenPrice;
        uint256 maxAllocations;
        uint256 tgeReleasePercent;
    }

    struct Refund {
        bool active;
        uint256 feePercent;
        uint256 period;
    }
}
