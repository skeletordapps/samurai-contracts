// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

interface IPoints {
    error NotAllowed(string);

    event MintedPoints(address account, uint256 numOfPoints);
    event BurnedPoints(address account, uint256 numOfPoints);

    function points(address account) external returns (uint256);
    function mint(address to, uint256 numOfPoints) external;
    function burn(address from, uint256 numOfPoints) external;
    function grantManagerRole(address account) external;
    function revokeManagerRole(address account) external;
}
