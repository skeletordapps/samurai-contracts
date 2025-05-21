//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ILockS} from "./interfaces/ILockS.sol";
import {IPoints} from "./interfaces/IPoints.sol";
import {console} from "forge-std/console.sol";

contract PointsBridge is Ownable, Pausable, ReentrancyGuard {
    IPoints public points;

    uint256 public constant MAX_REQUESTS = 50;
    uint256 public currentBatchId;
    uint256 public fulfillmentsCounter;

    mapping(uint256 id => mapping(uint256 fromChainId => ILockS.Request[])) public requests;
    mapping(bytes32 id => bool isRequestFulfilled) public requested;

    event PointsFulfilled(uint256 indexed batchId, uint256 amount);

    constructor(address _points) Ownable(msg.sender) {
        points = IPoints(_points);
    }

    function fulfillRequests(uint256 fromChainId, ILockS.Request[] memory _requests)
        external
        whenNotPaused
        nonReentrant
        onlyOwner
    {
        uint256 _currentBatchIdCopy = currentBatchId;

        require(fromChainId != 0, "Invalid chain ID");
        require(_requests.length > 0, "No requests provided");
        require(_requests.length <= MAX_REQUESTS, "Too many requests");
        require(requests[_currentBatchIdCopy][fromChainId].length == 0, "Requests batch already fulfilled");

        uint256 totalFulfilled;

        for (uint256 i = 0; i < _requests.length; i++) {
            totalFulfilled += fulfill(_currentBatchIdCopy, fromChainId, _requests[i]);
        }

        fulfillmentsCounter += _requests.length;
        currentBatchId++;

        emit PointsFulfilled(_currentBatchIdCopy, totalFulfilled);
    }

    function fulfill(uint256 _currentBatchId, uint256 _fromChainId, ILockS.Request memory _request)
        private
        returns (uint256)
    {
        require(checkRequest(_request) == false, "Requests already fulfilled");
        require(_request.wallet != address(0), "Invalid wallet address");
        require(_request.amount > 0, "Invalid amount");

        _request.isFulfilled = true;
        requests[_currentBatchId][_fromChainId].push(_request);
        requested[keccak256(abi.encode(_request.wallet, _request.amount, _request.lockIndex))] = true;

        points.mint(_request.wallet, _request.amount);

        return _request.amount;
    }

    function checkRequest(ILockS.Request memory _request) public view returns (bool) {
        bytes32 requestHash = keccak256(abi.encode(_request.wallet, _request.amount, _request.lockIndex));
        return requested[requestHash];
    }

    function getRequests(uint256 _currentBatchId, uint256 _fromChainId) public view returns (ILockS.Request[] memory) {
        return requests[_currentBatchId][_fromChainId];
    }
}
