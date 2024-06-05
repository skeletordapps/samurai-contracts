// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

interface IFactory {
    struct InitialConfig {
        string name;
        string symbol;
        string description;
    }

    // struct Tokens {
    //     address token;
    //     address acceptedToken;
    // }

    // struct Allocations {
    //     uint256 maxAllocation;
    //     uint256 minPerWallet;
    //     uint256 maxPerWallet;
    // }

    // struct Durations {
    //     uint256 registrationStartsAt;
    //     uint256 registrationDuration;
    //     uint256 participationStartsAt;
    //     uint256 participationDuration;
    // }

    error Factory__Cannot_Be_Blank();
    // error Factory__Invalid_Address();
    // error Factory__Cannot_Be_Zero();
    // error Factory__Max_Per_Wallet_Must_Be_Greater_Than_Min_Per_Wallet();
}
