// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

interface IIDO {
    error IIDO__Unauthorized(string message);
    error IIDO__Invalid(string message);

    event Allocated(address indexed wallet, address token, uint256 amount);
    event Whitelisted(address[] addresses);
    event Whitelisted(address indexed wallet);
    event PublicAllowed();
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);

    struct WalletRange {
        string name;
        uint256 min;
        uint256 max;
    }

    struct Periods {
        uint256 registrationStartsAt;
        uint256 registrationEndsAt;
        uint256 participationStartsAt;
        uint256 participationEndsAt;
        uint256 vestingStartsAt;
        uint256 releaseStartsAt;
        uint256 releaseEndsAt;
    }

    //-----------------------------------------

    // Phase Errors
    error IDO__Not_In_Registration_Phase(string message);
    error IDO__Not_In_Participation_Phase(string message);
    error IDO__Not_In_Vesting_Phase(string message);
    error IDO__Not_In_Release_Phase(string message);

    // Input Validation Errors
    error IDO__Cannot_Be_Zero(string message);
    error IDO__Max_Per_Wallet_Must_Be_Greater_Than_Min_Per_Wallet(string message);

    // Participation Errors
    error IDO__Insufficient_Amount_To_Participate(string message);
    error IDO__Exceeds_Max_Amount_Permitted(string message);
    error IDO__Not_Registered(string message);
    error IDO__SamNFT_Not_Found(string message);
    error IDO__Cannot_Update_After_Participation_Started(string message);
    error IDO__Cannot_Update_With_Zero(string message);
    error IDO__Max_Value_Cannot_Be_Less_Than_Min_Value(string message);
    error IDO__Invalid_Address(string message);
    error IDO__Insufficient_Balance(string message);
    error IDO__Cannot_Claim_Participations_Before_End_Period(string message);
    error IDO__Invalid_Message_Signature(string message);
    error IDO__Already_Participating(string message);

    // Wallet Errors
    error IDO__Wallet_Registered(string message);
    error IDO__Wallet_Blacklisted(string message);

    // Timing Errors
    error IDO__Time_Too_Close_To_Now(string message);

    // Update Errors
    error IDO__Cannot_Update_In_Vesting_Phase(string message);
    error IDO__Wrong_Release_Type(string message);
    error IDO__Wrong_Claim_Period_Type(string message);
    error IDO__Cannot_Update_In_Release_Phase(string message);

    // Token Claim Errors
    error IDO__Already_Claimed_TGE(string message);
    error IDO__No_Tokens_Available(string message);
    error IDO__Not_Allowed(string message);
    error IDO__Out_Claim_Period(string message);

    // Enums

    enum ReleaseType {
        Minute,
        Day,
        Week,
        Month,
        Year,
        Invalid
    }

    enum ClaimPeriodType {
        Day,
        Week,
        Month,
        ThreeMonths,
        Year,
        Invalid
    }

    enum Phase {
        Registration,
        Participation,
        Vesting,
        Release
    }

    // Events

    event Registered(address indexed wallet, uint256 timestamp);
    event Participating(address indexed wallet, uint256 amount, uint256 timestamp, bool registered);
    event Claimed(address indexed wallet, uint256 claimedAmount);
    event PublicAllowed(uint256 timestamp);
    event TGEClaimed(address indexed wallet, uint256 amountInTokens);
    event RegistrationSet(uint256 timestamp);
    event ParticipationSet(uint256 timestamp);
    event VestingSet(uint256 timestamp);
    event ReleaseSet(uint256 timestamp);
    event ParticipationsWithdrawal(uint256 amount);
    event RemainingTokensWithdrawal(uint256 amount);
    event IDOConfigUpdated(string field, bytes value);
}
