//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.22;

interface IGauge {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getReward(address _account) external;
    function stakingToken() external view returns (address);
    function balanceOf(address account) external view returns (uint256);
    function earned(address _account) external view returns (uint256);
}
