//SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/console.sol";
import {ILPStaking} from "./interfaces/ILPStaking.sol";
import {IGauge} from "./interfaces/IGauge.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";
import {console} from "forge-std/console.sol";

contract LPStakingV2 is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    //////////////////////////////////////
    // STATE VARIABLES
    //////////////////////////////////////

    uint256 public constant MAX_ALLOWED_TO_STAKE = 100_000_000 ether;
    UD60x18 public withdrawEarlierFee = ud(0.1e18);
    uint256 public withdrawEarlierFeeLockTime = 30 days;
    uint256 public minPerWallet = 0.000003 ether;
    uint256 public rewardsPerSecond;
    uint256 public totalStaked;
    uint256 public collectedFees;
    uint256 public periodFinish;
    address public lpToken;
    address public rewardsToken;
    address public gaugeRewardsToken;
    address public gauge;

    mapping(address account => ILPStaking.User user) public stakings;

    //////////////////////////////////////
    // MODIFIERS
    //////////////////////////////////////

    modifier canStake(uint256 amount) {
        if (block.timestamp > periodFinish) {
            revert ILPStaking.Staking_Period_Ended();
        }

        if (amount == 0) revert ILPStaking.Staking_Insufficient_Amount();
        if (amount < minPerWallet) revert ILPStaking.Staking_Insufficient_Amount();

        if (totalStaked + amount > MAX_ALLOWED_TO_STAKE) {
            revert ILPStaking.Staking_Max_Limit_Reached();
        }
        _;
    }

    modifier canWithdraw(address wallet, uint256 amount) {
        ILPStaking.User memory user = stakings[wallet];

        if (user.lockedAmount == 0) revert ILPStaking.Staking_No_Balance_Staked();
        if (amount == 0) revert ILPStaking.Staking_Insufficient_Amount();
        if (amount > user.lockedAmount) revert ILPStaking.Staking_Amount_Exceeds_Balance();
        if (amount < minPerWallet) revert ILPStaking.Staking_Insufficient_Amount();
        _;
    }

    constructor(address _lpToken, address _rewardsToken, address _gauge, address _gaugeRewardsToken)
        Ownable(msg.sender)
    {
        lpToken = _lpToken;
        rewardsToken = _rewardsToken;
        gauge = _gauge;
        gaugeRewardsToken = _gaugeRewardsToken;

        _pause();
    }

    //////////////////////////////////////
    // EXTERNAL FUNCTIONS
    //////////////////////////////////////

    function init(uint256 initialDuration, uint256 rewardsPerDay) external onlyOwner whenPaused {
        periodFinish = block.timestamp + initialDuration;
        rewardsPerSecond = rewardsPerDay / 86400;

        _unpause();
    }

    function stake(address wallet, uint256 amount) external whenNotPaused canStake(amount) nonReentrant {
        ILPStaking.User storage user = stakings[wallet];

        user.rewardsEarned = calculateRewards(wallet); // update user rewards earned so far
        user.lockedAmount += amount; // update user balance
        user.lastUpdate = block.timestamp; // update user last update timestamp
        emit ILPStaking.Staked(wallet, amount);

        totalStaked += amount; // update total LP staked in the contract

        // Transfers full LP amount from user to this contract
        ERC20(lpToken).safeTransferFrom(wallet, address(this), amount);

        // Approve and deposit LPs in the gauge system
        ERC20(lpToken).forceApprove(gauge, amount);
        IGauge(gauge).deposit(amount);
    }

    function withdraw(address wallet, uint256 amount) external canWithdraw(wallet, amount) nonReentrant {
        ILPStaking.User storage user = stakings[wallet];
        uint256 fee = 0;

        if (block.timestamp < user.lastUpdate + withdrawEarlierFeeLockTime) {
            fee = getFees(amount);
            collectedFees += fee;
        }

        user.rewardsEarned = calculateRewards(wallet); // update rewards earned so far
        user.lastUpdate = block.timestamp; // update user last update
        user.lockedAmount -= amount; // update user balance

        emit ILPStaking.StakeWithdrawn(wallet, amount);

        totalStaked -= amount; // update total LP staked in the contract

        uint256 amountLessFees = amount - fee;

        // Remove LP from the gauge if is not paused, otherwise the lp will be already in the contract
        if (!paused()) _withdrawFromGauge(amountLessFees);

        // Give user LP back
        ERC20(lpToken).safeTransfer(wallet, amountLessFees);
    }

    function claimRewards(address wallet) external nonReentrant {
        uint256 _totalRewards = totalRewards();

        if (_totalRewards == 0) revert ILPStaking.Staking_No_Rewards_Available();

        uint256 rewards = calculateRewards(wallet);
        if (rewards == 0 || _totalRewards < rewards) revert ILPStaking.Staking_No_Rewards_Available();

        ILPStaking.User storage user = stakings[wallet];
        user.rewardsEarned = 0;
        user.rewardsClaimed += rewards;
        user.lastUpdate = block.timestamp;

        ERC20(rewardsToken).safeTransfer(wallet, rewards);
        emit ILPStaking.RewardsClaimed(block.timestamp, wallet, rewards);
    }

    //////////////////////////////////////
    // EXTERNAL ONLY OWNER FUNCTIONS
    //////////////////////////////////////

    function collectFees() external onlyOwner nonReentrant {
        uint256 fees = collectedFees;
        collectedFees = 0;
        emit ILPStaking.FeesWithdrawn(fees);

        _withdrawFromGauge(fees);
        ERC20(lpToken).safeTransfer(owner(), fees);
    }

    function emergencyWithdraw() external onlyOwner nonReentrant {
        // Check to make sure that there are rewards to claim.
        uint256 gaugeRewardsBalance = IGauge(gauge).earned(address(this));
        if (gaugeRewardsBalance > 0) _claimRewardsFromGauge();

        // Remove all LP from the gauge
        uint256 gaugeBalance = IGauge(gauge).balanceOf(address(this));
        if (gaugeBalance > 0) IGauge(gauge).withdraw(gaugeBalance);

        // Update state variables
        uint256 fees = collectedFees;
        collectedFees = 0;
        periodFinish = block.timestamp;

        // Perform external transfers
        emit ILPStaking.EmergencyWithdrawnFunds(fees);
        ERC20(lpToken).safeTransfer(owner(), fees);
        ERC20(gaugeRewardsToken).safeTransfer(owner(), gaugeRewardsBalance);

        _pause();
    }

    function updateWithdrawEarlierFeeLockTime(uint256 _withdrawEarlierFeeLockTime) external onlyOwner {
        withdrawEarlierFeeLockTime = _withdrawEarlierFeeLockTime;
    }

    function updateWithdrawEarlierFee(uint256 _withdrawEarlierFee) external onlyOwner {
        withdrawEarlierFee = ud(_withdrawEarlierFee);
    }

    function updateMinPerWallet(uint256 _minPerWallet) external onlyOwner {
        if (_minPerWallet == 0) revert ILPStaking.Staking_Insufficient_Amount();
        minPerWallet = _minPerWallet;
    }

    //////////////////////////////////////
    // PRIVATE FUNCTIONS
    //////////////////////////////////////

    function _withdrawFromGauge(uint256 amount) private {
        uint256 gaugeBalance = IGauge(gauge).balanceOf(address(this));
        if (amount > gaugeBalance) revert ILPStaking.Staking_Exceeds_Farming_Balance(gaugeBalance);

        // Remove LP from the gauge
        IGauge(gauge).withdraw(amount);
    }

    function _claimRewardsFromGauge() private {
        // Claim the rewards from the gauge contract.
        IGauge(gauge).getReward(address(this));

        // Check contract gauge rewards balance
        uint256 claimedRewards = ERC20(rewardsToken).balanceOf(address(this));
        emit ILPStaking.GaugeRewardsClaimed(block.timestamp, claimedRewards);
    }

    ///////////////////////////////////////////////
    // PUBLIC VIEW FUNCTIONS
    ///////////////////////////////////////////////

    function getFees(uint256 _amount) public view returns (uint256) {
        UD60x18 amount = ud(_amount);
        UD60x18 result = amount.mul(withdrawEarlierFee);
        return result.intoUint256();
    }

    function totalRewards() public view returns (uint256) {
        return ERC20(rewardsToken).balanceOf(address(this));
    }

    function calculateRewards(address account) public view returns (uint256) {
        ILPStaking.User memory user = stakings[account];

        uint256 elapsedTime = calculateElapsedTime(account);
        uint256 lockedAmount = user.lockedAmount;
        uint256 accumulatedRewards = user.rewardsEarned;
        uint256 _totalRewards = totalRewards();

        if (_totalRewards == 0 || lockedAmount == 0 || elapsedTime == 0) {
            return accumulatedRewards;
        }

        UD60x18 userShare = ud(lockedAmount).div(ud(totalStaked));
        UD60x18 userRewards = userShare.mul(ud(elapsedTime)).div(ud(_totalRewards));

        return userRewards.intoUint256();
    }

    function calculateElapsedTime(address account) public view returns (uint256) {
        ILPStaking.User memory user = stakings[account];
        uint256 elapsedTime;

        if (block.timestamp > periodFinish) {
            elapsedTime = periodFinish > user.lastUpdate ? periodFinish - user.lastUpdate : 0;
        } else {
            elapsedTime = block.timestamp > user.lastUpdate ? block.timestamp - user.lastUpdate : 0;
        }

        return elapsedTime;
    }
}
