// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IVesting} from "./interfaces/IVesting.sol";
import {ISamuraiTiers} from "./interfaces/ISamuraiTiers.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";
import {BokkyPooBahsDateTimeLibrary} from "@BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";
import {console} from "forge-std/console.sol";

contract Vesting is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    uint256 public totalPurchased;
    uint256 public tgeReleasePercent;
    bool public purchasesSet;
    address public token;
    IVesting.VestingType public vestingType;
    IVesting.Periods public periods;
    address[] public walletsToRefund;

    mapping(address wallet => uint256 purchased) public purchases;
    mapping(address wallet => bool tgeClaimed) public hasClaimedTGE;
    mapping(address wallet => uint256 tokens) public tokensClaimed;
    mapping(address wallet => uint256 timestamp) public lastClaimTimestamps;

    /**
     * @notice Sets the initial configuration for the IDO contract.
     * @param _totalPurchased total amount of tokens purchased by users.
     * @param _tgeReleasePercent TGE release percent.
     * @param _periods Struct containing initial periods configuration: registration start, participation start/end, TGE vesting at.
     */
    constructor(
        uint256 _totalPurchased,
        uint256 _tgeReleasePercent,
        IVesting.VestingType _vestingType,
        IVesting.Periods memory _periods
    ) Ownable(msg.sender) {
        require(_tgeReleasePercent > 0, IVesting.IVesting__Invalid("TGE release percent should be greater than 0"));

        totalPurchased = _totalPurchased;
        tgeReleasePercent = _tgeReleasePercent;
        vestingType = _vestingType;
        setPeriods(_periods);
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
        IVesting.Periods memory periodsCopy = periods;
        require(block.timestamp >= periodsCopy.vestingAt, IVesting.IVesting__Unauthorized("Not in vesting phase"));
        require(purchases[msg.sender] > 0, IVesting.IVesting__Unauthorized("No tokens available"));
        require(block.timestamp > lastClaimTimestamps[msg.sender], IVesting.IVesting__Unauthorized("Not allowed"));
        _;
    }

    /**
     * @notice Allows users to deposit IDO tokens based on amount raised in participation and token price.
     * @dev This function is used to fill IDO tokens in the contract.
     * emit IDOTokenFilled(msg.sender, amount) Emitted when IDO tokens are deposited.
     */
    function fillIDOToken(uint256 amount) external {
        require(token != address(0), IVesting.IVesting__Unauthorized("IDO token not set"));
        require(totalPurchased > 0, IVesting.IVesting__Unauthorized("No purchases"));

        require(
            ERC20(token).balanceOf(address(this)) + amount <= totalPurchased,
            IVesting.IVesting__Unauthorized("Unable to receive more IDO tokens")
        );

        ERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        emit IVesting.TokensFilled(msg.sender, amount);
    }

    /**
     * @notice Allows users to claim their allocated IDO tokens after the TGE vesting period.
     * @dev This function can only be called after the TGE vesting period and if the contract is not paused.
     * It calculates the claimable amount based on the user's tier and participation.
     * emit Claimed(msg.sender, amount) Emitted when a user successfully claims their IDO tokens.
     */
    function claim() external canClaimTokens nonReentrant {
        uint256 claimable = previewClaimableTokens(msg.sender);
        require(claimable > 0, IVesting.IVesting__Unauthorized("There is no vested tokens available to claim"));

        if (!hasClaimedTGE[msg.sender]) hasClaimedTGE[msg.sender] = true;

        // Update claimed tokens by user
        tokensClaimed[msg.sender] += claimable;

        // Update last claim timestamp based on the release type
        lastClaimTimestamps[msg.sender] = block.timestamp;
        emit IVesting.Claimed(msg.sender, claimable);

        ERC20(token).safeTransfer(msg.sender, claimable);
    }

    /**
     * @notice Sets the IDO token address.
     * @dev Only the owner can call this function. Sets the `token` address to the provided `_token` address.
     *  Reverts if the token address is already set.
     *
     * Emits:
     *  IDOTokenSet(address indexed newToken)
     *
     * Requirements:
     *  - The caller must be the owner.
     *  - The token address must be zero.
     *
     * Parameters:
     *  _token: The new IDO token address.
     */
    function setIDOToken(address _token) external onlyOwner nonReentrant {
        require(token == address(0), IVesting.IVesting__Unauthorized("Token already set"));
        token = _token;

        emit IVesting.IDOTokenSet(_token);
    }

    /**
     * @notice Alows owner to set the list of wallets and it's purchases to be vested based on contract strategy
     * @param wallets list of wallets
     * @param tokensPurchased list of amounts of tokens purchased
     */
    function setAllPurchases(address[] calldata wallets, uint256[] calldata tokensPurchased)
        external
        onlyOwner
        nonReentrant
    {
        require(
            wallets.length == tokensPurchased.length,
            IVesting.IVesting__Unauthorized("wallets and tokensPurchased should have same size length")
        );
        require(!purchasesSet, IVesting.IVesting__Unauthorized("Purchases already set"));

        for (uint256 i = 0; i < wallets.length; i++) {
            require(wallets[i] != address(0), IVesting.IVesting__Invalid("Invalid address"));
            require(tokensPurchased[i] > 0, IVesting.IVesting__Invalid("Invalid amount permitted"));

            address wallet = wallets[i];

            purchases[wallet] = tokensPurchased[i];
        }

        purchasesSet = true;
        emit IVesting.PurchasesSet(wallets, tokensPurchased);
    }

    /**
     * @notice Allows the contract owner to withdraw remaining IDO tokens of a specific wallet.
     * This feature is designed to help participators with problems in it's wallets.
     * @dev This function can only be called by the contract owner and is protected against reentrancy.
     * It reverts if the IDO token address is not set or there are no tokens to claim.
     * emit Claimed(wallet, balance) Emitted when remaining IDO tokens are withdrawn.
     */
    function emergencyWithdrawByWallet(address wallet) external onlyOwner nonReentrant {
        require(token != address(0), IVesting.IVesting__Unauthorized("Token not set"));
        require(block.timestamp > vestingEndsAt(), IVesting.IVesting__Unauthorized("Vesting is ongoing"));

        uint256 allocation = purchases[wallet];
        require(allocation > 0, IVesting.IVesting__Unauthorized("Wallet has no allocation"));

        tokensClaimed[wallet] = allocation;

        uint256 claimable = previewClaimableTokens(wallet);
        emit IVesting.Claimed(wallet, claimable);

        ERC20(token).safeTransfer(owner(), claimable);
    }

    /**
     * @notice Allows the contract owner to withdraw remaining IDO tokens.
     * This feature is designed to help with problems and edge cases.
     * @dev This function can only be called by the contract owner and is protected against reentrancy.
     * It reverts if the IDO token address is not set or there are no tokens to withdraw.
     * emit RemainingTokensWithdrawal(balance) Emitted when remaining IDO tokens are withdrawn.
     */
    function emergencyWithdraw() external onlyOwner nonReentrant {
        require(token != address(0), IVesting.IVesting__Unauthorized("Token not set"));
        uint256 balance = ERC20(token).balanceOf(address(this));
        require(balance > 0, IVesting.IVesting__Unauthorized("Nothing to withdraw"));

        ERC20(token).safeTransfer(owner(), balance);
        emit IVesting.RemainingTokensWithdrawal(balance);
    }

    function askForRefund() external nonReentrant {
        require(!hasClaimedTGE[msg.sender], IVesting.IVesting__Unauthorized("Not refundable"));

        walletsToRefund.push(msg.sender);
        emit IVesting.NeedRefund(walletsToRefund);
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
    function setPeriods(IVesting.Periods memory _periods) public onlyOwner nonReentrant {
        IVesting.Periods memory periodsCopy = periods;

        /// When vestingDuration is already set
        /// New vestingDuration must be greater or equal than current vestingDuration
        if (periodsCopy.vestingDuration > 0) {
            require(
                _periods.vestingDuration >= periodsCopy.vestingDuration,
                IVesting.IVesting__Invalid("New vestingDuration must be greater or equal than vestingDuration")
            );
        }

        /// When vestingAt is already set
        /// New vestingAt must be greater or equal than current vestingAt
        /// New vestingAt must be greater or equal new participationEndsAt
        if (periodsCopy.vestingAt > 0) {
            require(
                _periods.vestingAt >= periodsCopy.vestingAt,
                IVesting.IVesting__Invalid("New vestingAt value must be greater or equal current vestingAt value")
            );
        }

        if (periodsCopy.cliff > 0) {
            require(_periods.cliff >= periodsCopy.cliff, IVesting.IVesting__Invalid("Invalid cliff"));
        }

        periods = _periods;
        emit IVesting.PeriodsSet(_periods);
    }

    /**
     * @notice Calculates the amount of IDO tokens allocated to a wallet at TGE (Token Generation Event).
     * @dev This function is a view function and does not modify contract state.
     * @param wallet The address of the user wallet for whom to calculate TGE tokens.
     * @return tgeAmount The calculated amount of IDO tokens allocated to the wallet at TGE.
     */
    function previewTGETokens(address wallet) public view returns (uint256) {
        return _calculateTGETokens(wallet).intoUint256();
    }

    /**
     * @notice Previews the total amount of vested tokens.
     * @dev Calculates the total amount of vested tokens based on the current block timestamp.
     *
     * @return vestedTokens The total amount of vested tokens.
     */
    function previewVestedTokens() public view returns (uint256) {
        return _calculateVestedTokens().intoUint256();
    }

    /**
     * @notice Previews the claimable tokens for a given wallet.
     * @dev Calculates the total amount of vested tokens for the specified wallet.
     *
     * @param wallet The wallet address to calculate claimable tokens for.
     * @return claimableTokens The total amount of claimable tokens for the wallet.
     */
    function previewClaimableTokens(address wallet) public view returns (uint256) {
        return _calculateVestedByWallet(wallet).intoUint256();
    }

    /**
     * @notice Calculates the cliff end timestamp for the IDO.
     * @dev This function calculates the cliff end timestamp by adding the cliff duration to the vesting start time.
     * @return The timestamp representing the end of the cliff period (uint256).
     */
    function cliffEndsAt() public view returns (uint256) {
        IVesting.Periods memory periodsCopy = periods;
        // return _periods.vestingAt + _periods.cliff;
        return BokkyPooBahsDateTimeLibrary.addMonths(periodsCopy.vestingAt, periodsCopy.cliff);
    }

    /**
     * @notice Returns the timestamp when vesting ends.
     * @dev Calculates the vesting end timestamp by adding the vesting duration to the cliff end timestamp.
     *
     * @return The timestamp when vesting ends.
     */
    function vestingEndsAt() public view returns (uint256) {
        IVesting.Periods memory periodsCopy = periods;
        // return cliffEndsAt() + periodsCopy.vestingDuration;
        return BokkyPooBahsDateTimeLibrary.addMonths(cliffEndsAt(), periodsCopy.vestingDuration);
    }

    function getWalletsToRefund() public view returns (address[] memory) {
        return walletsToRefund;
    }

    /**
     * @notice Calculates the amount of tokens allocated for TGE distribution.
     * @dev This function calculates the amount of tokens a participant receives during the TGE (Token Generation Event).
     *      Returns zero if the IDO token address is not set.
     * @param wallet The participant's wallet address (address).
     * @return The allocated TGE token amount (UD60x18).
     */
    function _calculateTGETokens(address wallet) private view returns (UD60x18) {
        if (token == address(0)) return convert(0);

        UD60x18 tokens = ud(purchases[wallet]);
        return tokens.mul(ud(tgeReleasePercent));
    }

    /**
     * @notice Calculates the amount of tokens allocated for TGE distribution.
     * @dev This function calculates the amount of tokens vested based on the vesting duration.
     * @return The total amount of vested tokens (UD60x18).
     */
    function _calculateVestedTokens() private view returns (UD60x18) {
        UD60x18 zero = convert(0);
        if (token == address(0)) return zero; // Token not set
        if (totalPurchased == 0) return zero; // Nothing raised

        IVesting.Periods memory periodsCopy = periods;
        if (periodsCopy.vestingAt == 0) return zero; // Vesting period not defined
        if (block.timestamp < periodsCopy.vestingAt) return zero; // Vesting not started

        /// IN VESTING PERIOD ======================================================
        UD60x18 maxOfTokens = ud(totalPurchased);
        UD60x18 tgeAmount = maxOfTokens.mul(ud(tgeReleasePercent)); // use ud because percent is already in 18 decimals
        UD60x18 maxOfTokensForVesting = maxOfTokens.sub(tgeAmount);

        uint256 _cliffEndsAt = cliffEndsAt();

        /// IN CLIFF PERIOD ========================================================
        /// Only TGE is unlocked before cliff ends =================================
        if (block.timestamp <= _cliffEndsAt) return tgeAmount;

        if (vestingType == IVesting.VestingType.CliffVesting) {
            /// CLIFF VESTING  =====================================================
            return maxOfTokens;
        } else {
            uint256 _vestingEndsAt = vestingEndsAt();

            /// Vest only TGE amount at first second of vesting period =============
            if (block.timestamp == periodsCopy.vestingAt) return tgeAmount;

            /// All tokens were vested =============================================
            if (block.timestamp > _vestingEndsAt) return maxOfTokens;

            UD60x18 vestedAmount;

            if (vestingType == IVesting.VestingType.LinearVesting) {
                /// LINEAR VESTING =================================================

                UD60x18 duration = convert(getDiffByPeriodType(_cliffEndsAt, _vestingEndsAt, IVesting.PeriodType.Days));
                UD60x18 elapsedTime = convert(block.timestamp - _cliffEndsAt);
                UD60x18 tokensPerSec = maxOfTokensForVesting.div(duration);
                vestedAmount = tgeAmount.add(tokensPerSec.mul(elapsedTime));
            } else if (vestingType == IVesting.VestingType.PeriodicVesting) {
                /// PERIODC VESTING ================================================

                UD60x18 totalMonths =
                    convert(getDiffByPeriodType(_cliffEndsAt, _vestingEndsAt, IVesting.PeriodType.Month));
                UD60x18 elapsedMonths =
                    convert(getDiffByPeriodType(_cliffEndsAt, block.timestamp, IVesting.PeriodType.Month));

                UD60x18 tokensPerMonth = maxOfTokensForVesting.div(totalMonths);
                UD60x18 vested = tokensPerMonth.mul(elapsedMonths);
                vestedAmount = tgeAmount.add(vested);
            }

            return vestedAmount;
        }
    }

    /**
     * @notice Calculates the amount of tokens available for a specific wallet.
     * @dev This function calculates the amount of tokens a participant can claim at the moment.
     * @param wallet The participant's wallet address (address).
     * @return The available tokens amount (UD60x18).
     */
    function _calculateVestedByWallet(address wallet) private view returns (UD60x18) {
        UD60x18 zero = convert(0);
        IVesting.Periods memory periodsCopy = periods;

        if (periodsCopy.vestingAt == 0) return zero; // Vesting period not defined
        if (block.timestamp < periodsCopy.vestingAt) return zero; // Vesting not started
        if (purchases[wallet] == 0) return zero; // Wallet has no purchases

        UD60x18 max = ud(purchases[wallet]);
        UD60x18 claimed = ud(tokensClaimed[wallet]);

        /// User already claimed all tokens vested
        if (claimed == max) return zero;

        uint256 _cliffEndsAt = cliffEndsAt();
        bool isTgeClaimed = hasClaimedTGE[wallet];

        /// Only TGE is vested during cliff period
        if (block.timestamp <= _cliffEndsAt) return isTgeClaimed ? zero : _calculateTGETokens(wallet);

        UD60x18 balance = max.sub(claimed);

        /// All tokens were vested -> return all balance remaining
        if (block.timestamp > vestingEndsAt()) return balance;

        /// CALCS  ================================================

        /// CLIFF VESTING
        if (vestingType == IVesting.VestingType.CliffVesting) return balance;

        /// LINEAR VESTING & PERIODIC VESTING
        UD60x18 total = ud(totalPurchased);
        UD60x18 vested = _calculateVestedTokens();
        UD60x18 totalVestedPercentage = vested.mul(convert(100)).div(total);
        UD60x18 walletSharePercentage = max.mul(convert(100)).div(total);
        UD60x18 walletVestedPercentage = walletSharePercentage.mul(totalVestedPercentage).div(convert(100));
        UD60x18 walletVested = total.mul(walletVestedPercentage).div(convert(100));
        UD60x18 walletClaimable = walletVested.sub(claimed);

        return walletClaimable;
    }

    /**
     * @dev Calculates the time difference between two timestamps based on a given period type.
     *
     * @param start The start timestamp.
     * @param end The end timestamp.
     * @param periodType The period type (days or months).
     * @return The calculated time difference in seconds (for days) or months.
     */
    function getDiffByPeriodType(uint256 start, uint256 end, IVesting.PeriodType periodType)
        private
        pure
        returns (uint256)
    {
        if (periodType == IVesting.PeriodType.Days) {
            // return number of days times seconds per day
            // eg: 2 * 86400 = number of days in secondss
            return BokkyPooBahsDateTimeLibrary.diffDays(start, end) * 86400;
        }

        // return number of months
        // eg 2 or 8
        return BokkyPooBahsDateTimeLibrary.diffMonths(start, end);
    }
}
