// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IPoints} from "./interfaces/IPoints.sol";

contract SamuraiPoints is Ownable, AccessControl {
    mapping(address wallet => uint256 numOfPoints) points;

    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    constructor() Ownable(msg.sender) {
        grantManagerRole(msg.sender);
    }

    function grantPoints(address to, uint256 numOfPoints) external onlyRole(MANAGER_ROLE) {
        points[to] += numOfPoints;
        emit IPoints.PointsAdded(to, numOfPoints);
    }

    function removePoints(address from, uint256 numOfPoints) external onlyRole(MANAGER_ROLE) {
        uint256 currentPoints = points[from];

        if (currentPoints - numOfPoints >= 0) {
            points[from] -= numOfPoints;
            emit IPoints.PointsRemoved(from, numOfPoints);
        }
    }

    function grantManagerRole(address account) public onlyOwner {
        _grantRole(MANAGER_ROLE, account);
    }

    function revokeManagerRole(address account) public onlyOwner {
        _revokeRole(MANAGER_ROLE, account);
    }
}
