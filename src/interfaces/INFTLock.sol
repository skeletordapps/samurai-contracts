// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface INFTLock {
    event NFTLocked(address indexed wallet, uint256 tokenId);
    event NFTUnlocked(address indexed wallet, uint256 tokenId);
    event LockPeriodToggled(uint256 updatedAt, bool isDisabled);

    error INFTLock__Error(string message);
}
