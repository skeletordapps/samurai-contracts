//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.23;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/console.sol";
import {ILPStaking} from "./interfaces/ILPStaking.sol";
import {IGauge} from "./interfaces/IGauge.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";

contract LPStaking is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    //////////////////////////////////////
    // STATE VARIABLES
    //////////////////////////////////////

    uint256 public constant MAX_ALLOWED_TO_STAKE = 100_000_000 ether;
    uint256 internal constant PRECISION = 1e18;

    uint256 public totalStaked;
    uint256 public collectedFees;
    uint256 public withdrawEarlierFeeLockTime = 30 days;
    // uint256 public withdrawEarlierFee = 10;
    UD60x18 public withdrawEarlierFee = ud(0.1e18);
    uint256 public minStakedToReward = 0.000003 ether;

    uint256 public END_STAKING_UNIX_TIME;
    address public LP_TOKEN;
    address public REWARDS_TOKEN;
    address public GAUGE;

    mapping(address account => ILPStaking.User user) public stakings;

    //////////////////////////////////////
    // EVENTS
    //////////////////////////////////////

    event Staked(address indexed account, uint256 amount);
    event StakeWithdrawn(address indexed account, uint256 amount);
    event GaugeRewardsClaimed(uint256 timestamp, uint256 amount);
    event RewardsClaimed(uint256 timestamp, address indexed account, uint256 amount);
    event FeesWithdrawn(uint256 amount);
    event EmergencyWithdrawnFunds(uint256 fees);

    //////////////////////////////////////
    // MODIFIERS
    //////////////////////////////////////

    modifier canStake(uint256 amount) {
        if (block.timestamp > END_STAKING_UNIX_TIME) {
            revert ILPStaking.Staking_Period_Ended();
        }

        if (amount == 0) revert ILPStaking.Staking_Insufficient_Amount();

        if (totalStaked + amount > MAX_ALLOWED_TO_STAKE) {
            revert ILPStaking.Staking_Max_Limit_Reached();
        }
        _;
    }

    constructor(address _lpToken, address _rewardsToken, address _gauge) Ownable(msg.sender) {
        LP_TOKEN = _lpToken;
        REWARDS_TOKEN = _rewardsToken;
        GAUGE = _gauge;

        _pause();
    }

    //////////////////////////////////////
    // EXTERNAL FUNCTIONS
    //////////////////////////////////////

    function init(uint256 initialDuration) external onlyOwner {
        END_STAKING_UNIX_TIME = block.timestamp + initialDuration;

        _unpause();
    }

    function stake(address wallet, uint256 amount) external whenNotPaused canStake(amount) nonReentrant {
        ILPStaking.User storage user = stakings[wallet];

        user.rewardsEarned = calculateRewards(wallet); // update user rewards earned so far
        user.lockedAmount += amount; // update user balance
        user.lastUpdate = block.timestamp; // update user last update timestamp
        emit Staked(wallet, amount);

        totalStaked += amount; // update total LP staked in the contract

        // Transfers full LP amount from user to this contract
        ERC20(LP_TOKEN).safeTransferFrom(wallet, address(this), amount);

        // Approve and deposit LPs in the gauge system
        ERC20(LP_TOKEN).forceApprove(GAUGE, amount);
        IGauge(GAUGE).deposit(amount);
    }

    function withdraw(address wallet, uint256 amount) external nonReentrant {
        if (amount == 0) revert ILPStaking.Staking_Insufficient_Amount();

        ILPStaking.User storage user = stakings[wallet];
        uint256 balance = user.lockedAmount;

        if (balance == 0) revert ILPStaking.Staking_No_Balance_Staked();
        if (amount > balance) revert ILPStaking.Staking_Amount_Exceeds_Balance();

        uint256 fee = 0;

        if (block.timestamp < user.lastUpdate + withdrawEarlierFeeLockTime) {
            fee = getFees(amount);
            collectedFees += fee;
        }

        user.rewardsEarned = calculateRewards(wallet); // update rewards earned so far
        user.lastUpdate = block.timestamp; // update user last update
        user.lockedAmount -= amount; // update user balance

        emit StakeWithdrawn(wallet, amount);

        totalStaked -= amount; // update total LP staked in the contract

        // Remove LP from the gauge if is not paused, otherwise the lp will be on the contract already
        if (!paused()) _withdrawFromGauge(amount - fee);

        // Give user LP back
        ERC20(LP_TOKEN).safeTransfer(wallet, amount - fee);
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

        ERC20(REWARDS_TOKEN).safeTransfer(wallet, rewards);
        emit RewardsClaimed(block.timestamp, wallet, rewards);
    }

    function collectFees() external onlyOwner nonReentrant {
        uint256 fees = collectedFees;
        collectedFees = 0;
        emit FeesWithdrawn(fees);

        _withdrawFromGauge(fees);
        ERC20(LP_TOKEN).safeTransfer(owner(), fees);
    }

    function emergencyWithdraw() external onlyOwner nonReentrant {
        // Check to make sure that there are rewards to claim.
        uint256 gaugeRewardsBalance = IGauge(GAUGE).earned(address(this));
        if (gaugeRewardsBalance > 0) _claimRewardsFromGauge();

        // Remove all LP from the gauge
        uint256 gaugeBalance = IGauge(GAUGE).balanceOf(address(this));
        if (gaugeBalance > 0) IGauge(GAUGE).withdraw(gaugeBalance);

        // Update state variables
        uint256 fees = collectedFees;
        collectedFees = 0;
        END_STAKING_UNIX_TIME = block.timestamp;

        // Perform external transfers
        emit EmergencyWithdrawnFunds(fees);
        ERC20(LP_TOKEN).safeTransfer(owner(), fees);

        _pause();
    }

    function updateWithdrawEarlierFeeLockTime(uint256 _withdrawEarlierFeeLockTime) external onlyOwner {
        withdrawEarlierFeeLockTime = _withdrawEarlierFeeLockTime;
    }

    function updateWithdrawEarlierFee(uint256 _withdrawEarlierFee) external onlyOwner {
        withdrawEarlierFee = ud(_withdrawEarlierFee);
    }

    function updateMinStakedToReward(uint256 _minStakedToReward) external onlyOwner {
        minStakedToReward = _minStakedToReward;
    }

    //////////////////////////////////////
    // PRIVATE FUNCTIONS
    //////////////////////////////////////

    function _withdrawFromGauge(uint256 amount) private {
        uint256 gaugeBalance = IGauge(GAUGE).balanceOf(address(this));
        if (amount > gaugeBalance) revert ILPStaking.Staking_Exceeds_Farming_Balance(gaugeBalance);

        // Remove LP from the gauge
        IGauge(GAUGE).withdraw(amount);
    }

    function _claimRewardsFromGauge() private {
        // Claim the rewards from the gauge contract.
        IGauge(GAUGE).getReward(address(this));

        // Check contract gauge rewards balance
        uint256 claimedRewards = ERC20(REWARDS_TOKEN).balanceOf(address(this));

        emit GaugeRewardsClaimed(block.timestamp, claimedRewards);
    }

    ///////////////////////////////////////////////
    // PRIVATE & INTERNAL VIEW & PURE FUNCTIONS
    ///////////////////////////////////////////////

    function getFees(uint256 _amount) public view returns (uint256) {
        UD60x18 amount = convert(_amount);
        UD60x18 result = amount.mul(withdrawEarlierFee);
        return result.intoUint256();
    }

    ///////////////////////////////////////////////
    // PUBLIC VIEW FUNCTIONS
    ///////////////////////////////////////////////

    function totalRewards() public view returns (uint256) {
        return IGauge(GAUGE).earned(address(this)) + ERC20(REWARDS_TOKEN).balanceOf(address(this));
    }

    function calculateRewards(address account) public view returns (uint256) {
        ILPStaking.User memory user = stakings[account];

        uint256 elapsedTime = calculateElapsedTime(account);
        uint256 lockedAmount = user.lockedAmount;
        uint256 accumulatedRewards = user.rewardsEarned;
        uint256 _totalRewards = totalRewards();

        if (_totalRewards == 0 || lockedAmount == 0 || lockedAmount < minStakedToReward || elapsedTime == 0) {
            return accumulatedRewards;
        }

        UD60x18 userShare = ud(lockedAmount).div(ud(totalStaked));
        UD60x18 timeFactor = ud(elapsedTime).mul(ud(PRECISION));
        UD60x18 userRewards = userShare.mul(timeFactor);
        userRewards = userRewards.div(ud(_totalRewards));

        return userRewards.intoUint256();
    }

    function calculateElapsedTime(address account) public view returns (uint256) {
        ILPStaking.User memory user = stakings[account];
        uint256 elapsedTime;

        if (block.timestamp > END_STAKING_UNIX_TIME) {
            elapsedTime = END_STAKING_UNIX_TIME > user.lastUpdate ? END_STAKING_UNIX_TIME - user.lastUpdate : 0;
        } else {
            elapsedTime = block.timestamp > user.lastUpdate ? block.timestamp - user.lastUpdate : 0;
        }

        return elapsedTime;
    }
}
