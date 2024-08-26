// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IParticipator} from "./interfaces/IParticipator.sol";

contract ParticipatorNftOpen is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    address public acceptedToken;
    uint256 public min;
    uint256 public max;
    uint256 public pricePerToken;
    uint256 public maxAllocations;
    uint256 public raised;

    mapping(address wallet => uint256 allocation) public allocations;
    mapping(address wallet => uint256 allocationInUSDC) public allocationsInUSDC;

    constructor(address _acceptedToken, uint256 _min, uint256 _max, uint256 _pricePerToken, uint256 _maxAllocations)
        Ownable(msg.sender)
    {
        require(_acceptedToken != address(0), IParticipator.IParticipator__Invalid("Invalid address"));
        require(_min > 0, IParticipator.IParticipator__Invalid("Min should be higher than 0"));
        require(_max > _min, IParticipator.IParticipator__Invalid("Max should be higher than Min"));
        require(_maxAllocations > 0, IParticipator.IParticipator__Invalid("Total Max should be greater than 0"));

        acceptedToken = _acceptedToken;
        min = _min;
        max = _max;
        pricePerToken = _pricePerToken;
        maxAllocations = _maxAllocations;
    }

    function sendToken(uint256 amountInTokens) external whenNotPaused nonReentrant {
        require(amountInTokens % pricePerToken == 0, IParticipator.IParticipator__Invalid("Invalid amount"));
        uint256 amount = amountInTokens / pricePerToken;
        require(amount >= min, IParticipator.IParticipator__Invalid("Amount too low"));
        require(amount <= max, IParticipator.IParticipator__Invalid("Amount too high"));
        require(
            allocations[msg.sender] + amount <= max,
            IParticipator.IParticipator__Invalid("Exceeds max allocation permitted")
        );

        require(
            raised + amount <= maxAllocations, IParticipator.IParticipator__Invalid("Exceeds max allocations permitted")
        );

        ERC20(acceptedToken).safeTransferFrom(msg.sender, address(this), amountInTokens);

        allocations[msg.sender] += amount;
        allocationsInUSDC[msg.sender] += amountInTokens;
        raised += amount;
        emit IParticipator.Allocated(msg.sender, acceptedToken, amount);
    }

    function withdraw() external onlyOwner {
        uint256 balance = ERC20(acceptedToken).balanceOf(address(this));
        ERC20(acceptedToken).safeTransfer(owner(), balance);
    }

    function updateMinMaxPerWallet(uint256 _min, uint256 _max) external onlyOwner nonReentrant {
        require(_max > _min, IParticipator.IParticipator__Invalid("Max should be higher or equal Min"));
        min = _min;
        max = _max;
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
