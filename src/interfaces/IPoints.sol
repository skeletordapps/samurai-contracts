// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

interface IPoints {
    event PointsAdded(address account, uint256 numOfPoints);
    event PointsRemoved(address account, uint256 numOfPoints);

    function points(address account) external returns (uint256);
    function grantPoints(address to, uint256 numOfPoints) external;
    function removePoints(address from, uint256 numOfPoints) external;
    function grantManagerRole(address account) external;
    function revokeManagerRole(address account) external;
}
