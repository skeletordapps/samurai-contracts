//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ISamLock} from "./ISamLock.sol";

interface ISamNfts {
    function balanceOf(address owner) external view returns (uint256);
}

interface ISamLocks {
    function getLockInfos(address wallet) external view returns (ISamLock.LockInfo[] memory);
}

interface ISamGaugeLP {
    function balanceOf(address wallet) external view returns (uint256);
}

// MOCKS FOR TESTS

interface MockSamNfts {
    function balanceOf(address wallet) external view returns (uint256);
}

interface MockSamLocks {
    function getLockInfos(address wallet) external view returns (ISamLock.LockInfo[] memory);
}

interface MockSamGaugeLP {
    function balanceOf(address wallet) external view returns (uint256);
}

interface ISamuraiTiers {
    struct Tier {
        string name;
        uint256 numOfSamNfts;
        uint256 minLocking;
        uint256 maxLocking;
        uint256 minLPStaking;
        uint256 maxLPStaking;
    }

    event Added(uint256 index);
    event Removed(Tier tier);
    event Updated(uint256 index);

    function counter() external view returns (uint256);
    function tiers(uint256 index) external view returns (Tier memory);
    function getTier(address wallet) external view returns (ISamuraiTiers.Tier memory);
}
