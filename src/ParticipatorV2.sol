// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
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
    bool public usingLinkedWallet;

    mapping(address wallet => uint256 allocation) public allocations;
    mapping(address wallet => bool whitelisted) public whitelist;
    mapping(address wallet => string linkedWallet) public linkedWallets;
    IParticipator.WalletRange[] public ranges;

    /**
     * @notice Constructor to initialize the contract.
     * @param _samuraiTiers Address of the SamuraiTiers contract.
     * @param _maxAllocations Total maximum allowed allocations. (Must be greater than 0)
     * @param _ranges Array of initial participation ranges.
     * @param _usingETH Flag indicating if ETH participation is enabled.
     */
    constructor(
        address _samuraiTiers,
        uint256 _maxAllocations,
        IParticipator.WalletRange[] memory _ranges,
        bool _usingETH,
        bool _usingLinkedWallet
    ) Ownable(msg.sender) {
        require(_samuraiTiers != address(0), IParticipator.IParticipator__Invalid("Invalid address"));
        require(_maxAllocations > 0, IParticipator.IParticipator__Invalid("Total Max should be greater than 0"));

        samuraiTiers = _samuraiTiers;
        maxAllocations = _maxAllocations;
        setRanges(_ranges);
        usingETH = _usingETH;
        usingLinkedWallet = _usingLinkedWallet;
    }

    /// @dev Enforces that the contract is configured for ETH participation.
    modifier whenUsingETH() {
        require(usingETH);
        _;
    }

    /// @dev Enforces that the contract is configured for token participation.
    modifier whenUsingToken() {
        require(!usingETH);
        _;
    }

    /// @dev Reverts if the `ranges` array is empty.
    modifier rangesNotEmpty() {
        require(ranges.length > 0, IParticipator.IParticipator__Invalid("Ranges are empty"));
        _;
    }

    modifier linkedWalletChecked() {
        if (usingLinkedWallet) {
            require(
                bytes(linkedWallets[msg.sender]).length > 0,
                IParticipator.IParticipator__Unauthorized("Linked wallet not found")
            );
        }
        _;
    }

    /// @dev Restricts registration to whitelisted wallets or during public participation.
    modifier canRegister() {
        ISamuraiTiers.Tier memory walletTier = getWalletTier(msg.sender);

        require(
            bytes(walletTier.name).length > 0, IParticipator.IParticipator__Unauthorized("Not allowed to whitelist")
        );

        _;
    }

    function linkWallet(string memory linkedWallet) external whenNotPaused nonReentrant {
        if (usingLinkedWallet) {
            require(bytes(linkedWallet).length > 0, IParticipator.IParticipator__Invalid("Invalid address"));
        } else {
            revert IParticipator.IParticipator__Unauthorized("Not using linked wallets");
        }

        linkedWallets[msg.sender] = linkedWallet;
    }

    /**
     * @notice Registers a wallet for the whitelist.
     * @dev Can only be called by a non-paused contract, while not in a reentrant call,
     *       by a wallet with a valid tier in SamuraiTiers (not empty tier name),
     *       and only if the wallet is not already whitelisted.
     * emit Whitelisted(wallet) Emitted when a wallet is successfully whitelisted.
     */
    function registerToWhitelist() external whenNotPaused nonReentrant rangesNotEmpty canRegister linkedWalletChecked {
        whitelist[msg.sender] = true;

        emit IParticipator.Whitelisted(msg.sender);
    }

    /**
     * @notice Allows a user to participate in the allocation using a specific token.
     * @dev Can only be called by a non-paused contract, while not in a reentrant call,
     *       with valid participation ranges defined, if the provided amount meets the
     *       minimum and maximum limits for the user's tier (based on `getWalletRange`),
     *       if the total raised amount doesn't exceed the maximum allocations,
     *       and if the provided token address is valid (non-zero) and accepted by the contract.
     *       Additionally, the user must be whitelisted or public participation must be allowed.
     * @param tokenAddress The address of the ERC20 token used for participation.
     * @param amount The amount of tokens to participate with.
     * emit Allocated(msg.sender, tokenAddress, amount) Emitted when a user successfully participates with a token.
     */
    function participate(address tokenAddress, uint256 amount)
        external
        whenNotPaused
        nonReentrant
        rangesNotEmpty
        whenUsingToken
        linkedWalletChecked
    {
        require(whitelist[msg.sender] || isPublic, IParticipator.IParticipator__Unauthorized("Wallet not allowed"));
        require(tokenAddress != address(0), IParticipator.IParticipator__Invalid("Invalid Token"));
        IParticipator.WalletRange memory walletRange = getWalletRange(msg.sender);
        require(amount >= walletRange.min, IParticipator.IParticipator__Invalid("Amount too low"));
        require(amount <= walletRange.max, IParticipator.IParticipator__Invalid("Amount too high"));
        require(
            allocations[msg.sender] + amount <= walletRange.max,
            IParticipator.IParticipator__Invalid("Exceeds max allocation permitted")
        );

        require(
            raised + amount <= maxAllocations, IParticipator.IParticipator__Invalid("Exceeds max allocations permitted")
        );

        bool accepted;

        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            if (tokenAddress == acceptedTokens[i]) {
                accepted = true;
                break;
            }
        }

        require(accepted, IParticipator.IParticipator__Invalid("Token not accepted"));

        allocations[msg.sender] += amount;
        raised += amount;
        emit IParticipator.Allocated(msg.sender, tokenAddress, amount);

        ERC20(tokenAddress).safeTransferFrom(msg.sender, address(this), amount);
    }

    /**
     * @notice Allows a user to participate in the allocation using ETH.
     * @dev Can only be called by a non-paused contract, while not in a reentrant call,
     *       with valid participation ranges defined, if the provided amount meets the
     *       minimum and maximum limits for the user's tier (based on `getWalletRange`),
     *       if the total raised amount doesn't exceed the maximum allocations,
     *       and if the user must be whitelisted or public participation must be allowed.
     *       Additionally, the user must send enough ETH to cover the participation amount.
     * @param amount The amount of ETH to participate with (in wei).
     * emit Allocated(msg.sender, address(0), amount) Emitted when a user successfully participates with ETH.
     */
    function participateETH(uint256 amount)
        external
        payable
        whenNotPaused
        whenUsingETH
        linkedWalletChecked
        nonReentrant
    {
        require(whitelist[msg.sender] || isPublic, IParticipator.IParticipator__Unauthorized("Wallet not allowed"));
        require(amount > 0, IParticipator.IParticipator__Unauthorized("Insufficient amount"));
        require(msg.value == amount, IParticipator.IParticipator__Unauthorized("Insufficient ETH"));

        IParticipator.WalletRange memory walletRange = getWalletRange(msg.sender);
        require(amount >= walletRange.min, IParticipator.IParticipator__Invalid("Amount too low"));
        require(amount <= walletRange.max, IParticipator.IParticipator__Invalid("Amount too high"));
        require(
            allocations[msg.sender] + amount <= walletRange.max,
            IParticipator.IParticipator__Invalid("Exceeds max allocation permitted")
        );

        require(
            raised + amount <= maxAllocations, IParticipator.IParticipator__Invalid("Exceeds max allocations permitted")
        );

        allocations[msg.sender] += amount;
        raised += amount;
        emit IParticipator.Allocated(msg.sender, address(0), amount);
    }

    /**
     * @notice Allows the contract owner to set the accepted ERC20 tokens for participation.
     * @dev This function can only be called by the contract owner and is protected against reentrancy.
     *       It reverts if any of the provided token addresses are invalid (zero address).
     * @param _acceptedTokens An array of addresses for the accepted ERC20 tokens.
     */
    function setTokens(address[] memory _acceptedTokens) external onlyOwner nonReentrant {
        acceptedTokens = new address[](_acceptedTokens.length);
        for (uint256 i = 0; i < _acceptedTokens.length; i++) {
            require(_acceptedTokens[i] != address(0), IParticipator.IParticipator__Invalid("Invalid Token"));
            acceptedTokens[i] = _acceptedTokens[i];
        }
    }

    /**
     * @notice Allows the contract owner to withdraw the raised funds.
     * @dev This function can only be called by the contract owner and is protected against reentrancy.
     *       The behavior depends on the `usingETH` flag:
     *         - If ETH participation is enabled, it transfers all ETH balance to the owner.
     *         - If ETH participation is disabled, it transfers the balance of each accepted token to the owner.
     */
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
     * @notice Allows the contract owner to set the participation ranges for different tiers.
     * @dev This function can only be called by the contract owner and is protected against reentrancy.
     *       It reverts if the provided ranges array is empty or if the first element in the array
     *       does not have the name "Public" (to ensure consistency).
     * @param _ranges An array of `IParticipator.WalletRange` structs defining the participation ranges.
     */
    function setRanges(IParticipator.WalletRange[] memory _ranges) public onlyOwner nonReentrant {
        require(
            keccak256(abi.encodePacked(_ranges[0].name)) == keccak256(abi.encodePacked("Public")),
            IParticipator.IParticipator__Invalid("Index 0 must be Public range")
        );
        ranges = new IParticipator.WalletRange[](_ranges.length);
        for (uint256 i = 0; i < _ranges.length; i++) {
            ranges[i] = _ranges[i];
        }
    }

    /**
     * @notice Retrieves the participation range applicable to a specific wallet based on their tier.
     * @dev This function is view-only and retrieves the range information from the `SamuraiTiers` contract
     *       using the provided wallet address. If tier.name is empty string, returns the public wallet range.
     * @param wallet The address of the wallet to get the participation range for.
     * @return walletRange A struct containing details about the participation range for the provided wallet.
     */
    function getWalletRange(address wallet) public view returns (IParticipator.WalletRange memory walletRange) {
        ISamuraiTiers.Tier memory tier = getWalletTier(wallet);
        IParticipator.WalletRange[] memory _ranges = ranges;

        if (isPublic || keccak256(abi.encodePacked(tier.name)) == keccak256(abi.encodePacked(""))) {
            walletRange.name = _ranges[0].name;
            walletRange.min = _ranges[0].min;
            walletRange.max = _ranges[0].max;

            return walletRange;
        }

        for (uint256 i = 0; i < _ranges.length; i++) {
            if (keccak256(abi.encodePacked(_ranges[i].name)) == keccak256(abi.encodePacked(tier.name))) {
                walletRange.name = tier.name;
                walletRange.min = _ranges[i].min;
                walletRange.max = _ranges[i].max;

                return walletRange;
            }
        }
    }

    /**
     * @notice Fetches the tier information for a wallet from the `SamuraiTiers` contract.
     * @dev This function is view-only and retrieves the tier details for the provided wallet address
     *       by calling the `getTier` function of the `SamuraiTiers` contract. It reverts if
     *       the tier information cannot be retrieved.
     * @param wallet The address of the wallet to get the tier information for.
     * @return tier A string representing the tier name for the provided wallet.
     */
    function getWalletTier(address wallet) public view returns (ISamuraiTiers.Tier memory tier) {
        tier = ISamuraiTiers(samuraiTiers).getTier(wallet);
    }

    /**
     * @notice Returns the number of accepted tokens configured for participation.
     * @dev This function is view-only and simply returns the length of the `acceptedTokens` array.
     * @return The number of accepted ERC20 tokens.
     */
    function acceptedTokensLength() public view returns (uint256) {
        return acceptedTokens.length;
    }

    /**
     * @notice Returns the number of participation ranges defined for the allocation.
     * @dev This function is view-only and simply returns the length of the `ranges` array.
     * @return The number of defined participation ranges.
     */
    function rangesLength() public view returns (uint256) {
        return ranges.length;
    }

    /**
     * @notice Retrieves a participation range by its index in the `ranges` array.
     * @dev This function requires a valid index within the range of the `ranges` array.
     * @param index The index of the participation range to retrieve (0-based indexing).
     * @return walletRange A struct containing details about the participation range at the specified index.
     */
    function getRange(uint256 index) public view returns (IParticipator.WalletRange memory) {
        require(index < ranges.length, IParticipator.IParticipator__Invalid("Invalid range index"));
        return ranges[index];
    }
}
