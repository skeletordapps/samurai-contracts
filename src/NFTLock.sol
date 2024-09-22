// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/interfaces/IERC721Receiver.sol";
import {INFTLock} from "./interfaces/INFTLock.sol";
import {IPoints} from "./interfaces/IPoints.sol";
import {console} from "forge-std/console.sol";

contract NFTLock is IERC721Receiver, Pausable, ReentrancyGuard, Ownable {
    uint256 public constant POINTS_PER_LOCK = 10_000 ether;
    uint256 public constant MAX_LOCKED = 5;
    uint256 public totalLocked;
    uint256 public totalWithdrawal;
    ERC721 private immutable samNFT;
    IPoints private immutable iPoints;
    address public immutable nftAddress;

    // Mapping to store lock information for each NFT
    struct LockInfo {
        address owner;
        uint256 lockedAt;
        uint256 unlockTime;
    }

    mapping(uint256 tokenId => address wallet) public ownerOf;
    mapping(address wallet => uint8 total) public locks;

    constructor(address _samNFT, address _points) Ownable(msg.sender) {
        samNFT = ERC721(_samNFT);
        nftAddress = _samNFT;
        iPoints = IPoints(_points);
    }

    /// @notice Pause the contract, preventing further locking actions
    function pause() external onlyOwner {
        _pause();
    }

    /// @notice Unpause the contract, allowing locking actions again
    function unpause() external onlyOwner {
        _unpause();
    }

    function onERC721Received(address operator, address from, uint256 id, bytes calldata)
        external
        override
        returns (bytes4)
    {
        require(operator == samNFT.ownerOf(id), "Not the owner");

        ownerOf[id] = from;
        locks[from]++;
        totalLocked++;

        setBoost(from, locks[from]);
        emit INFTLock.NFTLocked(msg.sender, id);

        return this.onERC721Received.selector;
    }

    /**
     * @dev Locks an NFT.
     * @param tokenId ID of the NFT to lock.
     */
    function lockNFT(uint256 tokenId) external nonReentrant whenNotPaused {
        require(msg.sender == samNFT.ownerOf(tokenId), "Not the owner");
        require(locks[msg.sender] + 1 <= MAX_LOCKED, "Exceeds limit");

        samNFT.safeTransferFrom(msg.sender, address(this), tokenId);
    }

    /**
     * @dev Unlocks an NFT.
     * @param tokenId ID of the NFT to unlock.
     */
    function unlockNFT(uint256 tokenId) external nonReentrant {
        require(msg.sender == ownerOf[tokenId], "Not the owner");

        delete ownerOf[tokenId];
        locks[msg.sender]--;
        totalWithdrawal++;

        setBoost(msg.sender, locks[msg.sender]);
        emit INFTLock.NFTUnlocked(msg.sender, tokenId);

        samNFT.safeTransferFrom(address(this), msg.sender, tokenId);
    }

    function setBoost(address to, uint8 amount) private {
        iPoints.setBoost(to, amount);
    }
}
