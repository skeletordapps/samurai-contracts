//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console2} from "forge-std/console2.sol";
import {ILaunchpadTiers} from "./interfaces/ILaunchpadTiers.sol";

contract LaunchpadTiers is Ownable {
    uint256 public counter;
    mapping(uint256 index => ILaunchpadTiers.Tier tier) public tiers;

    constructor() Ownable(msg.sender) {}

    function addTier(string memory name, uint256 staking, uint256 lpStaking, uint256 multiplier) external onlyOwner {
        uint256 index = counter + 1;
        tiers[index] = ILaunchpadTiers.Tier(name, staking, lpStaking, multiplier);
        counter++;

        emit ILaunchpadTiers.Added(index);
    }

    function removeTier(uint256 tierIndex) external onlyOwner {
        ILaunchpadTiers.Tier memory tierCopy = tiers[tierIndex];
        delete tiers[tierIndex];
        counter--;

        emit ILaunchpadTiers.Removed(tierCopy);
    }

    function updateTier(uint256 tierIndex, string memory name, uint256 staking, uint256 lpStaking, uint256 multiplier)
        external
        onlyOwner
    {
        tiers[tierIndex] = ILaunchpadTiers.Tier(name, staking, lpStaking, multiplier);
        emit ILaunchpadTiers.Updated(tierIndex);
    }
}
