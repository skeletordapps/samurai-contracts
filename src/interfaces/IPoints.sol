// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

interface IPoints {
    enum Roles {
        BOOSTER,
        MINTER,
        BURNER
    }

    error NotAllowed(string);

    event BoostSet(address account, uint256 boost);
    event MintedPoints(address account, uint256 numOfPoints, uint256 boost);
    event BurnedPoints(address account, uint256 numOfPoints);

    function points(address account) external returns (uint256);
    function mint(address to, uint256 numOfPoints) external;
    function burn(address from, uint256 numOfPoints) external;
    function setBoost(address to, uint8 boost) external;
    function grantRole(Roles role, address account) external;
    function revokeRole(Roles role, address account) external;
    function boostOf(address account) external returns (uint256);
}
