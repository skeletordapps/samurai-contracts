// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/console.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IParticipator} from "./interfaces/IParticipator.sol";

contract ParticipatorNFT is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    address[] public acceptedTokens;
    uint256 public minA;
    uint256 public maxA;
    uint256 public minB;
    uint256 public maxB;
    uint256 public minPublic;
    uint256 public maxPublic;
    uint256 public pricePerToken;
    uint256 public maxAllocations;
    uint256 public maxAllocationsOfTokensPermitted;
    uint256 public raised;
    uint256 public raisedInTokensPermitted;
    bool public isPublic;

    mapping(address wallet => uint256 allocation) public allocations;
    mapping(address wallet => uint256 allocationInUSDC) public allocationsInUSDC;
    mapping(address wallet => bool isWhitelisted) public whitelistA;
    mapping(address wallet => bool isWhitelisted) public whitelistB;

    constructor(
        address[] memory _acceptedTokens,
        uint256 _minA,
        uint256 _maxA,
        uint256 _minB,
        uint256 _maxB,
        uint256 _minPublic,
        uint256 _maxPublic,
        uint256 _pricePerToken,
        uint256 _maxAllocations
    ) Ownable(msg.sender) {
        acceptedTokens = new address[](_acceptedTokens.length);
        for (uint256 i = 0; i < _acceptedTokens.length; i++) {
            if (_acceptedTokens[i] == address(0)) revert IParticipator.IParticipator__Invalid("Invalid Token");
            acceptedTokens[i] = _acceptedTokens[i];
        }

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
        maxAllocationsOfTokensPermitted = _maxAllocations * _pricePerToken;
    }

    function sendToken(address wallet, address tokenAddress, uint256 amountInTokens)
        external
        whenNotPaused
        nonReentrant
    {
        if (!whitelistA[wallet] && !whitelistB[wallet] && !isPublic) {
            revert IParticipator.IParticipator__Unauthorized("Wallet not allowed");
        }

        if (tokenAddress == address(0)) revert IParticipator.IParticipator__Invalid("Invalid Token");

        uint256 amount = amountInTokens / pricePerToken;

        if (isPublic) {
            if (amount < minPublic) revert IParticipator.IParticipator__Invalid("Amount too low");
            if (amount > maxPublic) revert IParticipator.IParticipator__Invalid("Amount too high");
            if (allocations[wallet] + amount > maxPublic) {
                revert IParticipator.IParticipator__Invalid("Exceeds max allocation permitted");
            }
        } else if (whitelistA[wallet]) {
            if (amount < minA) revert IParticipator.IParticipator__Invalid("Amount too low");
            if (amount > maxA) revert IParticipator.IParticipator__Invalid("Amount too high");
            if (allocations[wallet] + amount > maxA) {
                revert IParticipator.IParticipator__Invalid("Exceeds max allocation permitted");
            }
        } else if (whitelistB[wallet]) {
            if (amount < minB) revert IParticipator.IParticipator__Invalid("Amount too low");
            if (amount > maxB) revert IParticipator.IParticipator__Invalid("Amount too high");
            if (allocations[wallet] + amount > maxB) {
                revert IParticipator.IParticipator__Invalid("Exceeds max allocation permitted");
            }
        }

        if (raised + amount > maxAllocations) {
            revert IParticipator.IParticipator__Invalid("Exceeds max allocations permitted");
        }

        bool accepted;

        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            if (tokenAddress == acceptedTokens[i]) {
                accepted = true;
                break;
            }
        }

        if (!accepted) revert IParticipator.IParticipator__Invalid("Token not accepted");

        ERC20(tokenAddress).safeTransferFrom(wallet, address(this), amountInTokens);

        allocations[wallet] += amount;
        raised += amount;

        allocationsInUSDC[wallet] += amountInTokens;
        raisedInTokensPermitted += amountInTokens;

        emit IParticipator.Allocated(wallet, tokenAddress, amount);
    }

    function withdraw() external onlyOwner {
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            uint256 balance = ERC20(acceptedTokens[i]).balanceOf(address(this));
            ERC20(acceptedTokens[i]).safeTransfer(owner(), balance);
        }
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
