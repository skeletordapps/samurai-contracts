// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IPoints} from "./interfaces/IPoints.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";
import {console} from "forge-std/console.sol";

/**
 * @title SamuraiPoints
 * @dev A custom ERC-20 token designed to represent points within a specific ecosystem.
 * It features restricted transfers, controlled minting and burning, and an access control mechanism to ensure proper management.
 */
contract SamuraiPoints is ERC20, Ownable, AccessControl {
    using SafeERC20 for ERC20;

    // Define the roles for access control
    bytes32 public constant BOOSTER_ROLE = keccak256("BOOSTER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    mapping(uint8 boost => uint256 multiplier) public boosts;
    mapping(address wallet => UD60x18 boostMultiplier) private boostedAccounts;

    constructor() ERC20("Samurai Points", "SPS") Ownable(msg.sender) {
        // Grant the all roles to the deployer
        grantRole(IPoints.Roles.BOOSTER, msg.sender);
        grantRole(IPoints.Roles.MINTER, msg.sender);
        grantRole(IPoints.Roles.BURNER, msg.sender);

        // initialize boosts
        boosts[1] = 0.25 ether; // 1 -> 0.25x Points Boost
        boosts[2] = 0.5 ether; // 2 -> 0.5x Points
        boosts[3] = 1 ether; // 3 -> 1x Points
        boosts[4] = 2 ether; // 4 -> 2x Points
        boosts[5] = 3 ether; // 5 -> 3x Points
    }

    modifier validAddress(address account) {
        require(account != address(0), IPoints.NotAllowed("Invalid address"));
        _;
    }

    /**
     * @notice Only addresses with the `BOOSTER_ROLE` can call this function.
     * @dev Boosts are used as multipliers of minted points.
     * @param to The address that receives a boost.
     * @param boost The representative boost number (1-5).
     */
    function setBoost(address to, uint8 boost) external onlyRole(BOOSTER_ROLE) validAddress(to) {
        require(boost < 6, IPoints.NotAllowed("Invalid boost amount"));

        uint256 _boost = boosts[boost];
        boostedAccounts[to] = ud(_boost);
        emit IPoints.BoostSet(to, _boost);
    }

    /**
     * @notice Only addresses with the `MINTER_ROLE` can call this function.
     * @dev Mints points to a specified address.
     * @param to The address to receive the points.
     * @param numOfPoints The number of points to mint.
     */
    function mint(address to, uint256 numOfPoints) external onlyRole(MINTER_ROLE) validAddress(to) {
        require(numOfPoints > 0, IPoints.NotAllowed("Invalid numOfPoints"));

        UD60x18 boost = boostedAccounts[to];
        UD60x18 points = ud(numOfPoints);

        if (boost.intoUint256() > 0) points.add(ud(numOfPoints).mul(boost));

        _mint(to, points.intoUint256());

        // Emit an event to notify of the points addition
        emit IPoints.MintedPoints(to, points.intoUint256(), boost.intoUint256());
    }

    /**
     * @notice Only addresses with the `BURNER_ROLE` can call this function.
     * @dev Burns points from a specified address.
     * @param from The address from which to burn the points.
     * @param numOfPoints The number of points to burn.
     * require The specified address has sufficient points to burn.
     */
    function burn(address from, uint256 numOfPoints) external onlyRole(BURNER_ROLE) validAddress(from) {
        require(balanceOf(from) >= numOfPoints, IPoints.NotAllowed("Insufficient points"));

        // Burn the corresponding number of tokens
        _burn(from, numOfPoints);
        // Emit an event to notify of the points removal
        emit IPoints.BurnedPoints(from, numOfPoints);
    }

    /**
     * @dev Reverts any attempt to transfer points directly.
     */
    function transfer(address, uint256) public pure override returns (bool) {
        revert IPoints.NotAllowed("Direct transfers are not allowed");
    }

    /**
     * @dev Reverts any attempt to transfer points from one address to another.
     */
    function transferFrom(address, address, uint256) public pure override returns (bool) {
        revert IPoints.NotAllowed("Direct transfers are not allowed");
    }

    /**
     * @notice Only the contract owner can call this function.
     * @dev Grants a specific role `IPoints.Roles` to a specified address.
     * @param account The address to grant the role to.
     */
    function grantRole(IPoints.Roles role, address account) public onlyOwner validAddress(account) {
        // Grant the role using AccessControl
        if (role == IPoints.Roles.BOOSTER) _grantRole(BOOSTER_ROLE, account);
        if (role == IPoints.Roles.MINTER) _grantRole(MINTER_ROLE, account);
        if (role == IPoints.Roles.BURNER) _grantRole(BURNER_ROLE, account);
    }

    /**
     * @notice Only the contract owner can call this function.
     * @dev Revokes a specific role `IPoints.Roles` from a specified address.
     * @param account The address to revoke the role from.
     */
    function revokeRole(IPoints.Roles role, address account) public onlyOwner validAddress(account) {
        // Revoke the role using AccessControl
        if (role == IPoints.Roles.BOOSTER) _revokeRole(BOOSTER_ROLE, account);
        if (role == IPoints.Roles.MINTER) _revokeRole(MINTER_ROLE, account);
        if (role == IPoints.Roles.BURNER) _revokeRole(BURNER_ROLE, account);
    }

    /**
     * @notice Returns boost amount of an account.
     * @param account The address to check it's boost.
     */
    function boostOf(address account) public view validAddress(account) returns (uint256) {
        return boostedAccounts[account].intoUint256();
    }
}
