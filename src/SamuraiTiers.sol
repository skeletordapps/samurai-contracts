//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {console2} from "forge-std/console2.sol";
import {ISamLock} from "./interfaces/ISamLock.sol";
import {ISamuraiTiers, ISamNfts, ISamLocks, ISamGaugeLP} from "./interfaces/ISamuraiTiers.sol";

contract SamuraiTiers is Ownable, ReentrancyGuard {
    address public nft = 0x519eD34150300dC0D04d50a5Ff401177A92b4406;
    address public lock = 0xfb691697BDAf1857C748C004cC7dab3d234E062E;
    address public lpGauge = 0xf96Bc096dd1E52dcE4d595B6C4B8c5d2200db1E5;
    uint256 public counter;

    mapping(uint256 index => ISamuraiTiers.Tier tier) public tiers;

    constructor() Ownable(msg.sender) {}

    function addTier(
        string memory name,
        uint256 numOfSamNfts,
        uint256 minLocking,
        uint256 maxLocking,
        uint256 minLPStaking,
        uint256 maxLPStaking,
        uint256 samuraiPoints
    ) external onlyOwner nonReentrant {
        uint256 index = counter + 1;
        tiers[index] =
            ISamuraiTiers.Tier(name, numOfSamNfts, minLocking, maxLocking, minLPStaking, maxLPStaking, samuraiPoints);
        counter++;

        emit ISamuraiTiers.Added(index);
    }

    function removeTier(uint256 tierIndex) external onlyOwner nonReentrant {
        ISamuraiTiers.Tier memory tierCopy = tiers[tierIndex];
        delete tiers[tierIndex];
        counter--;

        emit ISamuraiTiers.Removed(tierCopy);
    }

    function updateTier(
        uint256 tierIndex,
        string memory name,
        uint256 numOfSamNfts,
        uint256 minLocking,
        uint256 maxLocking,
        uint256 minLPStaking,
        uint256 maxLPStaking,
        uint256 samuraiPoints
    ) external onlyOwner nonReentrant {
        tiers[tierIndex] =
            ISamuraiTiers.Tier(name, numOfSamNfts, minLocking, maxLocking, minLPStaking, maxLPStaking, samuraiPoints);
        emit ISamuraiTiers.Updated(tierIndex);
    }

    function getTier(address wallet) public view returns (ISamuraiTiers.Tier memory) {
        console2.log("wallet", wallet);
        // Check SAM NFTs balance
        uint256 nftBalance = ISamNfts(nft).balanceOf(wallet);
        console2.log("nftBalance", nftBalance);

        // Check Sam Lock balance
        ISamLock.LockInfo[] memory lockings = ISamLocks(lock).getLockInfos(wallet);
        uint256 totalLocked;
        for (uint256 i = 0; i < lockings.length; i++) {
            totalLocked += lockings[i].lockedAmount - lockings[i].withdrawnAmount;
        }
        console2.log("totalLocked", totalLocked);

        // Check SAM/WETH gauge balance
        uint256 lpStaked = ISamGaugeLP(lpGauge).balanceOf(wallet);
        console2.log("lpStaked", lpStaked);
        console2.log(" ");

        if (nftBalance >= 1) {
            console2.log("Shogun");
            return getTierByName("Shogun");
        } // returns shogun tier

        // Iterate through tiers to find a matching tier
        for (uint256 i = 1; i <= counter; i++) {
            // start from 1 because tiers mapping starts from 1
            ISamuraiTiers.Tier memory tier = tiers[i];
            if (
                (totalLocked >= tier.minLocking && totalLocked <= tier.maxLocking)
                    || (lpStaked >= tier.minLPStaking && lpStaked <= tier.maxLPStaking)
            ) {
                console2.log(tier.name);
                return tier;
            }
        }

        // If no tier matches, return the default tier (optional)
        return ISamuraiTiers.Tier("", 0, 0, 0, 0, 0, 0); // Replace with your default tier values
    }

    function getTierByName(string memory name) public view returns (ISamuraiTiers.Tier memory) {
        bytes32 nameHash = keccak256(abi.encodePacked(name));

        for (uint256 i = 1; i <= counter; i++) {
            bytes32 tierNameHash = keccak256(abi.encodePacked(tiers[i].name));
            if (nameHash == tierNameHash) return tiers[i];
        }

        return ISamuraiTiers.Tier("", 0, 0, 0, 0, 0, 0);
    }
}
