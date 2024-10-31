// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IParticipator} from "./interfaces/IParticipator.sol";
import {ISamuraiTiers} from "./interfaces/ISamuraiTiers.sol";
import {console} from "forge-std/console.sol";

contract PrivateParticipator is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    address public immutable acceptedToken;
    uint256 public immutable maxAllocations;
    uint256 public immutable pricePerToken;
    uint256 public immutable minPerWallet;

    uint256 public raised;
    bool public isPublic;

    mapping(address wallet => uint256 max) public walletsMaxPermitted;
    mapping(address wallet => uint256 allocation) public allocations;

    /**
     * @notice Constructor to initialize the contract.
     * @param _acceptedToken Address of the accepted token.
     * @param _maxAllocations Total maximum allowed allocations. (Must be greater than 0)
     * @param _pricePerToken price per token purchased. (Must be greater than 0)
     * @param _minPerWallet Min allowed to allocation. (Must be greater than 0)
     * @param _wallets List of wallets addresses.
     * @param _purchases List of purchases by wallets.
     */
    constructor(
        address _acceptedToken,
        uint256 _maxAllocations,
        uint256 _pricePerToken,
        uint256 _minPerWallet,
        address[] memory _wallets,
        uint256[] memory _purchases
    ) Ownable(msg.sender) {
        require(_acceptedToken != address(0), IParticipator.IParticipator__Invalid("Invalid address"));
        require(_maxAllocations > 0, IParticipator.IParticipator__Invalid("Total Max should be greater than 0"));
        require(_pricePerToken > 0, IParticipator.IParticipator__Invalid("Price per token should be greater than 0"));
        require(_minPerWallet > 0, IParticipator.IParticipator__Invalid("Min per wallet should be greater than 0"));

        acceptedToken = _acceptedToken;
        maxAllocations = _maxAllocations;
        pricePerToken = _pricePerToken;
        minPerWallet = _minPerWallet;

        _setMaxPermitted(_wallets, _purchases);
    }

    /**
     * @notice Allows a user to participate in the allocation using a specific token.
     * @param amount The amount of tokens to participate with.
     * emit Allocated(msg.sender, tokenAddress, amount) Emitted when a user successfully participates with a token.
     */
    function participate(uint256 amount) external whenNotPaused nonReentrant {
        uint256 min = minPerWallet;
        uint256 max = walletsMaxPermitted[msg.sender];

        require(max > 0 || isPublic, IParticipator.IParticipator__Unauthorized("Wallet not allowed"));
        require(amount >= min, IParticipator.IParticipator__Invalid("Amount too low"));
        require(amount <= max, IParticipator.IParticipator__Invalid("Amount too high"));
        require(
            allocations[msg.sender] + amount <= max,
            IParticipator.IParticipator__Invalid("Exceeds max allocation permitted")
        );

        require(
            raised + amount <= maxAllocations, IParticipator.IParticipator__Invalid("Exceeds max allocations permitted")
        );

        allocations[msg.sender] += amount;
        raised += amount;
        emit IParticipator.Allocated(msg.sender, acceptedToken, amount);

        ERC20(acceptedToken).safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @notice Allows the contract owner to withdraw the raised funds.
     * @dev This function can only be called by the contract owner and is protected against reentrancy.
     */
    function withdraw() external onlyOwner nonReentrant {
        uint256 balance = ERC20(acceptedToken).balanceOf(address(this));
        ERC20(acceptedToken).safeTransfer(owner(), balance);
    }

    /**
     * @notice Opens participation to the public.
     * @dev This function can only be called by the contract owner and is protected against reentrancy.
     *       Setting public participation to true allows anyone to participate without being whitelisted.
     * emit IParticipator.PublicAllowed() Emitted when public participation is enabled.
     */
    function makePublic() external onlyOwner nonReentrant {
        isPublic = true;

        emit IParticipator.PublicAllowed();
    }

    /**
     * @dev Pauses all token transfers.
     * Can only be called by the contract owner.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses token transfers.
     * Can only be called by the contract owner.
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    /**
     * @notice Alows contract to set the list of wallets and it's purchases to be vested based on contract strategy
     * @param _wallets list of wallets
     * @param _purchases list of purchases of each wallet
     */
    function _setMaxPermitted(address[] memory _wallets, uint256[] memory _purchases) private onlyOwner nonReentrant {
        require(_wallets.length > 0, "wallets cannot be empty");
        require(
            _wallets.length == _purchases.length,
            IParticipator.IParticipator__Unauthorized("wallets and purchases should have same size length")
        );

        for (uint256 i = 0; i < _wallets.length; i++) {
            require(_wallets[i] != address(0), IParticipator.IParticipator__Invalid("Invalid address"));
            require(_purchases[i] > 0, IParticipator.IParticipator__Invalid("Invalid purchase amount"));

            walletsMaxPermitted[_wallets[i]] = _purchases[i] * pricePerToken;
        }
    }

    /**
     * @notice Retrieves the participation range applicable to a specific wallet based on their tier.
     * @dev This function is view-only and retrieves the range information for the wallet
     * @param wallet The address of the wallet to get the participation range for.
     * @return walletRange A uint256 number with range.
     */
    function getWalletMaxPermitted(address wallet) public view returns (uint256) {
        return walletsMaxPermitted[wallet];
    }
}
