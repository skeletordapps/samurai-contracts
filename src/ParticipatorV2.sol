// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console2} from "forge-std/console2.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IParticipator} from "./interfaces/IParticipator.sol";
import {ISamuraiTiers} from "./interfaces/ISamuraiTiers.sol";

contract ParticipatorV2 is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    address public samuraiTiers;
    address[] public acceptedTokens;
    uint256 public maxAllocations;
    uint256 public raised;
    bool public isPublic;
    bool public usingETH;

    mapping(address wallet => uint256 allocation) public allocations;
    mapping(address wallet => bool whitelisted) public whitelist;
    IParticipator.WalletRange[] public ranges;

    constructor(
        address _samuraiTiers,
        uint256 _maxAllocations,
        IParticipator.WalletRange[] memory _ranges,
        bool _usingETH
    ) Ownable(msg.sender) {
        samuraiTiers = _samuraiTiers;
        if (_maxAllocations == 0) revert IParticipator.IParticipator__Invalid("Total Max should be greater than 0");

        maxAllocations = _maxAllocations;
        setRanges(_ranges);
        usingETH = _usingETH;
    }

    modifier whenUsingETH() {
        require(usingETH);
        _;
    }

    modifier whenUsingToken() {
        require(!usingETH);
        _;
    }

    modifier rangesNotEmpty() {
        if (ranges.length == 0) revert IParticipator.IParticipator__Invalid("Ranges are empty");
        _;
    }

    modifier canRegister(address wallet) {
        ISamuraiTiers.Tier memory walletTier = getWalletTier(wallet);

        if (bytes(walletTier.name).length == 0) {
            revert IParticipator.IParticipator__Unauthorized("Not allowed to whitelist");
        }
        _;
    }

    function registerToWhitelist(address wallet)
        external
        whenNotPaused
        nonReentrant
        rangesNotEmpty
        canRegister(wallet)
    {
        whitelist[wallet] = true;

        emit IParticipator.Whitelisted(wallet);
    }

    function participate(address wallet, address tokenAddress, uint256 amount)
        external
        whenNotPaused
        nonReentrant
        rangesNotEmpty
        whenUsingToken
    {
        if (!whitelist[wallet] && !isPublic) revert IParticipator.IParticipator__Unauthorized("Wallet not allowed");
        if (tokenAddress == address(0)) revert IParticipator.IParticipator__Invalid("Invalid Token");
        IParticipator.WalletRange memory walletRange = isPublic ? getRangeByName("Public") : getWalletRange(wallet);
        if (amount < walletRange.min) revert IParticipator.IParticipator__Invalid("Amount too low");
        if (amount > walletRange.max) revert IParticipator.IParticipator__Invalid("Amount too high");
        if (allocations[wallet] + amount > walletRange.max) {
            revert IParticipator.IParticipator__Invalid("Exceeds max allocation permitted");
        }
        if (raised + amount > maxAllocations) {
            revert IParticipator.IParticipator__Invalid("Exceeds max allocations permitted");
        }

        bool accepted;

        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            if (tokenAddress == acceptedTokens[i]) {
                accepted = true;
                break;
            }
        }

        if (!accepted) revert IParticipator.IParticipator__Invalid("Token not accepted");
        allocations[wallet] += amount;
        raised += amount;
        emit IParticipator.Allocated(wallet, tokenAddress, amount);

        ERC20(tokenAddress).safeTransferFrom(wallet, address(this), amount);
    }

    function participateETH(address wallet, uint256 amount) external payable whenNotPaused whenUsingETH nonReentrant {
        if (!whitelist[wallet] && !isPublic) revert IParticipator.IParticipator__Unauthorized("Wallet not allowed");
        if (amount == 0) revert IParticipator.IParticipator__Unauthorized("Insufficient amount");
        if (msg.value < amount) revert IParticipator.IParticipator__Unauthorized("Insufficient ETH");

        IParticipator.WalletRange memory walletRange = isPublic ? getRangeByName("Public") : getWalletRange(wallet);
        if (amount < walletRange.min) revert IParticipator.IParticipator__Invalid("Amount too low");
        if (amount > walletRange.max) revert IParticipator.IParticipator__Invalid("Amount too high");
        if (allocations[wallet] + amount > walletRange.max) {
            revert IParticipator.IParticipator__Invalid("Exceeds max allocation permitted");
        }
        if (raised + amount > maxAllocations) {
            revert IParticipator.IParticipator__Invalid("Exceeds max allocations permitted");
        }

        allocations[wallet] += amount;
        raised += amount;
        emit IParticipator.Allocated(wallet, address(0), amount);
    }

    function setTokens(address[] memory _acceptedTokens) external onlyOwner nonReentrant {
        acceptedTokens = new address[](_acceptedTokens.length);
        for (uint256 i = 0; i < _acceptedTokens.length; i++) {
            if (_acceptedTokens[i] == address(0)) revert IParticipator.IParticipator__Invalid("Invalid Token");
            acceptedTokens[i] = _acceptedTokens[i];
        }
    }

    function withdraw() external onlyOwner nonReentrant {
        if (usingETH) {
            payable(owner()).transfer(address(this).balance); // Transfer ETH directly if usingETH is true
        } else {
            for (uint256 i = 0; i < acceptedTokens.length; i++) {
                uint256 balance = ERC20(acceptedTokens[i]).balanceOf(address(this));
                ERC20(acceptedTokens[i]).safeTransfer(owner(), balance);
            }
        }
    }

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

    function setRanges(IParticipator.WalletRange[] memory _ranges) public onlyOwner nonReentrant {
        if (ranges.length == 0) {
            for (uint256 i = 0; i < _ranges.length; i++) {
                ranges.push(_ranges[i]);
            }
        } else {
            for (uint256 i = 0; i < _ranges.length; i++) {
                ranges[i] = _ranges[i];
            }
        }
    }

    function getWalletRange(address wallet) public view returns (IParticipator.WalletRange memory walletRange) {
        ISamuraiTiers.Tier memory tier = getWalletTier(wallet);
        if (bytes(tier.name).length == 0) revert IParticipator.IParticipator__Invalid("Tier not found");

        IParticipator.WalletRange[] memory _ranges = ranges;

        for (uint256 i = 0; i < _ranges.length; i++) {
            if (keccak256(abi.encodePacked(_ranges[i].name)) == keccak256(abi.encodePacked(tier.name))) {
                walletRange.name = tier.name;
                walletRange.min = _ranges[i].min;
                walletRange.max = _ranges[i].max;

                return walletRange;
            }
        }
    }

    function getRangeByName(string memory name) public view returns (IParticipator.WalletRange memory range) {
        IParticipator.WalletRange[] memory _ranges = ranges;

        for (uint256 i = 0; i < _ranges.length; i++) {
            if (keccak256(abi.encodePacked(_ranges[i].name)) == keccak256(abi.encodePacked(name))) {
                return _ranges[i];
            }
        }
    }

    function getWalletTier(address wallet) public view returns (ISamuraiTiers.Tier memory tier) {
        tier = ISamuraiTiers(samuraiTiers).getTier(wallet);
    }

    function acceptedTokensLength() public view returns (uint256) {
        return acceptedTokens.length;
    }

    function rangesLength() public view returns (uint256) {
        return ranges.length;
    }

    function getRange(uint256 index) public view returns (IParticipator.WalletRange memory) {
        return ranges[index];
    }
}
