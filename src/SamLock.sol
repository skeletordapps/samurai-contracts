//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/console.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";
import {ISamLock} from "./interfaces/ISamLock.sol";

contract SamLock is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    // Define lock periods (in seconds)
    uint256 public constant THREE_MONTHS = 3 * 30 days;
    uint256 public constant SIX_MONTHS = 6 * 30 days;
    uint256 public constant NINE_MONTHS = 9 * 30 days;
    uint256 public constant TWELVE_MONTHS = 12 * 30 days;

    address public immutable sam;
    uint256 public minToLock;
    uint256 public totalLocked;
    uint256 public nextLockIndex;

    mapping(address wallet => ISamLock.LockInfo[]) public lockings;
    mapping(uint256 period => uint256 multiplier) public multipliers;

    constructor(address _sam, uint256 _minToLock) Ownable(msg.sender) {
        // SLK-02S: Inexistent Sanitization of Input Address - OK
        // Added a check to validate the sam address
        if (_sam == address(0)) revert ISamLock.SamLock__InvalidAddress();
        sam = _sam;

        multipliers[THREE_MONTHS] = 1e18;
        multipliers[SIX_MONTHS] = 3e18;
        multipliers[NINE_MONTHS] = 5e18;
        multipliers[TWELVE_MONTHS] = 7e18;

        minToLock = _minToLock;
    }

    /// @notice Lock SAM tokens to earn points based on lock tier and period
    /// @param amount Amount of SAM tokens to be locked
    /// @param lockPeriod Lock period chosen by the user (THREE_MONTHS, SIX_MONTHS, NINE_MONTHS, TWELVE_MONTHS)
    function lock(uint256 amount, uint256 lockPeriod) external nonReentrant whenNotPaused {
        // SLK-04M: Unauthorized Transfer of Funds - OK

        if (amount < minToLock) revert ISamLock.SamLock__InsufficientAmount();
        if (
            lockPeriod != THREE_MONTHS && lockPeriod != SIX_MONTHS && lockPeriod != NINE_MONTHS
                && lockPeriod != TWELVE_MONTHS
        ) revert ISamLock.SamLock__Invalid_Period();

        ERC20(sam).safeTransferFrom(msg.sender, address(this), amount);

        uint256 lockIndex = nextLockIndex;

        ISamLock.LockInfo memory newLock = ISamLock.LockInfo({
            lockIndex: lockIndex,
            lockedAmount: amount,
            withdrawnAmount: 0,
            lockedAt: block.timestamp,
            unlockTime: block.timestamp + lockPeriod,
            lockPeriod: lockPeriod
        });

        lockings[msg.sender].push(newLock);
        totalLocked += amount;
        nextLockIndex++;
        emit ISamLock.Locked(msg.sender, amount, lockIndex);
    }

    /// @notice Withdraw locked SAM tokens and earned points after the lock period ends
    /// @param amount Amount of SAM tokens to withdraw (must be less than or equal to locked amount)
    /// @param lockIndex Index of the specific lock information entry for the user
    function withdraw(uint256 amount, uint256 lockIndex) external nonReentrant {
        // SLK-03M: Unauthorized Release of Locks - OK
        // The wallet param was removed and the msg.sender is being used to avoid transfer of funds

        if (amount == 0) revert ISamLock.SamLock__InsufficientAmount();

        ISamLock.LockInfo storage lockInfo = lockings[msg.sender][lockIndex]; // SLK-01C: Inefficient mapping Lookups - OK
        if (block.timestamp < lockInfo.unlockTime) revert ISamLock.SamLock__Cannot_Unlock_Before_Period();
        if (amount > lockInfo.lockedAmount - lockInfo.withdrawnAmount) revert ISamLock.SamLock__InsufficientAmount();

        lockInfo.withdrawnAmount += amount;
        totalLocked -= amount;
        emit ISamLock.Withdrawn(msg.sender, amount, lockIndex);

        ERC20(sam).safeTransfer(msg.sender, amount);
    }

    /// @notice Pause the contract, preventing further locking actions
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract, allowing locking actions again
    function unpause() external onlyOwner {
        _unpause();
    }

    function updateMinToLock(uint256 _minToLock) external onlyOwner nonReentrant {
        minToLock = _minToLock;
    }

    function updateMultipliers(uint256 multiplier3x, uint256 multiplier6x, uint256 multiplier9x, uint256 multiplier12x)
        external
        onlyOwner
    {
        // SLK-02M: Insufficient Validation of Multipliers - OK
        // The new multipliers must be higher than before to keep consistency, improving also the validation as recommended

        if (
            multiplier3x <= multipliers[THREE_MONTHS] || multiplier6x <= multipliers[SIX_MONTHS]
                || multiplier9x <= multipliers[NINE_MONTHS] || multiplier12x <= multipliers[TWELVE_MONTHS]
        ) {
            revert ISamLock.SamLock__InvalidMultiplier();
        }

        multipliers[THREE_MONTHS] = multiplier3x;
        multipliers[SIX_MONTHS] = multiplier6x;
        multipliers[NINE_MONTHS] = multiplier9x;
        multipliers[TWELVE_MONTHS] = multiplier12x;

        emit ISamLock.MultipliersUpdated(multiplier3x, multiplier6x, multiplier9x, multiplier12x);
    }

    /// @notice Retrieve all lock information entries for a specific user (address)
    /// @param wallet Address of the user
    /// @return lockInfos Array containing the user's lock information entries
    /// @dev Reverts with ISamLock.SamLock__NotFound if there are no lock entries for the user
    function getLockInfos(address wallet) public view returns (ISamLock.LockInfo[] memory) {
        return lockings[wallet];
    }

    /// @notice Calculate the total points earned for a specific lock entry
    /// @param wallet Address of the user
    /// @param lockIndex Index of the lock information entry for the user
    /// @return points Total points earned for the specific lock entry (uint256)
    /// @dev Reverts with ISamLock.SamLock__InvalidLockIndex if the lock index is out of bounds
    function pointsByLock(address wallet, uint256 lockIndex) public view returns (uint256 points) {
        if (lockIndex >= lockings[wallet].length) revert ISamLock.SamLock__InvalidLockIndex();

        ISamLock.LockInfo memory lockInfo = lockings[wallet][lockIndex];

        // SLK-01M: Inexistent Retroactive Application of Multipliers - OK
        // The multiplier is now loading the latest multiplier based in lockPeriod selected by the user
        // enabling fair leverage of multipliers updates for old lockers
        UD60x18 multiplier = ud(multipliers[lockInfo.lockPeriod]);
        UD60x18 maxPointsToEarn = ud(lockInfo.lockedAmount).mul(multiplier);

        if (block.timestamp >= lockInfo.unlockTime) {
            points = maxPointsToEarn.intoUint256();
            return points;
        }

        // SLK-02C: Redundant Conditional - OK
        // The useless condition was removed as recommended
        uint256 elapsedTime = block.timestamp - lockInfo.lockedAt;

        if (elapsedTime > 0) {
            // SLK-01S: Illegible Numeric Value Representation - OK
            // The number was separated by _ as recommended
            UD60x18 oneDay = ud(86_400e18);
            UD60x18 periodInDays = convert(lockInfo.lockPeriod).div(oneDay);
            UD60x18 pointsPerDay = maxPointsToEarn.div(periodInDays);
            UD60x18 elapsedDays = convert(elapsedTime).div(oneDay);

            points = pointsPerDay.mul(elapsedDays).intoUint256();
        }

        return points;
    }
}
