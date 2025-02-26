//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {console} from "forge-std/console.sol";
import {ISamLock} from "./interfaces/ISamLock.sol";
import {ILock} from "./interfaces/ILock.sol";
import {ISamuraiTiers, ISamNftLock, ISamLocks, ISamLocksV2, ISamGaugeLP} from "./interfaces/ISamuraiTiers.sol";

contract SamuraiTiers is Ownable, ReentrancyGuard {
    address public nftLock;
    address public lock;
    address public lockV2;
    address public lpGauge;
    uint256 public counter;

    mapping(uint256 index => ISamuraiTiers.Tier tier) public tiers;

    constructor(address _nftLock, address _lock, address _lockV2, address _lpGauge) Ownable(msg.sender) {
        setSources(_nftLock, _lock, _lockV2, _lpGauge);
    }

    /**
     * @notice Creates a new tier with the specified parameters.
     * @dev Emits an Added event with the tier index.
     * @param name: Name of the tier.
     * @param numOfSamNfts: Minimum number of Sam NFTs required for the tier.
     * @param minLocking: Minimum amount of Sam tokens locked required for the tier.
     * @param maxLocking: Maximum amount of Sam tokens locked allowed for the tier.
     * @param minLPStaking: Minimum amount of Sam/WETH LP tokens staked required for the tier.
     * @param maxLPStaking: Maximum amount of Sam/WETH LP tokens staked allowed for the tier.
     * Returns nothing.
     */
    function addTier(
        string memory name,
        uint256 numOfSamNfts,
        uint256 minLocking,
        uint256 maxLocking,
        uint256 minLPStaking,
        uint256 maxLPStaking
    ) external onlyOwner nonReentrant {
        uint256 index = counter + 1;
        tiers[index] = ISamuraiTiers.Tier(name, numOfSamNfts, minLocking, maxLocking, minLPStaking, maxLPStaking);
        counter++;

        emit ISamuraiTiers.Added(index);
    }

    /**
     * @notice Removes the tier at the specified index.
     * @dev Emits a Removed event with the removed tier information.
     * @param tierIndex: Index of the tier to remove.
     * Returns nothing.
     */
    function removeTier(uint256 tierIndex) external onlyOwner nonReentrant {
        ISamuraiTiers.Tier memory tierCopy = tiers[tierIndex];
        delete tiers[tierIndex];
        counter--;

        emit ISamuraiTiers.Removed(tierCopy);
    }

    /**
     * @notice Updates the information of an existing tier.
     * @dev Emits an Updated event with the updated tier index.
     * @param tierIndex: Index of the tier to update.
     * @param name: New name for the tier.
     * @param numOfSamNfts: New minimum number of Sam NFTs required for the tier.
     * @param minLocking: New minimum amount of Sam tokens locked required for the tier.
     * @param maxLocking: New maximum amount of Sam tokens locked allowed for the tier.
     * @param minLPStaking: New minimum amount of Sam/WETH LP tokens staked required for the tier.
     * @param maxLPStaking: New maximum amount of Sam/WETH LP tokens staked allowed for the tier.
     * Returns nothing.
     */
    function updateTier(
        uint256 tierIndex,
        string memory name,
        uint256 numOfSamNfts,
        uint256 minLocking,
        uint256 maxLocking,
        uint256 minLPStaking,
        uint256 maxLPStaking
    ) external onlyOwner nonReentrant {
        tiers[tierIndex] = ISamuraiTiers.Tier(name, numOfSamNfts, minLocking, maxLocking, minLPStaking, maxLPStaking);
        emit ISamuraiTiers.Updated(tierIndex);
    }

    /**
     * @notice Sets the contract addresses for NFT, lock, and LP gauge sources.
     * @dev Emits a SourcesUpdated event with the new addresses.
     *       This function can only be called by the contract owner and is protected against reentrancy.
     *       It reverts if any of the provided addresses are invalid (zero address).
     * @param _nftLock The address of the Sam NFT Lock contract.
     * @param _lock The address of the Sam Lock contract.
     * @param _lpGauge The address of the Sam/WETH LP gauge contract.
     */
    function setSources(address _nftLock, address _lock, address _lockV2, address _lpGauge)
        public
        onlyOwner
        nonReentrant
    {
        require(_nftLock != address(0) && _lock != address(0) && _lpGauge != address(0), "Invalid address");
        nftLock = _nftLock;
        lock = _lock;
        lockV2 = _lockV2;
        lpGauge = _lpGauge;

        emit ISamuraiTiers.SourcesUpdated(_nftLock, _lock, _lockV2, _lpGauge);
    }

    /**
     * @notice Gets the tier a wallet belongs to based on Sam NFT locks, lockups, and LP staking.
     * @param wallet: Address of the wallet to check.
     * @return tier: The tier information for the wallet.
     */
    function getTier(address wallet) public view returns (ISamuraiTiers.Tier memory) {
        // Check SAM NFTs locked balance
        uint256 nftsLocked = ISamNftLock(nftLock).locksCounter(wallet);

        // Check Sam Lock balance
        ISamLock.LockInfo[] memory lockings = ISamLocks(lock).getLockInfos(wallet);
        uint256 totalLocked;

        for (uint256 i = 0; i < lockings.length; i++) {
            totalLocked += lockings[i].lockedAmount - lockings[i].withdrawnAmount;
        }

        ILock.LockInfo[] memory lockingsV2 = ISamLocksV2(lockV2).locksOf(wallet);
        uint256 totalLockedV2;

        for (uint256 i = 0; i < lockingsV2.length; i++) {
            totalLockedV2 += lockingsV2[i].lockedAmount - lockingsV2[i].withdrawnAmount;
        }

        // Check SAM/WETH gauge balance
        uint256 lpStaked = ISamGaugeLP(lpGauge).balanceOf(wallet);

        if (nftsLocked >= 1) return getTierByName("Shogun"); // returns shogun tier

        // Iterate through tiers to find a matching tier
        for (uint256 i = 1; i <= counter; i++) {
            // start from 1 because tiers mapping starts from 1
            ISamuraiTiers.Tier memory tier = tiers[i];
            if (
                (totalLockedV2 >= tier.minLocking && totalLockedV2 <= tier.maxLocking)
                    || (totalLocked >= tier.minLocking && totalLocked <= tier.maxLocking)
                    || (lpStaked >= tier.minLPStaking && lpStaked <= tier.maxLPStaking)
            ) {
                return tier;
            }
        }

        // If no tier matches, return a blank tier
        return ISamuraiTiers.Tier("", 0, 0, 0, 0, 0);
    }

    /**
     * @notice Gets the tier information by its name.
     * @param name: Name of the tier to get.
     * @return tier: The tier information matching the name.
     */
    function getTierByName(string memory name) public view returns (ISamuraiTiers.Tier memory) {
        bytes32 nameHash = keccak256(abi.encodePacked(name));

        for (uint256 i = 1; i <= counter; i++) {
            bytes32 tierNameHash = keccak256(abi.encodePacked(tiers[i].name));
            if (nameHash == tierNameHash) return tiers[i];
        }

        // If no tier matches, return a blank tier
        return ISamuraiTiers.Tier("", 0, 0, 0, 0, 0);
    }
}
