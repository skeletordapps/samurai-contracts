// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console2} from "forge-std/console2.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IParticipator} from "./interfaces/IParticipator.sol";

contract ParticipatorNFT_ETH is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    uint256 public minA;
    uint256 public maxA;
    uint256 public minB;
    uint256 public maxB;
    uint256 public minPublic;
    uint256 public maxPublic;
    uint256 public pricePerToken;
    uint256 public maxAllocations;
    uint256 public maxAllocationsOfETH;
    uint256 public raised;
    uint256 public raisedInETH;
    bool public isPublic;

    mapping(address wallet => uint256 allocation) public allocations;
    mapping(address wallet => uint256 allocationInETH) public allocationsInETH;
    mapping(address wallet => bool isWhitelisted) public whitelistA;
    mapping(address wallet => bool isWhitelisted) public whitelistB;

    constructor(
        uint256 _minA,
        uint256 _maxA,
        uint256 _minB,
        uint256 _maxB,
        uint256 _minPublic,
        uint256 _maxPublic,
        uint256 _pricePerToken,
        uint256 _maxAllocations
    ) Ownable(msg.sender) {
        if (_maxA < _minA) revert IParticipator.IParticipator__Invalid("Max should be higher than Min");
        if (_maxB < _minB) revert IParticipator.IParticipator__Invalid("Max should be higher than Min");
        if (_maxPublic < _minPublic) revert IParticipator.IParticipator__Invalid("Max should be higher than Min");
        if (_maxAllocations == 0) revert IParticipator.IParticipator__Invalid("Total Max should be greater than 0");

        minA = _minA;
        maxA = _maxA;
        minB = _minB;
        maxB = _maxB;
        minPublic = _minPublic;
        maxPublic = _maxPublic;
        pricePerToken = _pricePerToken;
        maxAllocations = _maxAllocations;
        maxAllocationsOfETH = _maxAllocations * _pricePerToken;
    }

    function participate(address wallet, uint256 numOfTokens) external payable whenNotPaused nonReentrant {
        if (!whitelistA[wallet] && !whitelistB[wallet] && !isPublic) {
            revert IParticipator.IParticipator__Unauthorized("Wallet not allowed");
        }

        if (isPublic) {
            if (numOfTokens < minPublic) revert IParticipator.IParticipator__Invalid("Amount too low");
            if (numOfTokens > maxPublic) revert IParticipator.IParticipator__Invalid("Amount too high");
            if (allocations[wallet] + numOfTokens > maxPublic) {
                revert IParticipator.IParticipator__Invalid("Exceeds max allocation permitted");
            }
        } else if (whitelistA[wallet]) {
            if (numOfTokens < minA) revert IParticipator.IParticipator__Invalid("Amount too low");
            if (numOfTokens > maxA) revert IParticipator.IParticipator__Invalid("Amount too high");
            if (allocations[wallet] + numOfTokens > maxA) {
                revert IParticipator.IParticipator__Invalid("Exceeds max allocation permitted");
            }
        } else if (whitelistB[wallet]) {
            if (numOfTokens < minB) revert IParticipator.IParticipator__Invalid("Amount too low");
            if (numOfTokens > maxB) revert IParticipator.IParticipator__Invalid("Amount too high");
            if (allocations[wallet] + numOfTokens > maxB) {
                revert IParticipator.IParticipator__Invalid("Exceeds max allocation permitted");
            }
        }

        if (raised + numOfTokens > maxAllocations) {
            revert IParticipator.IParticipator__Invalid("Exceeds max allocations permitted");
        }

        uint256 amountInETH = numOfTokens * pricePerToken;

        // Check if received ETH is sufficient
        if (msg.value < amountInETH) revert IParticipator.IParticipator__Invalid("Insufficient ETH sent");

        // Refund excess ETH if any
        if (msg.value > amountInETH) {
            payable(wallet).transfer(msg.value - amountInETH);
        }

        allocations[wallet] += numOfTokens;
        raised += numOfTokens;

        allocationsInETH[wallet] += amountInETH;
        raisedInETH += amountInETH;

        emit IParticipator.Allocated(wallet, address(0), numOfTokens);
    }

    function withdraw() external onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function addBatchToWhitelist(address[] calldata wallets, uint256 whitelistIndex) external onlyOwner nonReentrant {
        for (uint256 i = 0; i < wallets.length; i++) {
            address wallet = wallets[i];

            if (whitelistIndex == 0) {
                if (!whitelistA[wallet]) {
                    whitelistA[wallet] = true;
                }
            } else if (whitelistIndex == 1) {
                if (!whitelistB[wallet]) {
                    whitelistB[wallet] = true;
                }
            }
        }

        emit IParticipator.Whitelisted(wallets);
    }

    function makePublic() external onlyOwner nonReentrant {
        isPublic = true;

        emit IParticipator.PublicAllowed();
    }

    function updateAMinMaxPerWallet(uint256 _min, uint256 _max) external onlyOwner nonReentrant {
        if (_max < _min) revert IParticipator.IParticipator__Invalid("Max should be higher or equal Min");
        minA = _min;
        maxA = _max;
    }

    function updateBMinMaxPerWallet(uint256 _min, uint256 _max) external onlyOwner nonReentrant {
        if (_max < _min) revert IParticipator.IParticipator__Invalid("Max should be higher or equal Min");
        minB = _min;
        maxB = _max;
    }

    function updatePublicMinMaxPerWallet(uint256 _min, uint256 _max) external onlyOwner nonReentrant {
        if (_max < _min) revert IParticipator.IParticipator__Invalid("Max should be higher or equal Min");
        minPublic = _min;
        maxPublic = _max;
    }

    function updatePricePerToken(uint256 _pricePerToken) external onlyOwner nonReentrant {
        pricePerToken = _pricePerToken;
    }

    /**
     * @dev Pauses all token transfers.
     * Can only be called by the contract owner.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses token transfers.
     * Can only be called by the contract owner.
     */
    function unpause() public onlyOwner {
        _unpause();
    }
}
