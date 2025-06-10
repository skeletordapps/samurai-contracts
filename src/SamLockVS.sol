//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {UD60x18, ud} from "@prb/math/src/UD60x18.sol";
import {ILockS} from "./interfaces/ILockS.sol";

// aderyn-ignore-next-line(centralization-risk)
contract SamLockVS is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    uint256 public constant THREE_MONTHS = 3 * 30 days;
    uint256 public constant SIX_MONTHS = 6 * 30 days;
    uint256 public constant NINE_MONTHS = 9 * 30 days;
    uint256 public constant TWELVE_MONTHS = 12 * 30 days;

    uint256 public immutable maxRequestsPerBatch;
    address public immutable sam;
    uint256 public minToLock;
    uint256 public totalLocked;
    uint256 public totalWithdrawn;
    uint256 public totalPointsPending;
    uint256 public totalPointsFulfilled;
    uint256 public lastBatchId;

    mapping(address wallet => ILockS.LockInfo[]) lockings;
    mapping(uint256 period => uint256 multiplier) public multipliers;
    mapping(address wallet => mapping(uint256 lockIndex => ILockS.Request request)) public requests;
    mapping(address wallet => uint256 length) public numOfRequests;
    mapping(uint256 batchId => ILockS.Request[] requests) public batchesToRequests;
    mapping(uint256 batchId => bool isFulfilled) public batchIsFulfilled;

    constructor(uint256 _maxRequestsPerBatch, address _sam, uint256 _minToLock) Ownable(msg.sender) {
        require(_maxRequestsPerBatch > 0, ILockS.ILock__Error("Max requests cannot be 0"));
        require(_sam != address(0), ILockS.ILock__Error("Invalid address"));
        maxRequestsPerBatch = _maxRequestsPerBatch;
        sam = _sam;

        multipliers[THREE_MONTHS] = 1e18;
        multipliers[SIX_MONTHS] = 3e18;
        multipliers[NINE_MONTHS] = 5e18;
        multipliers[TWELVE_MONTHS] = 7e18;

        minToLock = _minToLock;
    }

    /**
     * @notice Lock SAM tokens to earn Samurai Points based on chosen lock period
     * @param amount Amount of SAM tokens to be locked
     * @param lockPeriod Lock period chosen by the user (THREE_MONTHS, SIX_MONTHS, NINE_MONTHS, TWELVE_MONTHS)
     */
    function lock(uint256 amount, uint256 lockPeriod) external nonReentrant whenNotPaused {
        require(msg.sender != address(0), ILockS.ILock__Error("Invalid address"));
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
     * @notice Withdraw unlocked SAM tokens after the lock period ends
     * @param amount Amount of SAM tokens to withdraw (must be less than or equal to locked amount)
     * @param lockIndex Index of the specific lock information entry for the user
     */
    function withdraw(uint256 amount, uint256 lockIndex) external nonReentrant {
        require(msg.sender != address(0), ILockS.ILock__Error("Invalid address"));
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
     * @notice Request Samurai Points for a specific lock
     * @param lockIndex Index of the lock to request points for
     * @dev Creates a new request for Samurai Points if the lock is valid and has not already been claimed or requested.
     *      Can only be called when the contract is not paused.
     *      Emits a PointsRequested event.
     */
    function request(uint256 lockIndex) external nonReentrant whenNotPaused {
        require(lockings[msg.sender].length > 0, ILockS.ILock__Error("You have no locks"));
        require(lockIndex < lockings[msg.sender].length, ILockS.ILock__Error("Invalid lock index"));

        ILockS.Request memory _request = requests[msg.sender][lockIndex];
        require(!_request.isFulfilled, ILockS.ILock__Error("Request already fulfilled"));
        require(_request.amount == 0, ILockS.ILock__Error("Already requested"));

        uint256 pointsToRequest = previewClaimablePoints(msg.sender, lockIndex);
        require(pointsToRequest > 0, ILockS.ILock__Error("No points to request"));

        uint256 batchId = getBatch(true);

        // Creates a new request
        ILockS.Request memory newRequest = ILockS.Request({
            wallet: msg.sender,
            amount: pointsToRequest,
            lockIndex: lockIndex,
            batchId: batchId,
            isFulfilled: false
        });

        requests[msg.sender][lockIndex] = newRequest; // assing new request to wallet and lockIndex
        batchesToRequests[batchId].push(newRequest); // include new request in the current batch

        numOfRequests[msg.sender]++;
        totalPointsPending += pointsToRequest;

        emit ILockS.PointsRequested(msg.sender, pointsToRequest);
    }

    /**
     * @notice Fulfill requests for samurai points
     * @param batchId Id of a batch of requests
     * @dev This function can only be called by the contract owner.
     *      It updates the lock information for each request and marks the request as fulfilled.
     *      Emits a RequestFulfilled event with the fulfilled requests.
     *      aderyn-ignore-next-line(centralization-risk)
     */
    function fulfill(uint256 batchId) external nonReentrant onlyOwner {
        require(batchId <= lastBatchId, ILockS.ILock__Error("Invalid batch request ID"));
        require(!batchIsFulfilled[batchId], ILockS.ILock__Error("Request already fulfilled"));

        ILockS.Request[] memory _requests = batchesToRequests[batchId];
        require(_requests.length > 0, ILockS.ILock__Error("No requests to fulfill"));

        // aderyn-ignore-next-line(costly-loop)
        for (uint256 i = 0; i < _requests.length; i++) {
            ILockS.Request memory _request = _requests[i];
            require(_request.wallet != address(0), ILockS.ILock__Error("Invalid address"));
            require(!_request.isFulfilled, ILockS.ILock__Error("Already fulfilled"));
            require(_request.amount > 0, ILockS.ILock__Error("Invalid amount"));

            ILockS.LockInfo storage lockInfo = lockings[_request.wallet][_request.lockIndex];

            require(lockInfo.lockedAmount > 0, ILockS.ILock__Error("No locks found"));
            require(lockInfo.claimedPoints == 0, ILockS.ILock__Error("Already fulfilled"));

            lockInfo.claimedPoints = _request.amount;
            totalPointsPending -= _request.amount;
            totalPointsFulfilled += _request.amount;

            requests[_request.wallet][_request.lockIndex].isFulfilled = true;
            numOfRequests[_request.wallet]--;
        }

        batchIsFulfilled[batchId] = true; // Mark batch as fulfilled

        emit ILockS.RequestFulfilled(batchId);
    }

    /// @notice Pause contract functionality (locking, requesting points)
    /// aderyn-ignore-next-line(centralization-risk)
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Resume contract functionality after pause
    /// aderyn-ignore-next-line(centralization-risk)
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Updates the minimum amount of SAM tokens required to lock
     * @param _minToLock New minimum lock amount
     * @dev Only callable by the contract owner
     * aderyn-ignore-next-line(centralization-risk)
     */
    function updateMinToLock(uint256 _minToLock) external nonReentrant onlyOwner {
        minToLock = _minToLock;
        emit ILockS.MinToLockUpdated(_minToLock);
    }

    /**
     * @notice Updates the multipliers used to calculate Samurai Points for each lock period
     * @param multiplier3x New multiplier for 3-month lock
     * @param multiplier6x New multiplier for 6-month lock
     * @param multiplier9x New multiplier for 9-month lock
     * @param multiplier12x New multiplier for 12-month lock
     * @dev Reverts unless at least one new multiplier is greater than its current value.
     *      Only callable by the contract owner.
     */
    function updateMultipliers(uint256 multiplier3x, uint256 multiplier6x, uint256 multiplier9x, uint256 multiplier12x)
        external
        nonReentrant // aderyn-ignore-next-line(centralization-risk)
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

    // aderyn-ignore-next-line(centralization-risk)
    function emergencyWithdraw() external nonReentrant whenPaused onlyOwner {
        uint256 balance = ERC20(sam).balanceOf(address(this));
        ERC20(sam).safeTransfer(owner(), balance);
        emit ILockS.EmergencyWithdrawn(balance);
    }

    /**
     * @notice Retrieve all lock information entries for a specific user (address)
     * @param wallet Address of the user
     * @return lockInfos Array containing the user's lock information entries
     */
    function locksOf(address wallet) external view returns (ILockS.LockInfo[] memory) {
        return lockings[wallet];
    }

    /**
     * @notice Retrieve all requests included in a specific batch
     * @param _lastBatchId ID of the batch
     * @return requests Array of requests included in the batch
     */
    function requestsOf(uint256 _lastBatchId) external view returns (ILockS.Request[] memory) {
        return batchesToRequests[_lastBatchId];
    }

    /**
     * @notice Calculate the amount of claimable Samurai Points for a specific lock
     * @param wallet Wallet address
     * @param lockIndex Index of the lock
     * @return claimablePoints Amount of claimable Samurai Points
     * @dev Returns 0 if the lock is already claimed, already requested, or invalid
     */
    function previewClaimablePoints(address wallet, uint256 lockIndex) public view returns (uint256) {
        ILockS.LockInfo[] memory walletLocks = lockings[wallet];

        if (walletLocks.length == 0) return 0;
        if (walletLocks.length <= lockIndex) return 0;

        ILockS.LockInfo memory lockInfo = walletLocks[lockIndex];
        ILockS.Request memory _request = requests[wallet][lockIndex];

        if (lockInfo.claimedPoints > 0 || _request.isFulfilled) return 0; // fulfilled
        if (_request.amount > 0) return 0; // already requested

        UD60x18 multiplier = ud(multipliers[lockInfo.lockPeriod]);
        UD60x18 maxPointsToEarn = ud(lockInfo.lockedAmount).mul(multiplier);

        return maxPointsToEarn.intoUint256();
    }

    /**
     * @notice Determines the batch ID for a new request
     * @param newPosition Whether a new request is being added
     * @dev Increments the batch ID if the current batch is full or already fulfilled
     */
    function getBatch(bool newPosition) private returns (uint256) {
        uint256 batchId = lastBatchId;

        if (newPosition) {
            bool limitReached = batchesToRequests[batchId].length >= maxRequestsPerBatch;
            bool alreadyFulfilled = batchIsFulfilled[batchId];

            if (limitReached || alreadyFulfilled) {
                batchId = ++lastBatchId;
            }
        }

        return batchId;
    }
}
