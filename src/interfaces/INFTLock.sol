// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

interface INFTLock {
    event NFTLocked(address indexed wallet, uint256 tokenId);
    event NFTUnlocked(address indexed wallet, uint256 tokenId);
}
