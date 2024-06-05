// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VestingClaim is Ownable(msg.sender) {
    struct ClaimInfo {
        uint256 claimId;
        uint256 amount;
        bool isAllClaimed;
        bool isInitialClaimed;
        uint256 totalClaimed;
        uint256 totalAmount;
        uint256 startTime; //   start time of the vesting in seconds
        uint256 endTime; //   end time of the vesting in seconds
        uint256 initialReleasePercentage; // percentage of the total amount to be released initially
    }

    // store signature of the claim in a map to avoid replay attack

    mapping(bytes => bool) public claimedSignatures;
    mapping(uint256 => ClaimInfo) public vestingLimits;

    event VestedAmount(uint256 _claimId, uint256 _value, bool _isAllClaimed, bool _isInitialClaimed);

    address public signerAddress;

    IERC20 private immutable vestingToken;

    constructor(address _token, address _signerAddress) {
        require(_token != address(0x0));
        require(_signerAddress != address(0x0));
        vestingToken = IERC20(_token);
        signerAddress = _signerAddress;
    }

    function claim(uint256 _nonce, ClaimInfo[] calldata claimInfos, bytes calldata _signature) external {
        require(!claimedSignatures[_signature], "SAMV: Signature already claimed");
        bytes32 mintData = keccak256(abi.encode(claimInfos));
        address signerWallet = verifySignature(_nonce, mintData, _signature); // Verifying signature
        require(signerWallet == signerAddress, "SAMV: Not authorized to claim");
        for (uint256 i = 0; i < claimInfos.length; i++) {
            require(claimInfos[i].claimId > 0, "SAMV: Invalid claim id");
            if (vestingLimits[claimInfos[i].claimId].claimId == 0) {
                vestingLimits[claimInfos[i].claimId] = claimInfos[i];
            }
            uint256 vestedAmount = 0;
            if (claimInfos[i].isAllClaimed) {
                uint256 remainingAmount =
                    vestingLimits[claimInfos[i].claimId].totalAmount - vestingLimits[claimInfos[i].claimId].totalClaimed;
                vestedAmount = remainingAmount / 2; // 50% of the remaining amount
                vestingLimits[claimInfos[i].claimId].isAllClaimed = true;
            } else {
                vestedAmount = getVestedAmount(claimInfos[i].claimId);
            }
            require(vestedAmount > 0, "SAMV: No vested amount");
            vestingLimits[claimInfos[i].claimId].totalClaimed += vestedAmount;
            vestingLimits[claimInfos[i].claimId].isInitialClaimed = true;
            claimedSignatures[_signature] = true;
            vestingToken.transfer(msg.sender, vestedAmount); // the token we using for vesting is EIP-20 compliant
            emit VestedAmount(
                claimInfos[i].claimId, vestedAmount, claimInfos[i].isAllClaimed, claimInfos[i].isInitialClaimed
            );
        }
    }

    function verifySignature(uint256 _nonce, bytes32 _mintData, bytes calldata _signature)
        internal
        view
        returns (address)
    {
        return ECDSA.recover(keccak256(abi.encode(msg.sender, _nonce, _mintData)), _signature);
    }
    // withdraw tokens from contract

    function withdrawTokens(uint256 _amount) external onlyOwner {
        vestingToken.transfer(msg.sender, _amount);
    }

    function getVestedAmount(uint256 _claimId) public view returns (uint256) {
        ClaimInfo storage _claimInfo = vestingLimits[_claimId];
        require(_claimInfo.startTime > 0, "SAMV: Claim not found");
        uint256 initialReleaseAmount = 0;
        if (_claimInfo.isAllClaimed) {
            return 0;
        }
        if (_claimInfo.initialReleasePercentage > 0) {
            initialReleaseAmount = (_claimInfo.totalAmount * _claimInfo.initialReleasePercentage) / 100;
        }
        uint256 alreadyClaimedAmount = _claimInfo.totalClaimed;
        uint256 totalAmount = _claimInfo.totalAmount - initialReleaseAmount;
        if (_claimInfo.isInitialClaimed && _claimInfo.initialReleasePercentage > 0) {
            alreadyClaimedAmount -= initialReleaseAmount;
        }
        uint256 currentTime = block.timestamp;
        if (currentTime > _claimInfo.endTime) {
            currentTime = _claimInfo.endTime;
        }
        if (currentTime < _claimInfo.startTime) {
            return 0;
        }
        uint256 vestedAmount = 0; // vested amount to be returned to the user. Value is based on time elapsed and  intial release percentage
        uint256 startTimestamp = _claimInfo.startTime;
        uint256 endTimestamp = _claimInfo.endTime;
        uint256 elapsedTime = currentTime - startTimestamp;
        uint256 vestingDuration = endTimestamp - startTimestamp;

        uint256 currentVestingAmount = (totalAmount * elapsedTime) / vestingDuration; // value according to the time elapsed until now from start of vesting period.
        vestedAmount = currentVestingAmount - alreadyClaimedAmount;

        if (_claimInfo.initialReleasePercentage > 0 && !_claimInfo.isInitialClaimed) {
            vestedAmount += initialReleaseAmount;
        }
        return vestedAmount;
    }
}
