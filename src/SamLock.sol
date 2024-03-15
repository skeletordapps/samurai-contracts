//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/console.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";
import {console2} from "forge-std/console2.sol";

contract SamLock is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    uint256 public constant MAX_ALLOWED_TO_STAKE = 100_000_000 ether;
    address public immutable sam;

    mapping(address wallet => uint256 amount) public lockings;
    mapping(address wallet => uint256 numberOfPoints) public points;

    event Staked(address indexed wallet, uint256 amount);
    event Withdrawn(address indexed wallet, uint256 amount);

    error SamLock__InsufficientAmount();

    constructor(address _sam) Ownable(msg.sender) {
        sam = _sam;
    }

    function stake(address wallet, uint256 amount) external nonReentrant whenNotPaused {
        if (amount == 0) revert SamLock__InsufficientAmount();

        ERC20(sam).safeTransferFrom(wallet, address(this), amount);
        lockings[wallet] += amount;
        emit Staked(wallet, amount);
    }

    function withdraw(address wallet, uint256 amount) external nonReentrant {
        if (amount == 0) revert SamLock__InsufficientAmount();
        if (amount > lockings[wallet]) revert SamLock__InsufficientAmount();

        lockings[wallet] -= amount;
        emit Withdrawn(wallet, amount);
        ERC20(sam).safeTransfer(wallet, amount);
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
