// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPoints} from "./interfaces/IPoints.sol";
import {ILock} from "./interfaces/ILock.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";
import {console} from "forge-std/console.sol";

contract MissingPoints is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    IPoints public immutable iPoints;
    ILock public immutable iLock;

    mapping(address account => uint256 claimed) public claims;

    constructor(address _points, address _lockV2) Ownable(msg.sender) {
        require(_points != address(0), "Invalid points address");
        require(_lockV2 != address(0), "Invalid lock address");

        iPoints = IPoints(_points);
        iLock = ILock(_lockV2);
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

    function claim() external nonReentrant whenNotPaused {
        require(claims[msg.sender] == 0, "Already claimed");
        uint256 points = calculate(msg.sender);
        require(points > 0, "No points to claim");

        claims[msg.sender] += points;
        iPoints.mint(msg.sender, points);
    }

    function calculate(address wallet) public returns (uint256) {
        uint256 points = 0;
        if (claims[wallet] > 0) return points; // return 0 if already claimed

        ILock.LockInfo[] memory locks = iLock.locksOf(wallet);
        for (uint256 i = 0; i < locks.length; i++) {
            uint256 claimable = iLock.previewClaimablePoints(wallet, i);
            uint256 claimed = locks[i].claimedPoints;

            uint256 amountToCheck = claimed > 0 ? claimed : claimable;
            if (amountToCheck == 0) continue;

            points += _calculate(wallet, locks[i].claimedPoints);
        }
        return points;
    }

    function _calculate(address wallet, uint256 totalPoints) private returns (uint256) {
        uint256 points = 0;
        uint256 boost = iPoints.boostOf(wallet);

        if (boost > 0) points = ud(totalPoints).mul(ud(boost)).intoUint256();

        return points;
    }
}
