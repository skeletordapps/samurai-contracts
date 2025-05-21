//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UD60x18, ud} from "@prb/math/src/UD60x18.sol";
import {ILockS} from "./interfaces/ILockS.sol";
import {console} from "forge-std/console.sol";

contract SamLockVS is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    uint256 public constant THREE_MONTHS = 3 * 30 days;
    uint256 public constant SIX_MONTHS = 6 * 30 days;
    uint256 public constant NINE_MONTHS = 9 * 30 days;
    uint256 public constant TWELVE_MONTHS = 12 * 30 days;

    uint256 public constant CLAIM_DELAY_PERIOD = 5 minutes; // 5 minutes

    address public immutable sam;
    uint256 public minToLock;
    uint256 public totalLocked;
    uint256 public totalWithdrawn;
    uint256 public totalPointsPending;
    uint256 public totalPointsFulfilled;

    mapping(address wallet => ILockS.LockInfo[]) lockings;
    mapping(uint256 period => uint256 multiplier) public multipliers;
    mapping(address wallet => mapping(uint256 lockIndex => ILockS.Request request)) public requests;
    mapping(address wallet => uint256 length) public numOfRequests;

    constructor(address _sam, uint256 _minToLock) Ownable(msg.sender) {
        require(_sam != address(0), ILockS.ILock__Error("Invalid address"));
        sam = _sam;

        multipliers[THREE_MONTHS] = 1e18;
        multipliers[SIX_MONTHS] = 3e18;
        multipliers[NINE_MONTHS] = 5e18;
        multipliers[TWELVE_MONTHS] = 7e18;

        minToLock = _minToLock;
    }

    /**
     * @notice Lock SAM tokens to earn points based on lock tier and period
     * @param amount Amount of SAM tokens to be locked
     * @param lockPeriod Lock period chosen by the user (THREE_MONTHS, SIX_MONTHS, NINE_MONTHS, TWELVE_MONTHS)
     */
    function lock(uint256 amount, uint256 lockPeriod) external nonReentrant whenNotPaused {
        require(amount >= minToLock, ILockS.ILock__Error("Insufficient amount"));
        require(
            lockPeriod == THREE_MONTHS || lockPeriod == SIX_MONTHS || lockPeriod == NINE_MONTHS
                || lockPeriod == TWELVE_MONTHS,
            ILockS.ILock__Error("Invalid period")
        );

        ERC20(sam).safeTransferFrom(msg.sender, address(this), amount);

        ILockS.LockInfo memory newLock = ILockS.LockInfo({
            lockedAmount: amount,
            withdrawnAmount: 0,
            lockedAt: block.timestamp,
            unlockTime: block.timestamp + lockPeriod,
            lockPeriod: lockPeriod,
            claimedPoints: 0
        });

        lockings[msg.sender].push(newLock);
        totalLocked += amount;
        emit ILockS.Locked(msg.sender, amount);
    }

    /**
     * @notice Withdraw locked SAM tokens and earned points after the lock period ends
     * @param amount Amount of SAM tokens to withdraw (must be less than or equal to locked amount)
     * @param lockIndex Index of the specific lock information entry for the user
     */
    function withdraw(uint256 amount, uint256 lockIndex) external nonReentrant {
        require(amount > 0, ILockS.ILock__Error("Insufficient amount"));

        ILockS.LockInfo storage lockInfo = lockings[msg.sender][lockIndex];

        require(block.timestamp >= lockInfo.unlockTime, ILockS.ILock__Error("Cannot unlock before period"));
        require(amount <= lockInfo.lockedAmount - lockInfo.withdrawnAmount, ILockS.ILock__Error("Insufficient amount"));

        lockInfo.withdrawnAmount += amount;
        totalWithdrawn += amount;
        emit ILockS.Withdrawn(msg.sender, amount, lockIndex);

        ERC20(sam).safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Request to claim samurai points for a specific lock
     * @dev This function allows users to request samurai points for their locked tokens.
     *      If there are claimable points, it creates a request for those points and updates the user's request count.
     *      The total points pending is also updated.
     *      Emits a PointsRequested event with the user's address and the total points requested.
     *      This function can only be called when the contract is not paused.
     *      This function can only be called by the user who owns the locks.
     *      This function can only be called if the user has not already requested points for the locks.
     *      This function can only be called if the user has claimable points for the locks.
     *      This function can only be called if the user has at least one lock.
     *      This function can only be called if the user has not already requested points for the lock.
     *      This function can only be called if the lock index is valid.
     */
    function requestPointsFor(uint256 lockIndex) external nonReentrant whenNotPaused {
        ILockS.LockInfo[] memory walletLocks = lockings[msg.sender];
        require(walletLocks.length > 0, ILockS.ILock__Error("You have no locks"));
        require(lockIndex < walletLocks.length, ILockS.ILock__Error("Invalid lock index"));

        ILockS.Request memory request = requests[msg.sender][lockIndex];
        require(!request.isFulfilled, ILockS.ILock__Error("Request already fulfilled"));
        require(request.amount == 0, ILockS.ILock__Error("Already requested"));

        uint256 pointsToRequest = previewClaimablePoints(msg.sender, lockIndex);
        require(pointsToRequest > 0, ILockS.ILock__Error("No points to request"));

        requests[msg.sender][lockIndex] =
            ILockS.Request({wallet: msg.sender, amount: pointsToRequest, lockIndex: lockIndex, isFulfilled: false});

        numOfRequests[msg.sender]++;
        totalPointsPending += pointsToRequest;

        emit ILockS.PointsRequested(msg.sender, pointsToRequest);
    }

    /**
     * @notice Fulfill requests for samurai points
     * @param _requests Array of requests to be fulfilled
     * @dev This function can only be called by the contract owner.
     *      It requires that the requests array is not empty and that each request is valid.
     *      It updates the lock information for each request and marks the request as fulfilled.
     *      Emits a RequestFulfilled event with the fulfilled requests.
     */
    function fulfillRequests(ILockS.Request[] memory _requests) external nonReentrant onlyOwner {
        require(_requests.length > 0, ILockS.ILock__Error("No requests found"));

        for (uint256 i = 0; i < _requests.length; i++) {
            ILockS.Request memory request = _requests[i];
            require(request.wallet != address(0), ILockS.ILock__Error("Invalid address"));
            require(!request.isFulfilled, ILockS.ILock__Error("Already fulfilled"));
            require(request.amount > 0, ILockS.ILock__Error("Invalid amount"));

            ILockS.LockInfo storage lockInfo = lockings[request.wallet][request.lockIndex];

            require(lockInfo.lockedAmount > 0, ILockS.ILock__Error("No locks found"));
            require(lockInfo.claimedPoints == 0, ILockS.ILock__Error("Already fulfilled"));

            lockInfo.claimedPoints = request.amount;
            totalPointsPending -= request.amount;
            totalPointsFulfilled += request.amount;

            requests[request.wallet][request.lockIndex].isFulfilled = true;
        }

        emit ILockS.RequestFulfilled(_requests);
    }

    /// @notice Pause the contract, preventing further locking actions
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract, allowing locking actions again
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Owner can update minToLock config
     * @param _minToLock value to be updated
     * @dev This function can only be called by the contract owner.
     */
    function updateMinToLock(uint256 _minToLock) external onlyOwner nonReentrant {
        minToLock = _minToLock;
    }

    /**
     * @notice This function updates the multipliers used to calculate lockup rewards for different lockup durations (3, 6, 9, and 12 months).
     * @param multiplier3x The new multiplier for the 3-month lockup.
     * @param multiplier6x The new multiplier for the 6-month lockup.
     * @param multiplier9x The new multiplier for the 9-month lockup.
     * @param multiplier12x The new multiplier for the 12-month lockup.
     * @dev This function can only be called by the contract owner. It reverts if any of the new multipliers are less than to the corresponding stored multiplier.
     */
    function updateMultipliers(uint256 multiplier3x, uint256 multiplier6x, uint256 multiplier9x, uint256 multiplier12x)
        external
        onlyOwner
    {
        require(
            multiplier3x > multipliers[THREE_MONTHS] || multiplier6x > multipliers[SIX_MONTHS]
                || multiplier9x > multipliers[NINE_MONTHS] || multiplier12x > multipliers[TWELVE_MONTHS],
            ILockS.ILock__Error("Invalid multiplier")
        );

        multipliers[THREE_MONTHS] = multiplier3x;
        multipliers[SIX_MONTHS] = multiplier6x;
        multipliers[NINE_MONTHS] = multiplier9x;
        multipliers[TWELVE_MONTHS] = multiplier12x;

        emit ILockS.MultipliersUpdated(multiplier3x, multiplier6x, multiplier9x, multiplier12x);
    }

    /**
     * @notice Retrieve all lock information entries for a specific user (address)
     * @param wallet Address of the user
     * @return lockInfos Array containing the user's lock information entries
     */
    function locksOf(address wallet) public view returns (ILockS.LockInfo[] memory) {
        return lockings[wallet];
    }

    /**
     * @notice Previews the claimable points for a given wallet and lockIndex.
     * @param wallet The wallet address to calculate claimable tokens for.
     * @param lockIndex The index of a specific lock.
     * @return claimablePoints The total amount of claimable points for the wallet.
     * @dev Calculates the total amount of Samurai Points tokens for specific stake.
     *      - Reverts with ILPStaking__Error if the wallet has no stakes.
     *      - Reverts with ILPStaking__Error if the stake index is out of bounds.
     *      - Calculates the total points for the stake.
     *      - Returns the total points for the stake.
     */
    function previewClaimablePoints(address wallet, uint256 lockIndex) public view returns (uint256) {
        ILockS.LockInfo[] memory walletLocks = lockings[wallet];

        if (walletLocks.length == 0) return 0;
        if (walletLocks.length <= lockIndex) return 0;

        ILockS.LockInfo memory lockInfo = walletLocks[lockIndex];
        ILockS.Request memory request = requests[wallet][lockIndex];

        if (lockInfo.claimedPoints > 0 || request.isFulfilled) return 0; // fulfilled
        if (request.amount > 0) return 0; // already requested

        UD60x18 multiplier = ud(multipliers[lockInfo.lockPeriod]);
        UD60x18 maxPointsToEarn = ud(lockInfo.lockedAmount).mul(multiplier);

        return maxPointsToEarn.intoUint256();
    }
}
