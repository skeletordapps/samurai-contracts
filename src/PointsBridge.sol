//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ILockS} from "./interfaces/ILockS.sol";
import {IPoints} from "./interfaces/IPoints.sol";

// aderyn-ignore-next-line(centralization-risk)
contract PointsBridge is Ownable, Pausable, ReentrancyGuard {
    IPoints public immutable points;
    uint256 public immutable maxRequestsPerBatch;
    uint256 public currentBatchId;
    uint256 public fulfillmentsCounter;

    mapping(uint256 fromChainId => mapping(uint256 batchId => ILockS.Request[])) public batchesToRequests;
    mapping(uint256 fromChainId => mapping(uint256 batchId => bool isFulfilled)) public batchIsFulfilled;

    event PointsFulfilled(uint256 indexed chainId, uint256 batchId, uint256 amount);

    constructor(address _points, uint256 _maxRequestsPerBatch) Ownable(msg.sender) {
        require(_points != address(0), "Invalid address");
        require(_maxRequestsPerBatch > 0, "Cannot be 0");
        points = IPoints(_points);
        maxRequestsPerBatch = _maxRequestsPerBatch;
    }

    /// @notice Pause the contract, preventing further locking actions
    /// aderyn-ignore-next-line(centralization-risk)
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract, allowing locking actions again
    /// aderyn-ignore-next-line(centralization-risk)
    function unpause() external onlyOwner {
        _unpause();
    }

    function fulfill(uint256 fromChainId, uint256 batchId, ILockS.Request[] memory requests)
        external
        nonReentrant
        whenNotPaused // aderyn-ignore-next-line(centralization-risk)
        onlyOwner
    {
        require(fromChainId != 0, "Invalid chain ID");
        require(requests.length > 0, "No requests provided");
        require(requests.length <= maxRequestsPerBatch, "Too many requests");
        require(batchesToRequests[fromChainId][batchId].length == 0, "Requests already fulfilled");
        require(!batchIsFulfilled[fromChainId][batchId], "Requests already fulfilled");

        uint256 totalFulfilled;

        // aderyn-ignore-next-line(costly-loop)
        for (uint256 i = 0; i < requests.length; i++) {
            totalFulfilled += fulfillRequest(fromChainId, batchId, requests[i]);
        }

        fulfillmentsCounter += requests.length;
        batchIsFulfilled[fromChainId][batchId] = true;

        emit PointsFulfilled(fromChainId, batchId, totalFulfilled);
    }

    function fulfillRequest(uint256 fromChainId, uint256 batchId, ILockS.Request memory request)
        private
        returns (uint256)
    {
        require(!request.isFulfilled, "Requests already fulfilled");
        require(request.wallet != address(0), "Invalid wallet address");
        require(request.amount > 0, "Invalid amount");

        request.isFulfilled = true;
        batchesToRequests[fromChainId][batchId].push(request);

        points.mint(request.wallet, request.amount);

        return request.amount;
    }

    function requestsFrom(uint256 chainId, uint256 batchId) external view returns (ILockS.Request[] memory) {
        return batchesToRequests[chainId][batchId];
    }
}
