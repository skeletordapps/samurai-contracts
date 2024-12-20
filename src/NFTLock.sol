// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import {BokkyPooBahsDateTimeLibrary} from "@BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";
import {INFTLock} from "./interfaces/INFTLock.sol";
import {IPoints} from "./interfaces/IPoints.sol";
import {console} from "forge-std/console.sol";

contract NFTLock is IERC721Receiver, Pausable, ReentrancyGuard, Ownable {
    uint256 public constant MAX_LOCKED = 10;
    uint256 public constant MAX_TO_BOOST = 5;
    uint256 public constant MIN_MONTHS_LOCKED = 6;
    uint256 public totalLocked;
    uint256 public totalWithdrawal;
    ERC721 private immutable samNFT;
    IPoints private immutable iPoints;
    address public immutable nftAddress;
    bool public lockPeriodDisabled;

    mapping(uint256 tokenId => address wallet) public ownerOf;
    mapping(address wallet => uint8 total) public locks;
    mapping(uint256 tokenId => uint256 lockedAt) public locksAt;

    constructor(address _samNFT, address _points) Ownable(msg.sender) {
        samNFT = ERC721(_samNFT);
        nftAddress = _samNFT;
        iPoints = IPoints(_points);
    }

    modifier isLockOwner(address wallet, uint256 tokenId) {
        require(wallet == ownerOf[tokenId], INFTLock.INFTLock__Error("Not the owner"));
        _;
    }

    /// @notice Pause the contract, preventing further locking actions
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract, allowing locking actions again
    function unpause() external onlyOwner {
        _unpause();
    }

    function disableLockPeriod() external onlyOwner nonReentrant {
        lockPeriodDisabled = true;
        emit INFTLock.LockPeriodDisabled(block.timestamp);
    }

    function onERC721Received(address operator, address from, uint256 id, bytes calldata)
        external
        override
        returns (bytes4)
    {
        require(operator == samNFT.ownerOf(id), INFTLock.INFTLock__Error("Not the owner"));

        ownerOf[id] = from;
        locks[from]++;
        locksAt[id] = block.timestamp;
        totalLocked++;

        _setBoost(from, locks[from]);
        emit INFTLock.NFTLocked(msg.sender, id);

        return this.onERC721Received.selector;
    }

    /**
     * @dev Locks an NFT.
     * @param tokenId ID of the NFT to lock.
     */
    function lockNFT(uint256 tokenId) external nonReentrant whenNotPaused {
        require(msg.sender == samNFT.ownerOf(tokenId), INFTLock.INFTLock__Error("Not the owner"));
        require(locks[msg.sender] + 1 <= MAX_LOCKED, INFTLock.INFTLock__Error("Exceeds limit"));

        samNFT.safeTransferFrom(msg.sender, address(this), tokenId);
    }

    function unlockNFTForWallet(address wallet, uint256 tokenId)
        external
        onlyOwner
        isLockOwner(wallet, tokenId)
        nonReentrant
    {
        _unlock(wallet, tokenId);
    }

    /**
     * @dev Unlocks an NFT.
     * @param tokenId ID of the NFT to unlock.
     */
    function unlockNFT(uint256 tokenId) external isLockOwner(msg.sender, tokenId) nonReentrant {
        if (!lockPeriodDisabled) {
            require(
                BokkyPooBahsDateTimeLibrary.diffMonths(locksAt[tokenId], block.timestamp) >= MIN_MONTHS_LOCKED,
                INFTLock.INFTLock__Error("Not allowed to unlock before min period")
            );
        }

        _unlock(msg.sender, tokenId);
    }

    function _unlock(address wallet, uint256 tokenId) private {
        delete ownerOf[tokenId];
        locks[wallet]--;
        totalWithdrawal++;

        _setBoost(wallet, locks[wallet]);
        emit INFTLock.NFTUnlocked(wallet, tokenId);

        samNFT.safeTransferFrom(address(this), wallet, tokenId);
    }

    function _setBoost(address to, uint8 amount) private {
        if (amount < 6) iPoints.setBoost(to, amount);
    }
}
