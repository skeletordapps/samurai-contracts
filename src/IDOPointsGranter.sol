// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract IDOPointsGranter is Ownable {
    mapping(address wallet => uint256 numOfPoints) points;

    constructor() Ownable(msg.sender) {}

    function grantPoints(address to, uint256 numOfPoints) external onlyOwner {
        points[to] += numOfPoints;
    }

    function removePoints(address from, uint256 numOfPoints) external onlyOwner {
        uint256 currentPoints = points[from];

        if (currentPoints - numOfPoints >= 0) {
            points[from] -= numOfPoints;
        }
    }
}
