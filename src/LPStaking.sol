//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

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

    uint256 public constant MAX_STAKES_PER_WALLET = 5;

    // Define lock periods (in seconds)
    uint256 public constant THREE_MONTHS = 3 * 30 days;
    uint256 public constant SIX_MONTHS = 6 * 30 days;
    uint256 public constant NINE_MONTHS = 9 * 30 days;
    uint256 public constant TWELVE_MONTHS = 12 * 30 days;

    ERC20 public immutable lpToken;
    ERC20 public immutable rewardsToken;
    IGauge public immutable gauge;
    IPoints private immutable iPoints;
    uint256 public minToStake;
    uint256 public totalStaked;
    uint256 public totalWithdrawn;
    uint256 public nextStakeIndex;

    uint256 public collectedFees;
    UD60x18 public withdrawEarlierFee = ud(0.1e18);

    mapping(address wallet => ILPStaking.StakeInfo[] stakes) public stakes;
    mapping(uint256 period => uint256 multiplier) public multipliers;
    mapping(address wallet => uint256 claimedAt) lastClaims;

    constructor(address _lpToken, address _rewardsToken, address _gauge, address _points, uint256 _minToStake)
        Ownable(msg.sender)
    {
        require(_lpToken != address(0), ILPStaking.ILPStaking__Error("Invalid address"));
        lpToken = ERC20(_lpToken);
        rewardsToken = ERC20(_rewardsToken);
        gauge = IGauge(_gauge);
        iPoints = IPoints(_points);
        minToStake = _minToStake;

        multipliers[THREE_MONTHS] = 1e18;
        multipliers[SIX_MONTHS] = 3e18;
        multipliers[NINE_MONTHS] = 5e18;
        multipliers[TWELVE_MONTHS] = 7e18;
    }

    /**
     * @notice Stake lp tokens to earn rewards and points based on lock tier and period
     * @param amount Amount of lp tokens to be staked
     * @param stakePeriod Stake period chosen by the user (THREE_MONTHS, SIX_MONTHS, NINE_MONTHS, TWELVE_MONTHS)
     */
    function stake(uint256 amount, uint256 stakePeriod) external nonReentrant whenNotPaused {
        require(stakes[msg.sender].length < MAX_STAKES_PER_WALLET, ILPStaking.ILPStaking__Error("Max stakes reached"));
        require(amount >= minToStake, ILPStaking.ILPStaking__Error("Insufficient amount"));
        require(
            stakePeriod == THREE_MONTHS || stakePeriod == SIX_MONTHS || stakePeriod == NINE_MONTHS
                || stakePeriod == TWELVE_MONTHS,
            ILPStaking.ILPStaking__Error("Invalid period")
        );

        ERC20(lpToken).safeTransferFrom(msg.sender, address(this), amount);

        uint256 stakeIndex = nextStakeIndex;

        ILPStaking.StakeInfo memory newStake = ILPStaking.StakeInfo({
            stakeIndex: stakeIndex,
            stakedAmount: amount,
            withdrawnAmount: 0,
            stakedAt: block.timestamp,
            withdrawTime: block.timestamp + stakePeriod,
            stakePeriod: stakePeriod,
            claimedPoints: 0,
            claimedRewards: 0,
            lastRewardsClaimedAt: 0
        });

        stakes[msg.sender].push(newStake);

        totalStaked += amount;
        nextStakeIndex++;

        emit ILPStaking.Staked(msg.sender, amount, stakeIndex);

        // Approve and deposit LPs in the gauge system
        lpToken.forceApprove(address(gauge), amount);
        gauge.deposit(amount);
    }

    /**
     * @notice Withdraw staked lp tokens and earned points after the lock period ends
     * @param amount Amount of lp tokens to withdraw (must be less than or equal to staked amount)
     * @param stakeIndex Index of the specific stake information entry for the user
     */
    function withdraw(uint256 amount, uint256 stakeIndex) external nonReentrant {
        require(amount > 0, ILPStaking.ILPStaking__Error("Insufficient amount"));

        require(stakeIndex < stakes[msg.sender].length, ILPStaking.ILPStaking__Error("Invalid stake index"));
        ILPStaking.StakeInfo storage stakeInfo = stakes[msg.sender][stakeIndex];

        // require(
        //     block.timestamp >= stakeInfo.withdrawTime,
        //     ILPStaking.ILPStaking__Error("Cannot withdraw before period ends")
        // );
        require(
            amount <= stakeInfo.stakedAmount - stakeInfo.withdrawnAmount,
            ILPStaking.ILPStaking__Error("Insufficient amount")
        );

        uint256 gaugeBalance = IGauge(gauge).balanceOf(address(this));
        require(amount <= gaugeBalance, ILPStaking.ILPStaking__Error("Exceeds balance"));

        uint256 fee;
        if (block.timestamp < stakeInfo.withdrawTime) {
            fee = getFees(amount);
            collectedFees += fee;
        }

        stakeInfo.withdrawnAmount += amount - fee;
        totalStaked -= amount;
        totalWithdrawn += amount;
        emit ILPStaking.Withdrawn(msg.sender, amount, stakeIndex);

        // Remove LP from the gauge
        IGauge(gauge).withdraw(amount);

        // Send LP back to staker
        ERC20(lpToken).safeTransfer(msg.sender, amount);
    }

    /**
     * @notice Claim samurai points distributed for all wallet locks
     * @dev Mint accrued Samurai Points (SPS)
     *      - Revert when tries to claim at the same time
     *      - Iterates through all wallet locks and mint the amount in samurai points
     *      - Revert if there's no points to claim
     */
    function claimPoints() external nonReentrant {
        require(block.timestamp > lastClaims[msg.sender], ILPStaking.ILPStaking__Error("Unallowed to claim right now"));
        uint256 points;
        ILPStaking.StakeInfo[] storage walletStakes = stakes[msg.sender];

        for (uint256 i = 0; i < walletStakes.length; i++) {
            uint256 stakePoints = pointsByStake(msg.sender, walletStakes[i].stakeIndex);
            points += stakePoints;
            walletStakes[i].claimedPoints = stakePoints;
        }

        require(points > 0, ILPStaking.ILPStaking__Error("Insufficient points to claim"));
        lastClaims[msg.sender] = block.timestamp;
        iPoints.mint(msg.sender, points);
        emit ILPStaking.PointsClaimed(msg.sender, points);
    }

    function claimRewards() external nonReentrant {
        uint256 totalRewards;
        ILPStaking.StakeInfo[] storage walletStakes = stakes[msg.sender];

        for (uint256 i = 0; i < walletStakes.length; i++) {
            uint256 stakeRewards = rewardsByStake(msg.sender, i);
            if (stakeRewards > 0) {
                totalRewards += stakeRewards;
                walletStakes[i].claimedRewards += stakeRewards;
                walletStakes[i].lastRewardsClaimedAt = block.timestamp;
            }
        }

        require(totalRewards > 0, ILPStaking.ILPStaking__Error("Insufficient rewards to claim"));

        // Claim rewards from the gauge
        gauge.getReward(address(this));

        // Transfer rewards to the user
        rewardsToken.safeTransfer(msg.sender, totalRewards);

        emit ILPStaking.RewardsClaimed(msg.sender, totalRewards);
    }

    function collectFees() external onlyOwner nonReentrant {
        uint256 fees = collectedFees;
        collectedFees = 0;
        emit ILPStaking.FeesWithdrawn(fees);

        gauge.withdraw(fees);
        ERC20(lpToken).safeTransfer(owner(), fees);
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
     * @notice Owner can update minToStake config
     * @param _minToStake value to be updated
     * @dev This function can only be called by the contract owner.
     */
    function updateMinToStake(uint256 _minToStake) external onlyOwner nonReentrant {
        minToStake = _minToStake;
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
     * @notice Retrieve all lock information entries for a specific user (address)
     * @dev Reverts with ILock.SamLock__NotFound if there are no lock entries for the user
     * @param wallet Address of the user
     * @return lockInfos Array containing the user's lock information entries
     */
    function getStakeInfos(address wallet) public view returns (ILPStaking.StakeInfo[] memory) {
        return stakes[wallet];
    }

    /**
     * @notice Calculate the total points earned for a specific lock entry
     * @param wallet Address of the user
     * @param stakeIndex Index of the lock information entry for the user
     * @return points Total points earned for the specific lock entry (uint256)
     * @dev Reverts with ILock.SamLock__InvalidstakeIndex if the lock index is out of bounds
     */
    function pointsByStake(address wallet, uint256 stakeIndex) public view returns (uint256 points) {
        require(stakeIndex < stakes[wallet].length, ILPStaking.ILPStaking__Error("Invalid stake index"));

        ILPStaking.StakeInfo memory stakeInfo = stakes[wallet][stakeIndex];
        UD60x18 multiplier = ud(multipliers[stakeInfo.stakePeriod]);
        UD60x18 maxPointsToEarn = ud(stakeInfo.stakedAmount).mul(multiplier).sub(ud(stakeInfo.claimedPoints));

        if (block.timestamp >= stakeInfo.withdrawTime) {
            points = maxPointsToEarn.intoUint256();
            return points;
        }

        uint256 elapsedTime = block.timestamp - stakeInfo.stakedAt;

        if (elapsedTime > 0) {
            UD60x18 oneDay = ud(86_400e18);
            UD60x18 periodInDays = convert(stakeInfo.stakePeriod).div(oneDay);
            UD60x18 pointsPerDay = maxPointsToEarn.div(periodInDays);
            UD60x18 elapsedDays = convert(elapsedTime).div(oneDay);

            points = pointsPerDay.mul(elapsedDays).intoUint256();
        }

        return points;
    }

    /**
     * @notice Calculate the total points earned for a specific lock entry
     * @param wallet Address of the user
     * @param stakeIndex Index of the lock information entry for the user
     * @return rewards Total rewards earned for the specific lock entry (uint256)
     * @dev Reverts with ILock.SamLock__InvalidstakeIndex if the lock index is out of bounds
     */
    function rewardsByStake(address wallet, uint256 stakeIndex) public view returns (uint256 rewards) {
        require(stakeIndex < stakes[wallet].length, ILPStaking.ILPStaking__Error("Invalid stake index"));

        ILPStaking.StakeInfo memory stakeInfo = stakes[wallet][stakeIndex];

        // Calculate total rewards earned by the contract
        UD60x18 totalRewards = ud(gauge.earned(address(this)));

        // Calculate the proportion of total staked amount that belongs to this stake
        UD60x18 stakeProportion = ud(stakeInfo.stakedAmount).div(ud(totalStaked));

        // Calculate rewards for this stake
        UD60x18 stakeRewards = totalRewards.mul(stakeProportion);

        // Subtract already claimed rewards
        rewards = stakeRewards.sub(ud(stakeInfo.claimedRewards)).intoUint256();

        return rewards;
    }

    function getFees(uint256 _amount) public view returns (uint256) {
        return ud(_amount).mul(withdrawEarlierFee).intoUint256();
    }
}
