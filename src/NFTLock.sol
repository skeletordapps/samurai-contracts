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
    mapping(address wallet => uint8 total) public locksCounter;
    mapping(uint256 tokenId => uint256 lockedAt) public locksAt;
    mapping(address wallet => mapping(uint8 index => uint256 tokenId)) public locks;

    constructor(address _samNFT, address _points) Ownable(msg.sender) {
        samNFT = ERC721(_samNFT);
        nftAddress = _samNFT;
        iPoints = IPoints(_points);
    }

    /**
     * @dev Modifier to restrict function calls to the owner of the specified NFT.
     * @param wallet Address of the wallet to check ownership for.
     * @param tokenId ID of the NFT to check ownership for.
     * @custom:error Not the owner
     */
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

    /**
     * @notice This function should be used with extreme caution as it bypasses
     * the intended lock period mechanism.
     * @dev Disables the minimum lock period requirement.
     * Can only be called by the contract owner.
     * emit LockPeriodDisabled Emitted when the lock period is disabled.
     */
    function toggleLockPeriod() external onlyOwner nonReentrant {
        bool isDisabled = !lockPeriodDisabled;
        lockPeriodDisabled = isDisabled;
        emit INFTLock.LockPeriodToggled(block.timestamp, isDisabled);
    }

    /**
     * @notice Handles the receipt of an NFT.
     * @dev This function is called by the underlying ERC721 contract
     * when an NFT is transferred to this contract.
     *
     * @param operator Address of the operator transferring the NFT.
     * @param from Address of the NFT's previous owner.
     * @param id ID of the NFT being received.
     *
     * @return bytes4 This function must return the ERC721Receiver interface ID
     *         to indicate successful receipt of the NFT.
     *
     * @custom:error Not the owner
     *         Reverts if the operator transferring the NFT is not
     *         the actual owner of the NFT.
     */
    function onERC721Received(address operator, address from, uint256 id, bytes calldata)
        external
        override
        returns (bytes4)
    {
        require(operator == samNFT.ownerOf(id), INFTLock.INFTLock__Error("Not the owner"));

        ownerOf[id] = from;
        locks[from][locksCounter[from]] = id;
        locksAt[id] = block.timestamp;
        locksCounter[from]++;
        totalLocked++;

        _setBoost(from, locksCounter[from]);
        emit INFTLock.NFTLocked(msg.sender, id);

        return this.onERC721Received.selector;
    }

    /**
     * @dev Locks an NFT.
     * @param tokenId ID of the NFT to lock.
     * @custom:error Exceeds limit
     * @custom:error Not the owner
     */
    function lockNFT(uint256 tokenId) external nonReentrant whenNotPaused {
        require(msg.sender == samNFT.ownerOf(tokenId), INFTLock.INFTLock__Error("Not the owner"));
        require(locksCounter[msg.sender] + 1 <= MAX_LOCKED, INFTLock.INFTLock__Error("Exceeds limit"));

        samNFT.safeTransferFrom(msg.sender, address(this), tokenId);
    }

    /**
     * @dev Unlocks an NFT for a specified wallet.
     * Can only be called by the contract owner.
     * @param wallet Address of the wallet to unlock the NFT for.
     * @param tokenId ID of the NFT to unlock.
     */
    function unlockNFTForWallet(address wallet, uint8 index, uint256 tokenId)
        external
        onlyOwner
        isLockOwner(wallet, tokenId)
        nonReentrant
    {
        _unlock(wallet, index, tokenId);
    }

    /**
     * @dev Unlocks an NFT.
     * @param tokenId ID of the NFT to unlock.
     * @custom:error Not allowed to unlock before min period
     * @custom:error Not the owner
     */
    function unlockNFT(uint8 index, uint256 tokenId) external isLockOwner(msg.sender, tokenId) nonReentrant {
        if (!lockPeriodDisabled) {
            require(
                BokkyPooBahsDateTimeLibrary.diffMonths(locksAt[tokenId], block.timestamp) >= MIN_MONTHS_LOCKED,
                INFTLock.INFTLock__Error("Not allowed to unlock before min period")
            );
        }

        _unlock(msg.sender, index, tokenId);
    }

    function getTokenId(address wallet, uint8 index) public view returns (uint256) {
        return locks[wallet][index];
    }

    /**
     * @dev Private function to handle NFT unlocking logic.
     * @param wallet Address of the wallet to unlock the NFT for.
     * @param tokenId ID of the NFT to unlock.
     */
    function _unlock(address wallet, uint8 index, uint256 tokenId) private {
        require(locks[wallet][index] == tokenId, INFTLock.INFTLock__Error("Wrong index"));

        delete ownerOf[tokenId];
        delete locks[wallet][index];
        locksCounter[wallet]--;
        totalWithdrawal++;

        _setBoost(wallet, locksCounter[wallet]);
        emit INFTLock.NFTUnlocked(wallet, tokenId);

        samNFT.safeTransferFrom(address(this), wallet, tokenId);
    }

    /**
     * @dev Sets the boost for the given wallet based on the number of locked NFTs.
     * Max of 5 NFTs are boosted.
     * @param to Address of the wallet to set the boost for.
     * @param amount Number of NFTs currently locked by the wallet.
     */
    function _setBoost(address to, uint8 amount) private {
        if (amount < 6) iPoints.setBoost(to, amount);
    }
}
