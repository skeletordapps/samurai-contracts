// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/console.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IParticipator} from "./interfaces/IParticipator.sol";

contract Participator is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    address[] public acceptedTokens;
    uint256 public min;
    uint256 public max;
    uint256 public maxAllocations;
    uint256 public raised;
    bool public isPublic;

    mapping(address wallet => uint256 allocation) public allocations;
    mapping(address wallet => bool isWhitelisted) public whitelist;
    mapping(address wallet => bool isBlacklisted) public blacklist;

    constructor(address[] memory _acceptedTokens, uint256 _min, uint256 _max, uint256 _maxAllocations)
        Ownable(msg.sender)
    {
        acceptedTokens = new address[](_acceptedTokens.length);
        for (uint256 i = 0; i < _acceptedTokens.length; i++) {
            if (_acceptedTokens[i] == address(0)) revert IParticipator.IParticipator__Invalid("Invalid Token");
            acceptedTokens[i] = _acceptedTokens[i];
        }

        if (_max <= _min) revert IParticipator.IParticipator__Invalid("Max should be higher than Min");
        if (_maxAllocations == 0) revert IParticipator.IParticipator__Invalid("Total Max should be greater than 0");

        min = _min;
        max = _max;
        maxAllocations = _maxAllocations;
    }

    function sendToken(address wallet, address tokenAddress, uint256 amount) external whenNotPaused nonReentrant {
        if (!whitelist[wallet] && !isPublic) revert IParticipator.IParticipator__Unauthorized("Wallet not allowed");

        if (tokenAddress == address(0)) revert IParticipator.IParticipator__Invalid("Invalid Token");
        if (amount < min) revert IParticipator.IParticipator__Invalid("Amount too low");
        if (amount > max) revert IParticipator.IParticipator__Invalid("Amount too high");
        if (allocations[wallet] + amount > max) {
            revert IParticipator.IParticipator__Invalid("Exceeds max allocation permitted");
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
        allocations[wallet] += amount;
        raised += amount;
        emit IParticipator.Allocated(wallet, tokenAddress, amount);

        ERC20(tokenAddress).safeTransferFrom(wallet, address(this), amount);
    }

    function withdraw() external onlyOwner {
        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            uint256 balance = ERC20(acceptedTokens[i]).balanceOf(address(this));
            ERC20(acceptedTokens[i]).safeTransfer(owner(), balance);
        }
    }

    function addBatchToWhitelist(address[] calldata wallets) external onlyOwner nonReentrant {
        for (uint256 i = 0; i < wallets.length; i++) {
            address wallet = wallets[i];

            if (!whitelist[wallet]) {
                whitelist[wallet] = true;
            }
        }

        emit IParticipator.Whitelisted(wallets);
    }

    function makePublic() external onlyOwner nonReentrant {
        isPublic = true;

        emit IParticipator.PublicAllowed();
    }

    function updateMinMaxPerWallet(uint256 _min, uint256 _max) external onlyOwner nonReentrant {
        if (_max <= _min) revert IParticipator.IParticipator__Invalid("Max should be higher than Min");
        min = _min;
        max = _max;
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
