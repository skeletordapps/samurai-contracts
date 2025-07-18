// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IVesting} from "./interfaces/IVesting.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";
import {BokkyPooBahsDateTimeLibrary} from "@BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";
import {IPoints} from "./interfaces/IPoints.sol";

// aderyn-ignore-next-line(centralization-risk)
contract Vesting is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    uint256 public immutable tgeReleasePercent;
    uint256 public immutable pointsPerToken;
    address public immutable token;
    address public immutable points;
    IVesting.VestingType public immutable vestingType;
    IVesting.PeriodType public immutable vestingPeriodType;
    bool public immutable isRefundable;

    uint256 public refundPeriod;
    uint256 public totalPurchased;
    uint256 public totalClaimed;
    uint256 public totalPoints;
    uint256 public totalPointsClaimed;
    uint256 public totalToRefund;

    IVesting.Periods public periods;
    address[] public walletsToRefund;

    mapping(address wallet => uint256 purchased) public purchases;
    mapping(address wallet => bool tgeClaimed) public hasClaimedTGE;
    mapping(address wallet => uint256 tokens) public tokensClaimed;
    mapping(address wallet => uint256 timestamp) public lastClaimTimestamps;
    mapping(address wallet => bool askedRefund) public askedRefund;
    mapping(address wallet => uint256 claimed) public pointsClaimed;

    /**
     * @notice Sets the initial configuration for the IDO contract.
     * @dev Reverts if the token address is invalid, total purchased is zero, TGE release percent is zero or vesting type is invalid.
     * @param _token IDO token address.
     * @param _points Samurai Points token address.
     * @param _tgeReleasePercent TGE release percent.
     * @param _pointsPerToken amount of points per token purchased
     * @param _vestingType Type of vesting schedule.
     * @param _vestingPeriodType Type of vesting unlocks
     * @param _periods Struct containing initial periods configuration: registration start, participation start/end, TGE vesting at.
     * @param _wallets List of wallets addresses.
     * @param _tokensPurchased List of tokens purchased by wallets.
     */
    constructor(
        address _token,
        address _points,
        uint256 _tgeReleasePercent,
        uint256 _pointsPerToken,
        uint256 _refundPeriod,
        bool _isRefundable,
        IVesting.VestingType _vestingType,
        IVesting.PeriodType _vestingPeriodType,
        IVesting.Periods memory _periods,
        address[] memory _wallets,
        uint256[] memory _tokensPurchased
    ) Ownable(msg.sender) {
        require(_token != address(0), IVesting.IVesting__Unauthorized("Invalid address"));
        require(_points != address(0), IVesting.IVesting__Unauthorized("Invalid address"));
        require(uint256(_vestingType) < 3, IVesting.IVesting__Invalid("Invalid vesting type"));
        require(uint256(_vestingPeriodType) < 5, IVesting.IVesting__Invalid("Invalid vesting period type"));

        token = _token;
        points = _points;
        tgeReleasePercent = _tgeReleasePercent; // this can be zero
        pointsPerToken = _pointsPerToken;
        refundPeriod = _refundPeriod; // 48 hours
        isRefundable = _isRefundable;
        vestingType = _vestingType;
        vestingPeriodType = _vestingPeriodType;
        _setPeriods(_periods);
        _setPurchases(_wallets, _tokensPurchased);
    }

    /**
     * @dev Enforces various conditions for claiming unlockable tokens:
     *       - Must be past the vesting period.
     *       - User must have allocated tokens.
     *       - User must not have claimed tokens in the current claim period.
     *       - Must be within the claim period since the user's last claim.
     *       This modifier is used on the `claim` function.
     */
    modifier canClaim() {
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
    // aderyn-ignore-next-line(eth-send-unchecked-address)
    function fillIDOToken(uint256 amount) external nonReentrant whenNotPaused {
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
     * It calculates the claimable amount based on the user's purchase.
     * emit Claimed(msg.sender, amount) Emitted when a user successfully claims their IDO tokens.
     */
    // aderyn-ignore-next-line(eth-send-unchecked-address)
    function claim() external nonReentrant canClaim whenNotPaused {
        uint256 claimable = previewClaimableTokens(msg.sender);
        require(claimable > 0, IVesting.IVesting__Unauthorized("There is no vested tokens available to claim"));
        require(
            totalClaimed + claimable <= totalPurchased,
            IVesting.IVesting__Unauthorized("Exceeds total amount purchased")
        );

        if (!hasClaimedTGE[msg.sender]) hasClaimedTGE[msg.sender] = true;

        // Update claimed tokens by user
        tokensClaimed[msg.sender] += claimable;

        // Update overal claimed tokens
        totalClaimed += claimable;

        // Update last claim timestamp based on the release type
        lastClaimTimestamps[msg.sender] = block.timestamp;
        emit IVesting.Claimed(msg.sender, claimable);

        ERC20(token).safeTransfer(msg.sender, claimable);
    }

    /**
     * @notice Allows users to claim Samurai Points.
     * @dev This function can only be called after the TGE vesting period and if the contract is not paused.
     * It calculates the claimable amount of points based on the user's purchase.
     * emit PointsClaimed(msg.sender, amount) Emitted when a user successfully claims their points.
     */
    function claimPoints() external nonReentrant canClaim whenNotPaused {
        uint256 pointsToClaim = previewClaimablePoints(msg.sender);
        require(pointsToClaim > 0, IVesting.IVesting__Unauthorized("Nothing to claim"));

        pointsClaimed[msg.sender] = pointsToClaim;
        totalPointsClaimed += pointsToClaim;
        emit IVesting.PointsClaimed(msg.sender, pointsToClaim);

        IPoints(points).mint(msg.sender, pointsToClaim);
    }

    /**
     * @notice Allows the contract owner to withdraw remaining IDO tokens of a specific wallet.
     * This feature is designed to help participators with problems in it's wallets.
     * @dev This function can only be called by the contract owner and is protected against reentrancy.
     * emit Claimed(wallet, balance) Emitted when remaining IDO tokens are withdrawn.
     */
    // aderyn-ignore-next-line(centralization-risk)
    function emergencyWithdrawByWallet(address wallet) external nonReentrant onlyOwner whenNotPaused {
        require(block.timestamp > vestingEndsAt(), IVesting.IVesting__Unauthorized("Vesting is ongoing"));

        uint256 allocation = purchases[wallet];
        require(allocation > 0, IVesting.IVesting__Unauthorized("Wallet has no allocation"));

        uint256 claimable = previewClaimableTokens(wallet);
        tokensClaimed[wallet] = allocation;
        emit IVesting.Claimed(wallet, claimable);

        ERC20(token).safeTransfer(wallet, claimable);
    }

    /**
     * @notice Allows the contract owner to withdraw remaining IDO tokens.
     * This feature is designed to help with problems and edge cases.
     * @dev This function can only be called by the contract owner and is protected against reentrancy.
     * It reverts if there are no tokens to withdraw.
     * emit RemainingTokensWithdrawal(balance) Emitted when remaining IDO tokens are withdrawn.
     */
    // aderyn-ignore-next-line(centralization-risk)
    function emergencyWithdraw() external nonReentrant onlyOwner {
        uint256 balance = ERC20(token).balanceOf(address(this));
        require(balance > 0, IVesting.IVesting__Unauthorized("Nothing to withdraw"));

        ERC20(token).safeTransfer(owner(), balance);
        emit IVesting.RemainingTokensWithdrawal(balance);
    }

    /**
     * @notice Allows the contract owner to withdraw project tokens to be refundable.
     * @dev This function can only be called by the contract owner and is protected against reentrancy.
     * It reverts if there are no refundable tokens to withdraw.
     * emit RefundsWidrawal(balance) Emitted when refundable tokens are withdrawn.
     */
    // aderyn-ignore-next-line(centralization-risk)
    function withdrawRefunds() external nonReentrant onlyOwner {
        uint256 totalToRefundCopy = totalToRefund;
        require(totalToRefundCopy > 0, IVesting.IVesting__Unauthorized("Nothing to withdraw"));

        totalToRefund = 0;
        emit IVesting.RefundsWidrawal(msg.sender, totalToRefundCopy);

        ERC20(token).safeTransfer(owner(), totalToRefundCopy);
    }

    /**
     * @notice Allows the contract owner to update the refund period.
     * @dev This function can only be called by the contract owner and is protected against reentrancy.
     * It reverts if _refundPeriod is equal or lower than refundPeriod.
     * emit RefundsWidrawal(balance) Emitted when refundable tokens are withdrawn.
     */
    // aderyn-ignore-next-line(centralization-risk)
    function setRefundPeriod(uint256 _refundPeriod) external nonReentrant onlyOwner {
        require(_refundPeriod > refundPeriod, IVesting.IVesting__Invalid("New period must be greater than current"));

        refundPeriod = _refundPeriod;
        emit IVesting.RefundPeriodSet(_refundPeriod);
    }

    /**
     * @notice Allows the contract to update IVesting.Periods uint256 vestingAt - TGE date.
     * @dev This function can only be called by the contract owner and is protected against reentrancy.
     * @param timestamp uint256 - new TGE date.
     */
    // aderyn-ignore-next-line(centralization-risk)
    function updateVestingAt(uint256 timestamp) external nonReentrant onlyOwner {
        require(timestamp > 0, IVesting.IVesting__Invalid("Invalid vestingAt"));

        // When vestingAt is already set by constructor
        if (periods.vestingAt > 0) {
            // Current block.timestamp must be lower than actual vestingAt timestamp
            require(block.timestamp < periods.vestingAt, IVesting.IVesting__Unauthorized("Vesting is ongoing"));
            // New timestamp should be greater than current
            require(
                periods.vestingAt < timestamp, IVesting.IVesting__Unauthorized("Not allowed to decrease vesting date")
            );
        }

        periods.vestingAt = timestamp;
        emit IVesting.VestingAtUpdated(timestamp);
    }

    /**
     * @notice Allows a wallet to ask for a refund.
     * @dev This function can only be called by the contract owner and is protected against reentrancy.
     * It reverts if refunding period has passed.
     * It reverts if wallet claimed tge.
     * It reverts if wallet claimed points.
     * emit NeedRefund(balance).
     */
    function askForRefund() external nonReentrant whenNotPaused {
        require(isRefundable, IVesting.IVesting__Unauthorized("Not refundable"));
        require(block.timestamp <= periods.vestingAt + refundPeriod, IVesting.IVesting__Unauthorized("Not refundable"));
        require(!hasClaimedTGE[msg.sender], IVesting.IVesting__Unauthorized("Not refundable"));
        require(pointsClaimed[msg.sender] == 0, IVesting.IVesting__Unauthorized("Not refundable"));

        askedRefund[msg.sender] = true;
        walletsToRefund.push(msg.sender);
        totalToRefund += purchases[msg.sender];
        emit IVesting.NeedRefund(walletsToRefund);
    }

    /**
     * @dev Pauses all token transfers.
     * Can only be called by the contract owner.
     */
    // aderyn-ignore-next-line(centralization-risk)
    function pause() external onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses token transfers.
     * Can only be called by the contract owner.
     */
    // aderyn-ignore-next-line(centralization-risk)
    function unpause() external onlyOwner {
        _unpause();
    }

    /**
     * @notice Calculates the amount of IDO tokens allocated to a wallet at TGE (Token Generation Event).
     * @dev This function is a view function and does not modify contract state.
     * @param wallet The address of the user wallet for whom to calculate TGE tokens.
     * @return tgeAmount The calculated amount of IDO tokens allocated to the wallet at TGE.
     */
    function previewTGETokens(address wallet) external view returns (uint256) {
        return _calculateTGETokens(wallet).intoUint256();
    }

    /**
     * @notice Previews the total amount of vested tokens.
     * @dev Calculates the total amount of vested tokens based on the current block timestamp.
     *
     * @return vestedTokens The total amount of vested tokens.
     */
    function previewVestedTokens() external view returns (uint256) {
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
     * @notice Previews the claimable points for a given wallet.
     * @dev Calculates the total amount of Samurai Points tokens for the specified wallet.
     *      - Wallets must had purchased IDO tokens
     *      - Wallets to be refunded cannot get any Samurai Point
     *      - Points are claimed only once after vesting starts
     *
     * @param wallet The wallet address to calculate claimable tokens for.
     * @return claimablePoints The total amount of claimable points for the wallet.
     */
    function previewClaimablePoints(address wallet) public view returns (uint256) {
        uint256 purchased = purchases[wallet];
        if (purchased == 0 || askedRefund[wallet] || pointsClaimed[wallet] > 0) {
            return 0;
        }

        uint256 boost = IPoints(points).boostOf(wallet);

        // Step 1: base points = purchased * pointsPerToken
        UD60x18 base = ud(purchased).mul(ud(pointsPerToken));

        // Step 2: boost amount = base * boost
        UD60x18 bonus = base.mul(ud(boost));

        // Step 3: total = base + bonus
        UD60x18 total = base.add(bonus);

        return total.intoUint256();
    }

    /**
     * @notice Calculates the cliff end timestamp for the IDO.
     * @dev This function calculates the cliff end timestamp by adding the cliff duration to the vesting start time.
     * @return The timestamp representing the end of the cliff period (uint256).
     */
    function cliffEndsAt() public view returns (uint256) {
        IVesting.Periods memory periodsCopy = periods;
        return BokkyPooBahsDateTimeLibrary.addMonths(periodsCopy.vestingAt, periodsCopy.cliff);
    }

    /**
     * @notice Returns the timestamp when vesting ends.
     * @dev Calculates the vesting end timestamp by adding the vesting duration to the cliff end timestamp.
     *
     * @return The timestamp when vesting ends.
     */
    function vestingEndsAt() public view returns (uint256) {
        return BokkyPooBahsDateTimeLibrary.addMonths(cliffEndsAt(), periods.vestingDuration);
    }

    /**
     * @notice Returns a list of addressess to be refunded.
     * @return address[].
     */
    function getWalletsToRefund() external view returns (address[] memory) {
        return walletsToRefund;
    }

    /**
     * @notice Calculates the amount of tokens allocated for TGE distribution.
     * @dev This function calculates the amount of tokens a participant receives during the TGE (Token Generation Event).
     * @param wallet The participant's wallet address (address).
     * @return The allocated TGE token amount (UD60x18).
     */
    function _calculateTGETokens(address wallet) private view returns (UD60x18) {
        if (tgeReleasePercent == 0) return convert(0);
        return ud(purchases[wallet]).mul(ud(tgeReleasePercent));
    }

    /**
     * @notice Allows the contract set the different time periods for the IDO process.
     * @dev This function can only be called by the contract constructor function.
     * @param _periods Struct containing configuration for the IDO periods:
     *                  - vestingDuration: Time when participation ends.
     *                  - vestingAt: Time when vesting starts.
     *                  - cliff: Cliff period after TGE before vesting starts.
     */
    function _setPeriods(IVesting.Periods memory _periods) private {
        require(_periods.vestingAt > 0, IVesting.IVesting__Invalid("Invalid vestingAt"));
        require(block.timestamp < _periods.vestingAt, IVesting.IVesting__Invalid("Invalid vestingAt"));

        periods = _periods;
        emit IVesting.PeriodsSet(_periods);
    }

    /**
     * @notice Alows contract to set the list of wallets and it's purchases to be vested based on contract strategy
     * @param wallets list of wallets
     * @param tokensPurchased list of amounts of tokens purchased
     * @dev This function also sets totalPurchased and totalPoints
     */
    function _setPurchases(address[] memory wallets, uint256[] memory tokensPurchased) private nonReentrant {
        require(wallets.length > 0, "wallets cannot be empty");
        require(
            wallets.length == tokensPurchased.length,
            IVesting.IVesting__Unauthorized("wallets and tokensPurchased should have same size length")
        );

        uint256 _totalPurchased;

        for (uint256 i = 0; i < wallets.length; i++) {
            require(wallets[i] != address(0), IVesting.IVesting__Invalid("Invalid address"));
            require(tokensPurchased[i] > 0, IVesting.IVesting__Invalid("Invalid amount permitted"));

            address wallet = wallets[i];

            purchases[wallet] = tokensPurchased[i];
            _totalPurchased += tokensPurchased[i];
        }

        totalPurchased = _totalPurchased; // Total amount of IDO tokens purchased
        totalPoints = ud(_totalPurchased).mul(ud(pointsPerToken)).intoUint256();
        emit IVesting.PurchasesSet(wallets, tokensPurchased);
    }

    /**
     * @notice Calculates the amount of tokens allocated for TGE distribution.
     * @dev This function calculates the amount of tokens vested based on the vesting duration.
     * @return The total amount of vested tokens (UD60x18).
     */
    function _calculateVestedTokens() private view returns (UD60x18) {
        UD60x18 zero = convert(0);

        IVesting.Periods memory periodsCopy = periods;
        if (block.timestamp < periodsCopy.vestingAt) return zero; // Vesting not started

        /// IN VESTING PERIOD ======================================================
        UD60x18 maxOfTokens = ud(totalPurchased);

        // tgeReleasePercent can be equal or higher than 0
        // use ud because percent is already in 18 decimals
        UD60x18 tgeAmount = tgeReleasePercent > 0 ? maxOfTokens.mul(ud(tgeReleasePercent)) : zero;
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

                UD60x18 duration =
                    convert(_getDiffByPeriodType(_cliffEndsAt, _vestingEndsAt, IVesting.PeriodType.Seconds));
                UD60x18 elapsedTime = convert(block.timestamp - _cliffEndsAt);
                UD60x18 tokensPerSec = maxOfTokensForVesting.div(duration);
                vestedAmount = tokensPerSec.mul(elapsedTime).add(tgeAmount);
            } else if (vestingType == IVesting.VestingType.PeriodicVesting) {
                /// PERIODC VESTING ================================================

                IVesting.PeriodType vestingPeriodTypeCopy = vestingPeriodType;
                UD60x18 totalForPeriod =
                    convert(_getDiffByPeriodType(_cliffEndsAt, _vestingEndsAt, vestingPeriodTypeCopy));
                UD60x18 elapsedPeriod =
                    convert(_getDiffByPeriodType(_cliffEndsAt, block.timestamp, vestingPeriodTypeCopy));

                UD60x18 tokensForPeriod = maxOfTokensForVesting.div(totalForPeriod);
                UD60x18 vested = tokensForPeriod.mul(elapsedPeriod);
                vestedAmount = vested.add(tgeAmount);
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

        if (block.timestamp < periods.vestingAt) return zero;
        if (purchases[wallet] == 0) return zero;
        if (askedRefund[wallet]) return zero;

        UD60x18 purchased = ud(purchases[wallet]);
        UD60x18 claimed = ud(tokensClaimed[wallet]);

        if (claimed >= purchased) return zero;

        // Calculate total vested tokens
        UD60x18 totalVested = _calculateVestedTokens();

        // Direct proportion calculation to avoid multiple ones
        UD60x18 walletVested = totalVested.mul(purchased).div(ud(totalPurchased));

        // more safety
        if (walletVested > purchased) walletVested = purchased;
        if (walletVested <= claimed) return zero;

        return walletVested.sub(claimed);
    }

    /**
     * @dev Calculates the time difference between two timestamps based on a given period type.
     *
     * @param start The start timestamp.
     * @param end The end timestamp.
     * @param periodType The period type (days, weeks or months).
     * @return The calculated time difference in seconds (for days) or months.
     */
    function _getDiffByPeriodType(uint256 start, uint256 end, IVesting.PeriodType periodType)
        private
        pure
        returns (uint256)
    {
        if (periodType == IVesting.PeriodType.Seconds) {
            // return number of days in seconds
            // eg: 2 * 86400 = number of days in secondss
            return BokkyPooBahsDateTimeLibrary.diffDays(start, end) * 86_400;
        } else if (periodType == IVesting.PeriodType.Days) {
            // return number of days
            return BokkyPooBahsDateTimeLibrary.diffDays(start, end);
        } else if (periodType == IVesting.PeriodType.Weeks) {
            // return number of weeks
            uint256 estimatedDays = BokkyPooBahsDateTimeLibrary.diffDays(start, end);
            uint256 estimatedWeeks = estimatedDays / 7; // Round down to the nearest week
            return estimatedWeeks;
        } else {
            // return number of months
            // eg 2 or 8
            return BokkyPooBahsDateTimeLibrary.diffMonths(start, end);
        }
    }
}
