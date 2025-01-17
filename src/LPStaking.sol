//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/console.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";
import {ILPStaking} from "./interfaces/ILPStaking.sol";
import {IPoints} from "./interfaces/IPoints.sol";
import {IGauge} from "./interfaces/IGauge.sol";

contract LPStaking is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    uint256 public constant MAX_STAKES_PER_WALLET = 5; // Maximum number of stakes per wallet
    uint256 public constant MAX_AMOUNT_TO_STAKE = 10_000 ether; // 10,000 LP tokens
    uint256 public constant CLAIM_DELAY_PERIOD = 5 minutes; // 5 minutes

    // Define stake periods (in seconds)
    uint256 public constant THREE_MONTHS = 3 * 30 days; // 3 months
    uint256 public constant SIX_MONTHS = 6 * 30 days; // 6 months
    uint256 public constant NINE_MONTHS = 9 * 30 days; // 9 months
    uint256 public constant TWELVE_MONTHS = 12 * 30 days; // 12 months

    ERC20 public immutable lpToken;
    ERC20 public immutable rewardsToken;
    IGauge public immutable gauge;
    IPoints private immutable iPoints;
    uint256 public pointsPerToken;

    uint256 public totalStaked;
    uint256 public totalWithdrawn;

    mapping(address wallet => ILPStaking.StakeInfo[] walletStakes) public stakes;
    mapping(uint256 period => uint256 multiplier) public multipliers;
    mapping(address wallet => uint256 claimedAt) lastClaims;

    /**
     * @notice Initialize the LPStaking contract
     * @param _lpToken The address of the LP token
     * @param _rewardsToken The address of the rewards token
     * @param _gauge The address of the gauge
     * @param _points The address of the points token
     * @param _pointsPerToken The amount of points per token
     * @dev Reverts with ILPStaking__Error if any of the parameters are invalid
     * - The LP token address must be valid
     * - The rewards token address must be valid
     * - The gauge address must be valid
     * - The points address must be valid
     * - The points per token must be greater than 0
     * - The multipliers for the lock periods must be greater than 0
     * - The total staked and total withdrawn amounts are initialized to 0
     * - The points per token is set to the input parameter
     * - The multipliers for the lock periods are set to the input parameters
     * - The LP token, rewards token, gauge, and points token addresses are stored
     */
    constructor(address _lpToken, address _rewardsToken, address _gauge, address _points, uint256 _pointsPerToken)
        Ownable(msg.sender)
    {
        require(_lpToken != address(0), ILPStaking.ILPStaking__Error("Invalid address _lpToken"));
        require(_rewardsToken != address(0), ILPStaking.ILPStaking__Error("Invalid address _rewardsToken"));
        require(_gauge != address(0), ILPStaking.ILPStaking__Error("Invalid address for _gauge"));
        require(_points != address(0), ILPStaking.ILPStaking__Error("Invalid address for _points"));

        lpToken = ERC20(_lpToken);
        rewardsToken = ERC20(_rewardsToken);
        gauge = IGauge(_gauge);
        iPoints = IPoints(_points);
        pointsPerToken = _pointsPerToken;

        multipliers[THREE_MONTHS] = 1 ether;
        multipliers[SIX_MONTHS] = 3 ether;
        multipliers[NINE_MONTHS] = 5 ether;
        multipliers[TWELVE_MONTHS] = 7 ether;
    }

    /**
     * @notice Stake lp tokens to earn rewards and points based on lock tier and period
     * @param amount Amount of lp tokens to be staked
     * @param period Lock period in seconds
     * @dev Transfer lp tokens from the user to the contract
     *      - Revert if the amount is less than or equal to 0
     *      - Revert if the user has reached the maximum number of stakes
     *      - Revert if the lock period is invalid
     *      - Transfer the lp tokens from the user to the contract
     *      - Create a new stake entry for the user
     *      - Increment the total staked amount
     *      - Emit a Staked event
     *      - Approve and deposit LPs in the gauge system
     */
    function stake(uint256 amount, uint256 period) external nonReentrant whenNotPaused {
        require(stakes[msg.sender].length < MAX_STAKES_PER_WALLET, ILPStaking.ILPStaking__Error("Max stakes reached"));
        require(amount > 0, ILPStaking.ILPStaking__Error("Insufficient amount"));
        require(amount <= MAX_AMOUNT_TO_STAKE, ILPStaking.ILPStaking__Error("Exceeds max amount")); // ADDED THIS LINE TO LIMIT MAX STAKE AMOUNT
        require(multipliers[period] > 0, ILPStaking.ILPStaking__Error("Invalid period"));

        ERC20(lpToken).safeTransferFrom(msg.sender, address(this), amount);

        ILPStaking.StakeInfo memory newStake = ILPStaking.StakeInfo({
            stakedAmount: amount,
            withdrawnAmount: 0,
            stakedAt: block.timestamp,
            withdrawTime: block.timestamp + period,
            stakePeriod: period,
            claimedPoints: 0,
            claimedRewards: 0
        });

        stakes[msg.sender].push(newStake);
        totalStaked += amount;
        emit ILPStaking.Staked(msg.sender, amount, stakes[msg.sender].length - 1);

        // Approve and deposit LPs in the gauge system
        lpToken.forceApprove(address(gauge), amount);
        gauge.deposit(amount);
    }

    /**
     * @notice Withdraw staked lp tokens and earned points after the lock period ends
     * @param amount Amount of lp tokens to withdraw (must be less than or equal to staked amount)
     * @param stakeIndex Index of the specific stake information entry for the user
     * @dev This function allows the user to withdraw their staked LP tokens after the lock period ends.
     *      - Revert if the amount is less than or equal to 0
     *      - Revert if the stake index is out of bounds
     *      - Revert if the current time is before the withdraw time
     *      - Revert if the amount is greater than the staked amount
     *      - Revert if the amount is greater than the balance of the gauge
     *      - Update the withdrawn amount for the stake
     *      - Decrement the total staked amount
     *      - Increment the total withdrawn amount
     *      - Emit a Withdrawn event
     *      - Withdraw the LP tokens from the gauge
     *      - Transfer the LP tokens back to the user
     */
    function withdraw(uint256 amount, uint256 stakeIndex) external nonReentrant {
        require(amount > 0, ILPStaking.ILPStaking__Error("Insufficient amount"));
        require(stakeIndex < stakes[msg.sender].length, ILPStaking.ILPStaking__Error("Invalid stake index"));
        ILPStaking.StakeInfo storage stakeInfo = stakes[msg.sender][stakeIndex];

        require(
            block.timestamp >= stakeInfo.withdrawTime,
            ILPStaking.ILPStaking__Error("Not allowed to withdraw in staking period")
        );

        uint256 walletStaked = stakeInfo.stakedAmount - stakeInfo.withdrawnAmount;

        require(walletStaked > 0, ILPStaking.ILPStaking__Error("Insufficient amount"));
        require(amount <= walletStaked, ILPStaking.ILPStaking__Error("Insufficient amount"));
        require(amount <= gauge.balanceOf(address(this)), ILPStaking.ILPStaking__Error("Exceeds balance"));

        stakeInfo.withdrawnAmount += amount;
        totalStaked -= amount;
        totalWithdrawn += amount;
        emit ILPStaking.Withdrawn(msg.sender, amount, stakeIndex);

        // Remove LP from the gauge
        gauge.withdraw(amount);

        // Send LP back to staker
        ERC20(lpToken).safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Claim rewards from the gauge
     * @dev Claim rewards from the gauge and transfer them to the user's wallet
     *      - Revert if there's no rewards to claim
     *      - Iterate through all wallet stakes and claim rewards for each
     *      - Transfer rewards to the user
     *      - Emit an event with the claimed rewards amount
     */
    function claimRewards() external nonReentrant {
        require(
            block.timestamp > lastClaims[msg.sender] + CLAIM_DELAY_PERIOD,
            ILPStaking.ILPStaking__Error("Claiming too soon")
        ); // ADDED THIS LINE TO DONT SPAM CLAIMS POINTS

        uint256 totalRewards;
        ILPStaking.StakeInfo[] storage walletStakes = stakes[msg.sender];

        for (uint256 i = 0; i < walletStakes.length; i++) {
            uint256 stakeRewards = rewardsByStake(msg.sender, i);
            if (stakeRewards > 0) {
                totalRewards += stakeRewards;
                walletStakes[i].claimedRewards += stakeRewards;
            }
        }

        require(totalRewards > 0, ILPStaking.ILPStaking__Error("Insufficient rewards to claim"));

        // Claim rewards from the gauge
        gauge.getReward(address(this));

        // Update the last claim timestamp
        lastClaims[msg.sender] = block.timestamp;

        // Transfer rewards to the user
        rewardsToken.safeTransfer(msg.sender, totalRewards);

        emit ILPStaking.RewardsClaimed(msg.sender, totalRewards);
    }

    /**
     * @notice Claim samurai points from a specific stake
     * @dev Mint accrued Samurai Points (SPS)
     *      - Revert when tries to claim at the same time
     *      - Revert if there's no stakes
     *      - Iterates through all wallet stakes and mint the amount in samurai points
     *      - Revert if there's no points to claim
     */
    function claimPoints() external nonReentrant {
        require(block.timestamp > lastClaims[msg.sender] + CLAIM_DELAY_PERIOD, "Claiming too soon"); // ADDED THIS LINE TO DONT SPAM CLAIMS POINTS

        ILPStaking.StakeInfo[] storage walletStakes = stakes[msg.sender];
        require(walletStakes.length > 0, ILPStaking.ILPStaking__Error("Insufficient points to claim"));

        uint256 points;
        for (uint256 i = 0; i < walletStakes.length; i++) {
            points += previewClaimablePoints(msg.sender, i);
            walletStakes[i].claimedPoints = points;
        }

        require(points > 0, ILPStaking.ILPStaking__Error("Insufficient points to claim"));

        // Update the last claim timestamp
        lastClaims[msg.sender] = block.timestamp;

        emit ILPStaking.PointsClaimed(msg.sender, points);

        iPoints.mint(msg.sender, points);
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
     * @notice Owner can withdraw in emergency
     * @dev This function can only be called by the contract owner.
     *      Withdraw rewards token and lp tokens to owner's wallet.
     *      Pause the contract.
     */
    function emergencyWithdraw() external onlyOwner nonReentrant {
        gauge.getReward(address(this));
        gauge.withdraw(gauge.balanceOf(address(this)));

        rewardsToken.safeTransfer(owner(), rewardsToken.balanceOf(address(this)));
        lpToken.safeTransfer(owner(), lpToken.balanceOf(address(this)));

        _pause();
    }

    /**
     * @notice This function updates the multipliers used to calculate lockup rewards for different lockup durations (3, 6, 9, and 12 months).
     * @param multiplier3x The new multiplier for the 3-month lockup.
     * @param multiplier6x The new multiplier for the 6-month lockup.
     * @param multiplier9x The new multiplier for the 9-month lockup.
     * @param multiplier12x The new multiplier for the 12-month lockup.
     * @dev This function can only be called by the contract owner. It reverts if any of the new multipliers are less than to the corresponding stored multiplier.
     */
    function updateMultipliers(uint256 multiplier3x, uint256 multiplier6x, uint256 multiplier9x, uint256 multiplier12x)
        external
        onlyOwner
    {
        require(
            multiplier3x > multipliers[THREE_MONTHS] || multiplier6x > multipliers[SIX_MONTHS]
                || multiplier9x > multipliers[NINE_MONTHS] || multiplier12x > multipliers[TWELVE_MONTHS],
            ILPStaking.ILPStaking__Error("Invalid multiplier")
        );

        multipliers[THREE_MONTHS] = multiplier3x;
        multipliers[SIX_MONTHS] = multiplier6x;
        multipliers[NINE_MONTHS] = multiplier9x;
        multipliers[TWELVE_MONTHS] = multiplier12x;

        emit ILPStaking.MultipliersUpdated(multiplier3x, multiplier6x, multiplier9x, multiplier12x);
    }

    /**
     * @notice Previews the claimable rewards for a given wallet.
     * @param wallet The wallet address to calculate claimable tokens for.
     * @return rewards The total amount of claimable rewards for the wallet.
     * @dev Calculates the total amount of rewards tokens for specific wallet.
     *      - Iterates through all wallet stakes and calculates the rewards for each.
     *      - Returns the total rewards for the wallet.
     *      - Reverts with ILPStaking__Error if the wallet has no stakes.
     *
     */
    function previewRewards(address wallet) public view returns (uint256 rewards) {
        ILPStaking.StakeInfo[] memory walletStakes = stakes[wallet];

        for (uint256 i = 0; i < walletStakes.length; i++) {
            uint256 stakeRewards = rewardsByStake(wallet, i);
            rewards += stakeRewards;
        }

        return rewards;
    }

    /**
     * @notice Calculate the total points earned for a specific lock entry
     * @param wallet Address of the user
     * @param stakeIndex Index of the lock information entry for the user
     * @return rewards Total rewards earned for the specific lock entry (uint256)
     * @dev Reverts with ILock.SamLock__InvalidstakeIndex if the lock index is out of bounds
     *      - Calculate the total rewards earned by the contract
     *      - Calculate the proportion of total staked amount that belongs to this lock
     *      - Calculate rewards for this lock
     *      - Subtract already claimed rewards
     *      - Return rewards
     */
    function rewardsByStake(address wallet, uint256 stakeIndex) public view returns (uint256) {
        // require(stakeIndex < stakes[wallet].length, ILPStaking.ILPStaking__Error("Invalid stake index"));
        if (stakeIndex >= stakes[wallet].length) return 0;

        // prevent division by zero
        if (totalStaked == 0) return 0;

        ILPStaking.StakeInfo memory stakeInfo = stakes[wallet][stakeIndex];

        // Calculate total staked amount for current stakeIndex
        uint256 stakedAmount = stakeInfo.stakedAmount - stakeInfo.withdrawnAmount;

        // prevent division by zero
        if (stakedAmount == 0) return 0;

        uint256 currentRewards = gauge.earned(address(this));

        // prevent division by zero
        if (currentRewards == 0) return 0;

        // Convert total rewards to UD60x18
        UD60x18 totalRewards = ud(currentRewards);

        // Calculate the proportion of total staked amount that belongs to this stake
        UD60x18 stakeProportion = ud(stakedAmount).div(ud(totalStaked));

        // Calculate rewards for this stake
        UD60x18 stakeRewards = totalRewards.mul(stakeProportion);

        if (stakeRewards.intoUint256() == 0) return 0;

        // Subtract already claimed rewards
        uint256 rewards = stakeRewards.sub(ud(stakeInfo.claimedRewards)).intoUint256();
        return rewards;
    }

    /**
     * @notice Previews the claimable points for a given wallet and stakeIndex.
     * @param wallet The wallet address to calculate claimable tokens for.
     * @param stakeIndex The index of a specific stake.
     * @return claimablePoints The total amount of claimable points for the wallet.
     * @dev Calculates the total amount of Samurai Points tokens for specific stake.
     *      - Reverts with ILPStaking__Error if the wallet has no stakes.
     *      - Reverts with ILPStaking__Error if the stake index is out of bounds.
     *      - Calculates the total points for the stake.
     *      - Returns the total points for the stake.
     */
    function previewClaimablePoints(address wallet, uint256 stakeIndex) public view returns (uint256) {
        ILPStaking.StakeInfo[] memory walletStakes = stakes[wallet];

        if (walletStakes.length == 0) return 0;
        if (walletStakes.length <= stakeIndex) return 0;

        ILPStaking.StakeInfo memory stakeInfo = walletStakes[stakeIndex];

        if (stakeInfo.claimedPoints > 0) return 0;

        return
            ud(stakeInfo.stakedAmount).mul(ud(pointsPerToken)).mul(ud(multipliers[stakeInfo.stakePeriod])).intoUint256();
    }
}
