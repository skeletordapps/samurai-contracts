// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

interface IParticipator {
    error IParticipator__Unauthorized(string message);
    error IParticipator__Invalid(string message);

    event Allocated(address indexed wallet, address token, uint256 amount);
    event Whitelisted(address[] addresses);
    event PublicAllowed();
    event PriceUpdated(uint256 oldPrice, uint256 newPrice);
}
