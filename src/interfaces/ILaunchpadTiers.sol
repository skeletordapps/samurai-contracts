//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

interface ILaunchpadTiers {
    struct Tier {
        string name;
        uint256 staking;
        uint256 lpStaking;
        uint256 multiplier;
    }

    event Added(uint256 index);
    event Removed(Tier tier);
    event Updated(uint256 index);

    function counter() external view returns (uint256);
    function tiers(uint256 index) external view returns (Tier memory);
}
