// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IIDO} from "./interfaces/IIDO.sol";
import {ISamuraiTiers} from "./interfaces/ISamuraiTiers.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";
import {console2} from "forge-std/console2.sol";

contract IDO is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    string public idoName;
    string public idoSymbol;
    string public idoDescription;
    address public token; // the IDO token
    address public samuraiTiers;
    address[] public acceptedTokens;
    uint256 public raised;
    bool public isPublic;
    bool public usingETH;
    bool public usingLinkedWallet;
    IIDO.VestingType public vestingType;
    IIDO.Amounts public amounts;
    IIDO.Periods public periods;

    mapping(address wallet => bool whitelisted) public whitelist;
    mapping(address wallet => string linkedWallet) public linkedWallets;
    mapping(address wallet => uint256 allocation) public allocations;
    mapping(address wallet => uint256 tokens) public tokens;
    mapping(address wallet => bool tgeClaimed) public hasClaimedTGE;
    mapping(address wallet => uint256 tokens) public tokensClaimed;
    mapping(address wallet => uint256 timestamp) public lastClaimTimestamps;
    IIDO.WalletRange[] public ranges;

    /**
     * @notice Sets the initial configuration for the IDO contract.
     * @param _samuraiTiers Address of the SamuraiTiers contract for tier verification.
     * @param _usingETH Flag indicating if ETH participation is enabled.
     * @param _usingLinkedWallet Flag indicating if linked wallet verification is enabled.
     * @param _amounts Struct containing initial amounts configuration: token price, max allocations, TGE release percent.
     * @param _periods Struct containing initial periods configuration: registration start, participation start/end, TGE vesting at.
     * @param _ranges Array of structs defining participation ranges for different tiers.
     */
    constructor(
        address _samuraiTiers,
        bool _usingETH,
        bool _usingLinkedWallet,
        IIDO.VestingType _vestingType,
        IIDO.Amounts memory _amounts,
        IIDO.Periods memory _periods,
        IIDO.WalletRange[] memory _ranges
    ) Ownable(msg.sender) {
        require(_samuraiTiers != address(0), IIDO.IIDO__Invalid("Invalid address"));
        require(_amounts.tokenPrice > 0, IIDO.IIDO__Invalid("Token price should be greater than 0"));
        require(_amounts.maxAllocations > 0, IIDO.IIDO__Invalid("Total Max should be greater than 0"));
        require(_amounts.tgeReleasePercent > 0, IIDO.IIDO__Invalid("TGE release percent should be greater than 0"));

        samuraiTiers = _samuraiTiers;
        usingETH = _usingETH;
        usingLinkedWallet = _usingLinkedWallet;
        vestingType = _vestingType;
        setAmounts(_amounts);
        setPeriods(_periods);
        setRanges(_ranges);
    }

    /**
     * @dev Enforces that the contract is configured for ETH participation.
     * This modifier is used on functions that require ETH participation to be enabled.
     */
    modifier whenUsingETH() {
        require(usingETH);
        _;
    }

    /**
     * @dev Enforces that the contract is configured for token participation.
     * This modifier is used on functions that require token participation to be enabled.
     */
    modifier whenUsingToken() {
        require(!usingETH);
        _;
    }

    /**
     * @dev Reverts if the `ranges` array is empty.
     * This modifier is used on functions that require the `ranges` array to be populated.
     */
    modifier rangesNotEmpty() {
        require(ranges.length > 0, IIDO.IIDO__Invalid("Ranges are empty"));
        _;
    }

    /**
     * @dev Enforces that the sender's linked wallet is set if linked wallet verification is enabled.
     * This modifier is used on functions that require a linked wallet for participation.
     */
    modifier linkedWalletChecked() {
        if (usingLinkedWallet) {
            require(bytes(linkedWallets[msg.sender]).length > 0, IIDO.IIDO__Unauthorized("Linked wallet not found"));
        }
        _;
    }

    /**
     * @dev Restricts registration for wallets in allowed tiers based on SamuraiTiers contract.
     * This modifier is used on functions that control the registration process.
     */
    modifier canRegister() {
        ISamuraiTiers.Tier memory walletTier = getWalletTier(msg.sender);
        require(bytes(walletTier.name).length > 0, IIDO.IIDO__Unauthorized("Not allowed to register"));
        _;
    }

    /**
     * @dev Enforces various conditions for claiming unlockable tokens:
     *       - Must be past the vesting period.
     *       - User must have allocated tokens.
     *       - User must not have claimed tokens in the current claim period.
     *       - Must be within the claim period since the user's last claim.
     *       This modifier is used on the `claim` function.
     */
    modifier canClaimTokens() {
        IIDO.Periods memory periodsCopy = periods;
        require(block.timestamp >= periodsCopy.vestingAt, IIDO.IIDO__Unauthorized("Not in vesting phase"));
        require(tokens[msg.sender] > 0, IIDO.IIDO__Unauthorized("No tokens available"));
        require(block.timestamp > lastClaimTimestamps[msg.sender], IIDO.IIDO__Unauthorized("Not allowed"));
        _;
    }

    /**
     * @notice Allows a user to link their wallet address with another address for participation.
     * This function is only callable if linked wallet verification is enabled (`usingLinkedWallet`).
     * @dev This function is non-reentrant and can only be called when the contract is not paused.
     * @param linkedWallet The address to be linked to the user's wallet.
     * emit WalletLinked(msg.sender, linkedWallet) Emitted when a wallet is successfully linked.
     */
    function linkWallet(string memory linkedWallet) external whenNotPaused nonReentrant {
        if (!usingLinkedWallet) {
            revert IIDO.IIDO__Unauthorized("Not using linked wallets");
        }

        require(bytes(linkedWallet).length > 0, IIDO.IIDO__Invalid("Invalid address"));
        linkedWallets[msg.sender] = linkedWallet;
        emit IIDO.WalletLinked(msg.sender, linkedWallet);
    }

    /**
     * @notice Registers a wallet for the whitelist.
     * @dev Can only be called by a non-paused contract, while not in a reentrant call,
     *       by a wallet with a valid tier in SamuraiTiers (not empty tier name),
     *       and only if the wallet is not already whitelisted.
     * emit Whitelisted(wallet) Emitted when a wallet is successfully whitelisted.
     */
    function register() external whenNotPaused rangesNotEmpty canRegister nonReentrant {
        whitelist[msg.sender] = true;
        emit IIDO.Registered(msg.sender);
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
        rangesNotEmpty
        whenUsingToken
        linkedWalletChecked
        nonReentrant
    {
        require(
            block.timestamp >= periods.participationStartsAt && block.timestamp <= periods.participationEndsAt,
            IIDO.IIDO__Unauthorized("Not in participation period")
        );
        require(whitelist[msg.sender] || isPublic, IIDO.IIDO__Unauthorized("Wallet not allowed"));
        require(tokenAddress != address(0), IIDO.IIDO__Invalid("Invalid Token"));
        IIDO.WalletRange memory walletRange = getWalletRange(msg.sender);
        require(amount >= walletRange.min, IIDO.IIDO__Invalid("Amount too low"));
        require(amount <= walletRange.max, IIDO.IIDO__Invalid("Amount too high"));
        require(
            allocations[msg.sender] + amount <= walletRange.max, IIDO.IIDO__Invalid("Exceeds max allocation permitted")
        );

        require(raised + amount <= amounts.maxAllocations, IIDO.IIDO__Invalid("Exceeds max allocations permitted"));

        bool accepted;

        for (uint256 i = 0; i < acceptedTokens.length; i++) {
            if (tokenAddress == acceptedTokens[i]) {
                accepted = true;
                break;
            }
        }

        require(accepted, IIDO.IIDO__Invalid("Token not accepted"));

        allocations[msg.sender] += amount;
        tokens[msg.sender] = tokenAmountByParticipation(allocations[msg.sender]);
        raised += amount;
        emit IIDO.Participated(msg.sender, tokenAddress, amount);

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
        require(
            block.timestamp >= periods.participationStartsAt && block.timestamp <= periods.participationEndsAt,
            IIDO.IIDO__Unauthorized("Not in participation period")
        );
        require(whitelist[msg.sender] || isPublic, IIDO.IIDO__Unauthorized("Wallet not allowed"));
        require(amount > 0, IIDO.IIDO__Unauthorized("Insufficient amount"));
        require(msg.value == amount, IIDO.IIDO__Unauthorized("Insufficient ETH"));

        IIDO.WalletRange memory walletRange = getWalletRange(msg.sender);
        require(amount >= walletRange.min, IIDO.IIDO__Invalid("Amount too low"));
        require(amount <= walletRange.max, IIDO.IIDO__Invalid("Amount too high"));
        require(
            allocations[msg.sender] + amount <= walletRange.max, IIDO.IIDO__Invalid("Exceeds max allocation permitted")
        );

        require(raised + amount <= amounts.maxAllocations, IIDO.IIDO__Invalid("Exceeds max allocations permitted"));

        allocations[msg.sender] += amount;
        tokens[msg.sender] = tokenAmountByParticipation(allocations[msg.sender]);
        raised += amount;
        emit IIDO.Participated(msg.sender, address(0), amount);
    }

    /**
     * @notice Allows users to deposit IDO tokens based on amount raised in participation and token price.
     * @dev This function is used to fill IDO tokens in the contract.
     * emit IDOTokenFilled(msg.sender, amount) Emitted when IDO tokens are deposited.
     */
    function fillIDOToken() external {
        uint256 amount = ud(raised).div(ud(amounts.tokenPrice)).intoUint256();
        ERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit IIDO.IDOTokensFilled(msg.sender, amount);
    }

    /**
     * @notice Allows users to claim their allocated IDO tokens after the TGE vesting period.
     * @dev This function can only be called after the TGE vesting period and if the contract is not paused.
     *       It calculates the claimable amount based on the user's tier and participation.
     * emit Claimed(msg.sender, amount) Emitted when a user successfully claims their IDO tokens.
     */
    function claim() external canClaimTokens nonReentrant {
        uint256 releasedTokens = calculateReleasedTokens(msg.sender);
        require(releasedTokens > 0, IIDO.IIDO__Unauthorized("There is no released tokens available to claim"));

        // Update last claim timestamp based on the release type
        lastClaimTimestamps[msg.sender] =
            block.timestamp - (block.timestamp % getReleaseSchedule(periods.releaseSchedule));
        emit IIDO.Claimed(msg.sender, releasedTokens);

        ERC20(token).safeTransfer(msg.sender, releasedTokens);
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
            require(_acceptedTokens[i] != address(0), IIDO.IIDO__Invalid("Invalid Token"));
            acceptedTokens[i] = _acceptedTokens[i];
        }
        emit IIDO.TokensSet(acceptedTokens);
    }

    /**
     * @notice Allows the contract owner to withdraw the raised funds.
     * @dev This function can only be called by the contract owner and is protected against reentrancy.
     *       The behavior depends on the `usingETH` flag:
     *         - If ETH participation is enabled, it transfers all ETH balance to the owner.
     *         - If ETH participation is disabled, it transfers the balance of each accepted token to the owner.
     */
    function withdraw() external onlyOwner nonReentrant {
        uint256 balance;

        if (usingETH) {
            balance = address(this).balance;
            payable(owner()).transfer(balance); // Transfer ETH directly if usingETH is true
        } else {
            for (uint256 i = 0; i < acceptedTokens.length; i++) {
                uint256 partialBalance = ERC20(acceptedTokens[i]).balanceOf(address(this));
                balance += partialBalance;
                ERC20(acceptedTokens[i]).safeTransfer(owner(), partialBalance);
            }
        }

        emit IIDO.ParticipationsWithdrawal(balance);
    }

    /**
     * @notice Allows the contract owner to withdraw any remaining IDO tokens from the contract.
     * @dev This function can only be called by the contract owner and is protected against reentrancy.
     * It reverts if the IDO token address is invalid or there are no tokens to claim.
     * emit RemainingTokensWithdrawal(balance) Emitted when remaining IDO tokens are withdrawn.
     */
    function withdrawIDOTokens() external onlyOwner nonReentrant {
        require(token != address(0), IIDO.IIDO__Invalid("Invalid Address"));
        uint256 balance = ERC20(token).balanceOf(address(this));
        require(balance > 0, IIDO.IIDO__Unauthorized("Nothing to claim"));

        emit IIDO.RemainingTokensWithdrawal(balance);
        ERC20(token).safeTransfer(owner(), balance);
    }

    /**
     * @notice Opens participation to the public.
     * @dev This function can only be called by the contract owner and is protected against reentrancy.
     *       Setting public participation to true allows anyone to participate without being whitelisted.
     * emit IIDO.PublicAllowed() Emitted when public participation is enabled.
     */
    function makePublic() external onlyOwner nonReentrant {
        isPublic = true;

        emit IIDO.PublicAllowed();
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

    function setAmounts(IIDO.Amounts memory _amounts) public onlyOwner nonReentrant {
        require(_amounts.tokenPrice >= amounts.tokenPrice, IIDO.IIDO__Invalid("Cannot update with a lower tokenPrice"));
        require(
            _amounts.maxAllocations >= amounts.maxAllocations,
            IIDO.IIDO__Invalid("Cannot update with a lower maxAllocations")
        );

        require(
            _amounts.tgeReleasePercent >= amounts.tgeReleasePercent,
            IIDO.IIDO__Invalid("Cannot update with a lower tgeReleasePercent")
        );

        amounts = _amounts;
        emit IIDO.AmountsSet(_amounts);
    }

    /**
     * @notice Allows the contract owner to set the participation ranges for different tiers.
     * @dev This function can only be called by the contract owner and is protected against reentrancy.
     *       It reverts if the provided ranges array is empty or if the first element in the array
     *       does not have the name "Public" (to ensure consistency).
     * @param _ranges An array of `IIDO.WalletRange` structs defining the participation ranges.
     */
    function setRanges(IIDO.WalletRange[] memory _ranges) public onlyOwner nonReentrant {
        require(
            keccak256(abi.encodePacked(_ranges[0].name)) == keccak256(abi.encodePacked("Public")),
            IIDO.IIDO__Invalid("First range must be Public")
        );
        ranges = new IIDO.WalletRange[](_ranges.length);
        for (uint256 i = 0; i < _ranges.length; i++) {
            // all ranges must be validated
            // each range must be greater than i-1
            ranges[i] = _ranges[i];
        }

        emit IIDO.RangesSet(_ranges);
    }

    /**
     * @notice Allows the contract owner to set the different time periods for the IDO process.
     * @dev This function can only be called by the contract owner and is protected against reentrancy.
     *       It performs various validations to ensure proper configuration of periods.
     * @param _periods Struct containing configuration for the IDO periods:
     *                  - registrationAt: Time when registration starts.
     *                  - participationStartsAt: Time when participation starts.
     *                  - participationEndsAt: Time when participation ends.
     *                  - vestingAt: Time when vesting starts.
     *                  - cliff: Cliff period after TGE before vesting starts.
     *                  - releaseType: Type of token release schedule (e.g., cliff and vesting, linear release).
     */
    function setPeriods(IIDO.Periods memory _periods) public onlyOwner nonReentrant {
        require(_periods.registrationAt >= block.timestamp, IIDO.IIDO__Invalid("registrationStartsAt cannot be zero"));

        require(
            _periods.participationStartsAt > _periods.registrationAt,
            IIDO.IIDO__Invalid("participationStartsAt should be higher than registrationEndsAt")
        );

        require(
            _periods.participationEndsAt > _periods.participationStartsAt,
            IIDO.IIDO__Invalid("participationEndsAt should be higher than participationStartsAt")
        );

        IIDO.Periods memory periodsCopy = periods;

        if (periodsCopy.vestingAt > 0) {
            require(
                _periods.vestingAt >= periodsCopy.vestingAt,
                IIDO.IIDO__Invalid("New vestingAt value must be greater or equal current vestingAt value")
            );
            require(
                _periods.vestingAt >= _periods.participationEndsAt,
                IIDO.IIDO__Invalid("vestingAt must be greater or equal than participationEndsAt")
            );
        }

        if (periodsCopy.cliff > 0) {
            require(_periods.cliff >= periodsCopy.cliff, IIDO.IIDO__Invalid("Invalid cliff"));
        }

        if (periodsCopy.releaseSchedule != IIDO.ReleaseSchedule.None) {
            require(
                _periods.releaseSchedule != IIDO.ReleaseSchedule.None,
                IIDO.IIDO__Invalid("Release schedule cannot be None")
            );
        }

        periods = _periods;
        emit IIDO.PeriodsSet(_periods);
    }

    /**
     * @notice Retrieves the participation range applicable to a specific wallet based on their tier.
     * @dev This function is view-only and retrieves the range information from the `SamuraiTiers` contract
     *       using the provided wallet address. It reverts if the tier information for the wallet is not found.
     * @param wallet The address of the wallet to get the participation range for.
     * @return walletRange A struct containing details about the participation range for the provided wallet.
     */
    function getWalletRange(address wallet) public view returns (IIDO.WalletRange memory) {
        ISamuraiTiers.Tier memory tier = getWalletTier(wallet);
        IIDO.WalletRange[] memory _ranges = ranges;

        if (isPublic) return _ranges[0];

        for (uint256 i = 0; i < _ranges.length; i++) {
            if (keccak256(abi.encodePacked(_ranges[i].name)) == keccak256(abi.encodePacked(tier.name))) {
                return _ranges[i];
            }
        }

        return _ranges[0];
    }

    /**
     * @notice Fetches the tier information for a wallet from the `SamuraiTiers` contract.
     * @dev This function is view-only and retrieves the tier details for the provided wallet address
     *       by calling the `getTier` function of the `SamuraiTiers` contract. It reverts if
     *       the tier information cannot be retrieved.
     * @param wallet The address of the wallet to get the tier information for.
     * @return tier A string representing the tier name for the provided wallet.
     */
    function getWalletTier(address wallet) public view returns (ISamuraiTiers.Tier memory) {
        return ISamuraiTiers(samuraiTiers).getTier(wallet);
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
    function getRange(uint256 index) public view returns (IIDO.WalletRange memory) {
        require(index < ranges.length, IIDO.IIDO__Invalid("Invalid range index"));
        return ranges[index];
    }

    /**
     * @notice Calculates the amount of IDO tokens allocated to a wallet at TGE (Token Generation Event).
     * @dev This function is a view function and does not modify contract state.
     * @param wallet The address of the user wallet for whom to calculate TGE tokens.
     * @return tgeAmount The calculated amount of IDO tokens allocated to the wallet at TGE.
     */
    function calculateTGETokens(address wallet) public view returns (uint256) {
        return tokens[wallet] * amounts.tgeReleasePercent / 100;
    }

    /**
     * @notice Calculates the amount of unlockable IDO tokens for a specific wallet.
     * @dev This function is a view function and does not modify contract state.
     *       It considers vesting period, claimed tokens, and allocation amount.
     * @param wallet The address of the user wallet for whom to calculate unlockable tokens.
     * @return releasedTokens The calculated amount of released IDO tokens for the wallet.
     */
    function calculateReleasedTokens(address wallet) public view returns (uint256 releasedTokens) {
        IIDO.Periods memory periodsCopy = periods;
        if (block.timestamp <= periodsCopy.vestingAt) return 0; // Vesting not started
        if (allocations[wallet] == 0) return 0; // Wallet has no allocations

        uint256 userTokensClaimed = tokensClaimed[wallet];
        uint256 userTokensBalance = tokens[wallet];

        // TGE full release vesting
        if (userTokensClaimed == userTokensBalance) return 0;

        uint256 userTokens = hasClaimedTGE[wallet]
            ? userTokensBalance - userTokensClaimed
            : userTokensBalance - calculateTGETokens(wallet) - userTokensClaimed;

        // Cliff Vesting
        if (vestingType == IIDO.VestingType.CliffVesting) {
            releasedTokens = block.timestamp >= periodsCopy.cliff ? userTokens : 0;
        }

        // Linear Vesting
        if (vestingType == IIDO.VestingType.LinearVesting) {
            uint256 userLastClaimTimestamp = lastClaimTimestamps[wallet];
            uint256 elapsedTime =
                block.timestamp - userLastClaimTimestamp > 0 ? userLastClaimTimestamp : periodsCopy.vestingAt;

            // Adjust elapsed time based on release type
            UD60x18 partialReleaseTime = ud(elapsedTime / getReleaseSchedule(periodsCopy.releaseSchedule));

            UD60x18 _100Percent = ud(100);
            // Calculate percentage released (preventing potential overflow)
            UD60x18 percentageReleased = partialReleaseTime.mul(_100Percent).div(ud(block.timestamp));

            releasedTokens = ud(userTokens).mul(percentageReleased).div(_100Percent).intoUint256();
        }

        return releasedTokens;
    }

    /**
     * @notice Converts the release type enum to the corresponding number of seconds.
     * @dev This function is a pure function and does not interact with storage or make external calls.
     * @param _schedule The release type enum value to be converted.
     * @return scheduleTimestamp The number of seconds corresponding to the release type.
     */
    function getReleaseSchedule(IIDO.ReleaseSchedule _schedule) public pure returns (uint256 scheduleTimestamp) {
        if (_schedule == IIDO.ReleaseSchedule.Minute) scheduleTimestamp = 1 minutes;
        else if (_schedule == IIDO.ReleaseSchedule.Day) scheduleTimestamp = 1 days;
        else if (_schedule == IIDO.ReleaseSchedule.Week) scheduleTimestamp = 7 days;
        else if (_schedule == IIDO.ReleaseSchedule.Month) scheduleTimestamp = 30 days;
        else if (_schedule == IIDO.ReleaseSchedule.Year) scheduleTimestamp = 365 days;
    }

    /**
     * @notice Calculates the amount of IDO tokens a user receives based on their participation amount.
     * @dev This function is a view function and does not modify contract state.
     *       It considers the token price and if ETH or ERC20 token is used for participation.
     * @param amount The amount of funds contributed by the user for participation.
     * @return tokensPerAllocation The calculated amount of IDO tokens received per allocation unit.
     */
    function tokenAmountByParticipation(uint256 amount) public view returns (uint256 tokensPerAllocation) {
        tokensPerAllocation = (amount / amounts.tokenPrice) * (usingETH ? 1e18 : 1e6);
    }
}
