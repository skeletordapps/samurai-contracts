// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IFactory} from "./interfaces/IFactory.sol";
import {IIDOFull} from "./interfaces/IIDOFull.sol";
import {console2} from "forge-std/console2.sol";

contract IDOFull is Ownable, Pausable, ReentrancyGuard {
    using SafeERC20 for ERC20;

    // Deploy Initial Config variables
    string public name;
    string public symbol;
    string public description;

    // Needed to start Registration Phase
    uint256 public registrationStartsAt;
    uint256 public registrationDuration;
    uint256 public participationStartsAt; // wallets can participate after this date
    uint256 public participationDuration; // participations ends after participation starts + duration
    address public acceptedToken; // eg. USDC
    uint256 public price; // price in USDC per IDO token
    uint256 public maxAllocation; // overall accepted token max allocation

    // Needed to start Participation Phase
    uint256 public minPerWallet; // min USDC per wallet
    uint256 public maxPerWallet; // max USDC per wallet

    // Needed to start Vesting Phase
    address public token; // the IDO token
    uint256 public vesting; // timestamp eg. unlock tokens at certain date
    uint256 public tgeUnlock; // percentage of IDO token that will be available for users to claim after vesting date

    // Needed to start Release Phase
    uint256 public cliff; // timestamp eg. 4 months blocked without unlock and releases
    IIDOFull.ReleaseType public releaseType;
    IIDOFull.ClaimPeriodType public claimPeriodType;
    uint256 public releaseDuration; // timestamp eg. 3 months
    uint256 public releaseStartsAt; // this can be removed as we already had the cliff duration or we can remove cliff and just work with release start date as cliff

    // Counters
    uint256 public raised; // a public counter to measure allocations in accepted token
    uint256 public tokensSold; // a public counter to measure how much ido tokens were sold

    bool public isPublic;
    IIDOFull.Phase public phase = IIDOFull.Phase.None;

    // Mappings
    mapping(address wallet => bool isRegistered) public registrations;
    mapping(address wallet => bool whitelisted) public whitelist;
    mapping(address wallet => bool blacklisted) public blacklist;
    mapping(address wallet => uint256 participation) public allocations;
    mapping(address wallet => uint256 tokens) public tokens;
    mapping(address wallet => bool tgeClaimed) public hasClaimedTGE;
    mapping(address wallet => uint256 tokens) public tokensClaimed;
    mapping(address wallet => uint256 timestamp) public lastClaimTimestamps;

    constructor(IFactory.InitialConfig memory initialConfig) Ownable(msg.sender) {
        name = initialConfig.name;
        symbol = initialConfig.symbol;
        description = initialConfig.description;

        _pause();
    }

    /// Phase modifiers

    modifier canSetRegistrationPhase(
        uint256 _registrationStartsAt,
        uint256 _registrationDuration,
        uint256 _participationStartsAt,
        uint256 _participationDuration,
        address _acceptedToken,
        uint256 _price,
        uint256 _maxAllocation
    ) {
        if (_registrationStartsAt == 0) revert IIDOFull.IDO__Cannot_Be_Zero("Value cannot be zero");
        if (_registrationStartsAt <= block.timestamp) {
            revert IIDOFull.IDO__Time_Too_Close_To_Now("Time defined to close to now");
        }
        if (_registrationDuration == 0) revert IIDOFull.IDO__Cannot_Be_Zero("Value cannot be zero");
        if (_participationStartsAt == 0) revert IIDOFull.IDO__Cannot_Be_Zero("Value cannot be zero");
        if (_participationStartsAt <= block.timestamp) {
            revert IIDOFull.IDO__Time_Too_Close_To_Now("Time defined to close to now");
        }
        if (_participationDuration == 0) revert IIDOFull.IDO__Cannot_Be_Zero("Value cannot be zero");
        if (_acceptedToken == address(0)) revert IIDOFull.IDO__Invalid_Address("Invalid Address");
        if (_price == 0) revert IIDOFull.IDO__Cannot_Be_Zero("Value cannot be zero");
        if (_maxAllocation == 0) revert IIDOFull.IDO__Cannot_Be_Zero("Value cannot be zero");
        if (_participationStartsAt <= _registrationStartsAt + _registrationDuration) {
            revert IIDOFull.IDO__Not_Allowed("Not allowed");
        }
        _;
    }

    modifier canSetParticipationPhase(uint256 _minPerWallet, uint256 _maxPerWallet) {
        if (block.timestamp < registrationStartsAt + registrationDuration) {
            revert IIDOFull.IDO__Not_Allowed("Registration Phase Ongoing");
        }
        if (_minPerWallet == 0) revert IIDOFull.IDO__Cannot_Be_Zero("Value cannot be zero");
        if (_maxPerWallet == 0) revert IIDOFull.IDO__Cannot_Be_Zero("Value cannot be zero");
        if (_maxPerWallet <= _minPerWallet) revert IIDOFull.IDO__Not_Allowed("Not allowed");

        _;
    }

    modifier canSetVestingPhase(address _token, uint256 _vesting, uint256 _tgeUnlock) {
        if (block.timestamp <= participationStartsAt + participationDuration) {
            revert IIDOFull.IDO__Not_Allowed("Participation Phase Ongoing");
        }
        if (_token == address(0)) revert IIDOFull.IDO__Invalid_Address("Invalid Address");
        if (_token == acceptedToken) revert IIDOFull.IDO__Invalid_Address("Invalid Address");
        if (_vesting == 0) revert IIDOFull.IDO__Cannot_Be_Zero("Value cannot be zero");
        if (_vesting <= block.timestamp) revert IIDOFull.IDO__Time_Too_Close_To_Now("Time defined to close to now");
        if (_tgeUnlock == 0) revert IIDOFull.IDO__Cannot_Be_Zero("Value cannot be zero");
        _;
    }

    modifier canSetReleasePhase(
        uint256 _cliff,
        IIDOFull.ReleaseType _releaseType,
        IIDOFull.ClaimPeriodType _claimPeriodType,
        uint256 _releaseStartsAt,
        uint256 _releaseDuration
    ) {
        if (phase != IIDOFull.Phase.Vesting) revert IIDOFull.IDO__Not_Allowed("Not in vesting phase");
        if (block.timestamp < vesting) revert IIDOFull.IDO__Not_Allowed("Not in vesting phase");
        if (_cliff == 0) revert IIDOFull.IDO__Cannot_Be_Zero("Value cannot be zero");
        if (uint256(_releaseType) > 4) revert IIDOFull.IDO__Not_Allowed("Not allowed");
        if (uint256(_claimPeriodType) > 4) revert IIDOFull.IDO__Not_Allowed("Not allowed");
        if (_releaseStartsAt == 0) revert IIDOFull.IDO__Cannot_Be_Zero("Value cannot be zero");
        if (_releaseStartsAt <= block.timestamp) {
            revert IIDOFull.IDO__Time_Too_Close_To_Now("Time defined to close to now");
        }
        if (_releaseDuration == 0) revert IIDOFull.IDO__Cannot_Be_Zero("Value cannot be zero");
        _;
    }

    /// Users actions modifiers

    modifier canRegister(address wallet) {
        if (phase != IIDOFull.Phase.Registration) {
            revert IIDOFull.IDO__Not_In_Registration_Phase("Not in registration phase");
        }
        if (!whitelist[wallet]) revert IIDOFull.IDO__Not_Allowed("Wallet not whitelisted");
        if (blacklist[wallet]) revert IIDOFull.IDO__Wallet_Blacklisted("Wallet blacklisted");
        if (registrations[wallet]) revert IIDOFull.IDO__Wallet_Registered("Wallet already registered");
        _;
    }

    modifier canParticipate(address wallet, uint256 amount) {
        if (phase != IIDOFull.Phase.Participation) {
            revert IIDOFull.IDO__Not_In_Participation_Phase("Not in participation phase");
        }

        if (block.timestamp < participationStartsAt || block.timestamp > participationStartsAt + participationDuration)
        {
            revert IIDOFull.IDO__Not_In_Participation_Phase("Not in participation phase");
        }

        if (blacklist[wallet]) revert IIDOFull.IDO__Wallet_Blacklisted("Wallet blacklisted");
        if (!registrations[wallet] && !isPublic) revert IIDOFull.IDO__Not_Registered("Not registered");
        if (allocations[wallet] > 0) revert IIDOFull.IDO__Already_Participating("Wallet already participating");
        if (amount < minPerWallet) {
            revert IIDOFull.IDO__Insufficient_Amount_To_Participate("Insufficient amount to participate");
        }
        if (amount > maxPerWallet) revert IIDOFull.IDO__Exceeds_Max_Amount_Permitted("Exceeds max amount permitted");
        if (amount > ERC20(acceptedToken).balanceOf(wallet)) {
            revert IIDOFull.IDO__Insufficient_Amount_To_Participate("Insufficient amount to participate");
        }
        if (raised + amount > maxAllocation) {
            revert IIDOFull.IDO__Exceeds_Max_Amount_Permitted("Exceeds max amount permitted");
        }
        _;
    }

    modifier canClaimTGE(address wallet) {
        if (
            phase == IIDOFull.Phase.None || phase == IIDOFull.Phase.Registration
                || phase == IIDOFull.Phase.Participation || phase == IIDOFull.Phase.Invalid
        ) {
            revert IIDOFull.IDO__Not_Allowed("Not in the correct phase");
        }
        if (tokens[wallet] == 0) revert IIDOFull.IDO__No_Tokens_Available("No tokens available");
        if (hasClaimedTGE[wallet]) revert IIDOFull.IDO__Already_Claimed_TGE("Wallet already claimed TGE");
        _;
    }

    modifier canClaimtokens(address wallet) {
        if (phase != IIDOFull.Phase.Release) revert IIDOFull.IDO__Not_In_Release_Phase("Not in release phase");
        if (tokens[wallet] == 0) revert IIDOFull.IDO__No_Tokens_Available("No tokens available");
        if (lastClaimTimestamps[wallet] == block.timestamp) revert IIDOFull.IDO__Not_Allowed("Not allowed");

        if (block.timestamp - lastClaimTimestamps[wallet] < getClaimPeriodDuration(claimPeriodType)) {
            revert IIDOFull.IDO__Out_Claim_Period("Out of claim period");
        }
        _;
    }

    // External Functions

    function register(address wallet) external whenNotPaused canRegister(wallet) nonReentrant {
        registrations[wallet] = true;
        emit IIDOFull.Registered(wallet, block.timestamp);
    }

    function participate(address wallet, uint256 amount)
        external
        payable
        whenNotPaused
        canParticipate(wallet, amount)
        nonReentrant
    {
        allocations[wallet] = amount;
        raised += amount;

        // sets users tokens at the tge claim time
        uint256 userTokens = tokenAmountByParticipation(allocations[wallet]);
        tokens[wallet] = userTokens;
        tokensSold += userTokens;

        emit IIDOFull.Participating(wallet, amount, block.timestamp, registrations[wallet]);

        ERC20(acceptedToken).safeTransferFrom(wallet, address(this), amount);
    }

    // YOU NEED TO THINK ABOUT HAVE OR NOT A FUNCTION TO ADD IDO TOKENS TO THE CONTRACT
    // function addIDOTokens(address wallet) external whenNotPaused nonReentrant {}

    function claimTGE(address wallet) external whenNotPaused canClaimTGE(wallet) nonReentrant {
        uint256 tgeAmount = calculateTGETokens(wallet);

        hasClaimedTGE[wallet] = true;
        tokensClaimed[wallet] += tgeAmount;

        emit IIDOFull.TGEClaimed(wallet, tgeAmount);

        ERC20(token).safeTransfer(wallet, tgeAmount);
    }

    // Onwer functions

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function addToBlacklist(address wallet) external onlyOwner {
        registrations[wallet] = false;
        blacklist[wallet] = true;
    }

    function removeFromBlacklist(address wallet) external onlyOwner {
        blacklist[wallet] = false;
    }

    /// Phase Functions

    function setRegistrationPhase(
        uint256 _registrationStartsAt,
        uint256 _registrationDuration,
        uint256 _participationStartsAt,
        uint256 _participationDuration,
        address _acceptedToken,
        uint256 _price,
        uint256 _maxAllocation
    )
        external
        onlyOwner
        canSetRegistrationPhase(
            _registrationStartsAt,
            _registrationDuration,
            _participationStartsAt,
            _participationDuration,
            _acceptedToken,
            _price,
            _maxAllocation
        )
        nonReentrant
    {
        registrationStartsAt = _registrationStartsAt;
        registrationDuration = _registrationDuration;
        participationStartsAt = _participationStartsAt;
        participationDuration = _participationDuration;
        acceptedToken = _acceptedToken;
        price = _price;
        maxAllocation = _maxAllocation;

        phase = IIDOFull.Phase.Registration;
        emit IIDOFull.RegistrationSet(block.timestamp);
    }

    function setParticipationPhase(uint256 _minPerWallet, uint256 _maxPerWallet)
        external
        onlyOwner
        whenNotPaused
        canSetParticipationPhase(_minPerWallet, _maxPerWallet)
        nonReentrant
    {
        minPerWallet = _minPerWallet;
        maxPerWallet = _maxPerWallet;

        phase = IIDOFull.Phase.Participation;
        emit IIDOFull.ParticipationSet(block.timestamp);
    }

    function setVestingPhase(address _token, uint256 _vesting, uint256 _tgeUnlock)
        external
        onlyOwner
        whenNotPaused
        canSetVestingPhase(_token, _vesting, _tgeUnlock)
        nonReentrant
    {
        token = _token;
        vesting = _vesting;
        tgeUnlock = _tgeUnlock;

        phase = IIDOFull.Phase.Vesting;
        emit IIDOFull.VestingSet(block.timestamp);
    }

    function setReleasePhase(
        uint256 _cliff,
        IIDOFull.ReleaseType _releaseType,
        IIDOFull.ClaimPeriodType _claimPeriodType,
        uint256 _releaseStartsAt,
        uint256 _releaseDuration
    )
        external
        onlyOwner
        whenNotPaused
        canSetReleasePhase(_cliff, _releaseType, _claimPeriodType, _releaseStartsAt, _releaseDuration)
        nonReentrant
    {
        cliff = _cliff;
        releaseType = _releaseType;
        claimPeriodType = _claimPeriodType;
        releaseStartsAt = _releaseStartsAt;
        releaseDuration = _releaseDuration;

        phase = IIDOFull.Phase.Release;
        emit IIDOFull.ReleaseSet(block.timestamp);
    }

    function allowPublic() external onlyOwner whenNotPaused nonReentrant {
        if (phase != IIDOFull.Phase.Participation) {
            revert IIDOFull.IDO__Not_In_Participation_Phase("Not in participation phase");
        }

        if (block.timestamp > participationStartsAt + participationDuration) {
            revert IIDOFull.IDO__Not_Allowed("Participation phase ended");
        }
        isPublic = true;
        emit IIDOFull.PublicAllowed(block.timestamp);
    }

    function withdrawParticipations() external onlyOwner nonReentrant {
        if (acceptedToken == address(0)) revert IIDOFull.IDO__Invalid_Address("Invalid Address");

        uint256 balance = ERC20(acceptedToken).balanceOf(address(this));

        if (balance == 0) revert IIDOFull.IDO__Insufficient_Balance("Nothing to claim");

        raised = 0;
        emit IIDOFull.ParticipationsWithdrawal(balance);

        ERC20(acceptedToken).safeTransfer(owner(), balance);
    }

    function withdrawIDOTokens() external onlyOwner nonReentrant {
        if (token == address(0)) revert IIDOFull.IDO__Invalid_Address("Invalid Address");

        uint256 balance = ERC20(token).balanceOf(address(this));

        if (balance == 0) revert IIDOFull.IDO__Insufficient_Balance("Nothing to claim");

        emit IIDOFull.RemainingTokensWithdrawal(balance);

        ERC20(token).safeTransfer(owner(), balance);
    }

    /// @dev Owner functions to update params

    /// Registration Phase update functions
    function updateAcceptedToken(address _acceptedToken) external onlyOwner nonReentrant {
        if (phase != IIDOFull.Phase.Registration) revert IIDOFull.IDO__Not_Allowed("Not in registration phase");
        if (_acceptedToken == address(0)) revert IIDOFull.IDO__Invalid_Address("Invalid Address");

        if (block.timestamp > registrationStartsAt + registrationDuration) {
            revert IIDOFull.IDO__Not_Allowed("Registration phase ended");
        }

        acceptedToken = _acceptedToken;
        emit IIDOFull.IDOConfigUpdated("acceptedToken", abi.encodePacked(_acceptedToken));
    }

    function updateParticipationStart(uint256 _participationStartsAt) external onlyOwner nonReentrant {
        if (phase != IIDOFull.Phase.Registration) revert IIDOFull.IDO__Not_Allowed("Not in registration phase");
        if (_participationStartsAt == 0) revert IIDOFull.IDO__Cannot_Be_Zero("Value cannot be zero");
        if (_participationStartsAt <= block.timestamp) {
            revert IIDOFull.IDO__Time_Too_Close_To_Now("Time defined to close to now");
        }
        if (block.timestamp > registrationStartsAt + registrationDuration) {
            revert IIDOFull.IDO__Not_Allowed("Registration phase ended");
        }

        participationStartsAt = _participationStartsAt;
        emit IIDOFull.IDOConfigUpdated("participationStartsAt", abi.encodePacked(_participationStartsAt));
    }

    function updateParticipationDuration(uint256 _participationDuration) external onlyOwner nonReentrant {
        if (phase != IIDOFull.Phase.Registration) revert IIDOFull.IDO__Not_Allowed("Not in registration phase");
        if (_participationDuration == 0) revert IIDOFull.IDO__Cannot_Be_Zero("Value cannot be zero");
        if (block.timestamp > registrationStartsAt + registrationDuration) {
            revert IIDOFull.IDO__Not_Allowed("Registration phase ended");
        }

        participationDuration = _participationDuration;
        emit IIDOFull.IDOConfigUpdated("participationDuration", abi.encodePacked(_participationDuration));
    }

    // uint256 public price; // ido token price in accepted token
    function updateIDOTokenPrice(uint256 _price) external onlyOwner nonReentrant {
        if (phase != IIDOFull.Phase.Registration) revert IIDOFull.IDO__Not_Allowed("Not in registration phase");
        if (_price == 0) revert IIDOFull.IDO__Cannot_Update_With_Zero("Value cannot be zero");
        if (block.timestamp > registrationStartsAt + registrationDuration) {
            revert IIDOFull.IDO__Not_Allowed("Registration phase ended");
        }

        price = _price;
        emit IIDOFull.IDOConfigUpdated("price", abi.encodePacked(_price));
    }

    function updateMaxAllocation(uint256 _maxAllocation) external onlyOwner nonReentrant {
        if (phase != IIDOFull.Phase.Registration) revert IIDOFull.IDO__Not_Allowed("Not in registration phase");
        if (_maxAllocation == 0) revert IIDOFull.IDO__Cannot_Update_With_Zero("Value cannot be zero");
        if (block.timestamp > registrationStartsAt + registrationDuration) {
            revert IIDOFull.IDO__Not_Allowed("Registration phase ended");
        }

        maxAllocation = _maxAllocation;
        emit IIDOFull.IDOConfigUpdated("maxAllocation", abi.encodePacked(_maxAllocation));
    }

    /// Participation Phase update functions

    function updateMinPerWallet(uint256 _minPerWallet) external onlyOwner nonReentrant {
        if (phase != IIDOFull.Phase.Participation) revert IIDOFull.IDO__Not_Allowed("Not in participation phase");
        if (_minPerWallet == 0) revert IIDOFull.IDO__Cannot_Update_With_Zero("Value cannot be zero");
        if (_minPerWallet >= maxPerWallet) revert IIDOFull.IDO__Not_Allowed("Value to high");
        if (block.timestamp > participationStartsAt + participationDuration) {
            revert IIDOFull.IDO__Not_Allowed("Participation phase ended");
        }

        minPerWallet = _minPerWallet;
        emit IIDOFull.IDOConfigUpdated("minPerWallet", abi.encodePacked(_minPerWallet));
    }

    function updateMaxPerWallet(uint256 _maxPerWallet) external onlyOwner nonReentrant {
        if (phase != IIDOFull.Phase.Participation) revert IIDOFull.IDO__Not_Allowed("Not in participation phase");
        if (_maxPerWallet == 0) revert IIDOFull.IDO__Cannot_Update_With_Zero("Value cannot be zero");
        if (_maxPerWallet <= minPerWallet) {
            revert IIDOFull.IDO__Not_Allowed("Value too low");
        }
        if (block.timestamp > participationStartsAt + participationDuration) {
            revert IIDOFull.IDO__Not_Allowed("Participation phase ended");
        }

        maxPerWallet = _maxPerWallet;
        emit IIDOFull.IDOConfigUpdated("maxPerWallet", abi.encodePacked(_maxPerWallet));
    }

    /// Vesting Phase update functions

    function updateTokenAddress(address _token) external onlyOwner nonReentrant {
        if (phase != IIDOFull.Phase.Vesting) revert IIDOFull.IDO__Not_Allowed("Not in vesting phase");
        if (_token == address(0)) revert IIDOFull.IDO__Invalid_Address("Invalid Address");
        if (_token == acceptedToken) revert IIDOFull.IDO__Invalid_Address("Invalid Address");
        if (block.timestamp >= vesting) {
            revert IIDOFull.IDO__Not_Allowed("Vesting phase already started");
        }

        token = _token;
        emit IIDOFull.IDOConfigUpdated("token", abi.encodePacked(_token));
    }

    // uint256 public vesting; // timestamp eg. unlock tokens at certain date
    function updateVestingTimestamp(uint256 _vestingTimestamp) external onlyOwner nonReentrant {
        if (phase != IIDOFull.Phase.Vesting) revert IIDOFull.IDO__Not_Allowed("Not in vesting phase");
        if (_vestingTimestamp == 0) revert IIDOFull.IDO__Cannot_Update_With_Zero("Value cannot be zero");
        if (block.timestamp >= vesting) {
            revert IIDOFull.IDO__Not_Allowed("Vesting phase already started");
        }

        vesting = _vestingTimestamp;
        emit IIDOFull.IDOConfigUpdated("vesting", abi.encodePacked(_vestingTimestamp));
    }

    // uint256 public tgeUnlock; // percentage that will be available for users to claim after vesting
    function updateTGEUnlockPercentage(uint256 _percentage) external onlyOwner nonReentrant {
        if (phase != IIDOFull.Phase.Vesting) revert IIDOFull.IDO__Not_Allowed("Not in vesting phase");
        if (_percentage == 0) revert IIDOFull.IDO__Cannot_Update_With_Zero("Value cannot be zero");
        if (block.timestamp >= vesting) {
            revert IIDOFull.IDO__Not_Allowed("Vesting phase already started");
        }

        tgeUnlock = _percentage;
        emit IIDOFull.IDOConfigUpdated("tgeUnlock", abi.encodePacked(_percentage));
    }

    /// Release Phase update functions

    // uint256 public cliff; // timestamp eg. 4 months blocked without unlock and releases
    function updateCliffPeriod(uint256 _cliff) external onlyOwner nonReentrant {
        if (phase != IIDOFull.Phase.Release) revert IIDOFull.IDO__Not_Allowed("Not in release phase");
        if (block.timestamp >= releaseStartsAt) revert IIDOFull.IDO__Not_Allowed("Release phase already started");
        if (_cliff == 0) revert IIDOFull.IDO__Cannot_Update_With_Zero("Value cannot be zero");

        cliff = _cliff;
        emit IIDOFull.IDOConfigUpdated("cliff", abi.encodePacked(_cliff));
    }

    // IIDOFull.ReleaseType public releaseType; // release type selected when contract is deployed
    function updateReleaseType(IIDOFull.ReleaseType _releaseType) external onlyOwner nonReentrant {
        if (phase != IIDOFull.Phase.Release) revert IIDOFull.IDO__Not_Allowed("Not in release phase");
        if (block.timestamp >= releaseStartsAt) revert IIDOFull.IDO__Not_Allowed("Release phase already started");
        if (uint256(_releaseType) > 4) revert IIDOFull.IDO__Wrong_Release_Type("Wrong release type");

        releaseType = _releaseType;
        emit IIDOFull.IDOConfigUpdated("releaseType", abi.encodePacked(_releaseType));
    }

    function updateClaimPeriodType(IIDOFull.ClaimPeriodType _claimPeriodType) external onlyOwner nonReentrant {
        if (phase != IIDOFull.Phase.Release) revert IIDOFull.IDO__Not_Allowed("Not in release phase");
        if (block.timestamp >= releaseStartsAt) revert IIDOFull.IDO__Not_Allowed("Release phase already started");
        if (uint256(_claimPeriodType) > 4) revert IIDOFull.IDO__Wrong_Claim_Period_Type("Wrong claim period type");

        claimPeriodType = _claimPeriodType;
        emit IIDOFull.IDOConfigUpdated("claimPeriodType", abi.encodePacked(_claimPeriodType));
    }

    // uint256 public releaseStartsAt; // timestamp
    function updateReleaseStartsAt(uint256 _startsAtTimestamp) external onlyOwner nonReentrant {
        if (phase != IIDOFull.Phase.Release) revert IIDOFull.IDO__Not_Allowed("Not in release phase");
        if (block.timestamp >= releaseStartsAt) revert IIDOFull.IDO__Not_Allowed("Release phase already started");
        if (_startsAtTimestamp == 0) revert IIDOFull.IDO__Cannot_Update_With_Zero("Value cannot be zero");

        releaseStartsAt = _startsAtTimestamp;
        emit IIDOFull.IDOConfigUpdated("releaseStartsAt", abi.encodePacked(_startsAtTimestamp));
    }

    // uint256 public releaseDuration; // timestamp eg. 3 months
    function updateReleaseDuration(uint256 _durationTimestamp) external onlyOwner nonReentrant {
        if (phase != IIDOFull.Phase.Release) revert IIDOFull.IDO__Not_Allowed("Not in release phase");
        if (block.timestamp >= releaseStartsAt) revert IIDOFull.IDO__Not_Allowed("Release phase already started");
        if (_durationTimestamp == 0) revert IIDOFull.IDO__Cannot_Update_With_Zero("Value cannot be zero");

        releaseDuration = _durationTimestamp;
        emit IIDOFull.IDOConfigUpdated("releaseDuration", abi.encodePacked(_durationTimestamp));
    }

    /**
     * @dev Adds multiple wallets to the whitelist.
     * @param wallets The array of addresses to be added.
     */
    function addBatchToWhitelist(address[] calldata wallets) external onlyOwner {
        for (uint256 i = 0; i < wallets.length; i++) {
            address wallet = wallets[i];

            if (!whitelist[wallet]) {
                whitelist[wallet] = true;
            }
        }

        emit IIDOFull.Whitelisted(wallets);
    }

    function claimUnlockedTokens(address wallet) external canClaimtokens(wallet) nonReentrant {
        uint256 unlockedTokens = calculateUnlockableTokens(wallet);

        // Update last claim timestamp based on the release type
        lastClaimTimestamps[wallet] = block.timestamp - (block.timestamp % getReleaseTypeInSeconds(releaseType));
        emit IIDOFull.Claimed(wallet, unlockedTokens);

        ERC20(token).safeTransfer(wallet, unlockedTokens);
    }

    /// View Functions

    // Calculates the token amount based on the participation
    function tokenAmountByParticipation(uint256 amount) public view returns (uint256 tokensPerAllocation) {
        tokensPerAllocation = (amount / price) * 1e12;
    }

    // Calculates the amount of unlockable tokens in TGE
    function calculateTGETokens(address wallet) public view returns (uint256 tgeAmount) {
        tgeAmount = tokens[wallet] * tgeUnlock / 100;
    }

    function calculateUnlockableTokens(address wallet) public view returns (uint256 unlockableTokens) {
        if (phase != IIDOFull.Phase.Release) return 0; // Not in release phase
        if (block.timestamp <= releaseStartsAt) return 0; // Release not started
        if (blacklist[wallet]) return 0; // Wallet is blacklisted
        if (allocations[wallet] == 0) return 0; // Wallet didn't participate

        uint256 userTokens = hasClaimedTGE[wallet]
            ? tokens[wallet] - tokensClaimed[wallet]
            : tokens[wallet] - calculateTGETokens(wallet) - tokensClaimed[wallet];

        uint256 releaseEndsAt = releaseStartsAt + releaseDuration;
        uint256 currentTimestamp = block.timestamp > releaseEndsAt ? releaseEndsAt : block.timestamp;

        uint256 elapsedTime = lastClaimTimestamps[wallet] > 0
            ? currentTimestamp - lastClaimTimestamps[wallet]
            : currentTimestamp - releaseStartsAt;

        // Adjust elapsed time based on release type
        uint256 elapsedTimeInReleaseType = elapsedTime / getReleaseTypeInSeconds(releaseType);

        // Calculate percentage released (preventing potential overflow)
        uint256 percentageReleased = (elapsedTimeInReleaseType * 100) / releaseDuration;

        // Assuming linear release model
        unlockableTokens = (userTokens * percentageReleased) / 100;

        return unlockableTokens;
    }

    function getReleaseTypeInSeconds(IIDOFull.ReleaseType _releaseType)
        public
        pure
        returns (uint256 releaseTypeInSeconds)
    {
        if (_releaseType == IIDOFull.ReleaseType.Minute) releaseTypeInSeconds = 1 minutes;
        else if (_releaseType == IIDOFull.ReleaseType.Day) releaseTypeInSeconds = 1 days;
        else if (_releaseType == IIDOFull.ReleaseType.Week) releaseTypeInSeconds = 7 days;
        else if (_releaseType == IIDOFull.ReleaseType.Month) releaseTypeInSeconds = 30 days;
        else if (_releaseType == IIDOFull.ReleaseType.Year) releaseTypeInSeconds = 365 days;
    }

    function getClaimPeriodDuration(IIDOFull.ClaimPeriodType _claimPeriodType)
        public
        pure
        returns (uint256 claimPeriodTypeInSeconds)
    {
        if (_claimPeriodType == IIDOFull.ClaimPeriodType.Day) claimPeriodTypeInSeconds = 1 days;
        else if (_claimPeriodType == IIDOFull.ClaimPeriodType.Week) claimPeriodTypeInSeconds = 7 days;
        else if (_claimPeriodType == IIDOFull.ClaimPeriodType.Month) claimPeriodTypeInSeconds = 30 days;
        else if (_claimPeriodType == IIDOFull.ClaimPeriodType.ThreeMonths) claimPeriodTypeInSeconds = 90 days;
        else if (_claimPeriodType == IIDOFull.ClaimPeriodType.Year) claimPeriodTypeInSeconds = 365 days;
    }

    function countDecimalPlaces(uint256 num) public pure returns (uint8) {
        for (uint8 i = 0; i < 256; i++) {
            if (num == 0 || (num % 10 != 0 && num % 10 ** (i + 1) == 0)) {
                // Check for decimal point
                return i;
            }
            num /= 10;
        }
        return 0; // Number is zero
    }

    function to18Decimals(uint256 value) public pure returns (uint256) {
        uint8 decimals = countDecimalPlaces(value);

        if (decimals == 18) {
            return value; // Already has 18 decimal places
        } else if (decimals > 18) {
            revert("Value has more than 18 decimal places"); // Prevent overflow
        } else {
            // Check for potential overflow before multiplication
            if (value > (type(uint256).max - 1) / 10 ** (18 - decimals)) {
                revert("Multiplication would overflow");
            }
            return value * 10 ** (18 - decimals);
        }
    }

    function calculatePercentageReleased(uint256 _elapsedTime, uint256 _releaseDuration)
        public
        pure
        returns (uint256 percentageReleased)
    {
        return (_elapsedTime * 100) / _releaseDuration;
    }
}
