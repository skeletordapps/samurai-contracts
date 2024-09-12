// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {IPoints} from "./interfaces/IPoints.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title SamuraiPoints
 * @dev A custom ERC-20 token designed to represent points within a specific ecosystem.
 * It features restricted transfers, controlled minting and burning, and an access control mechanism to ensure proper management.
 */
contract SamuraiPoints is ERC20, Ownable, AccessControl {
    using SafeERC20 for ERC20;

    // Define the MANAGER_ROLE for access control
    bytes32 public constant MANAGER_ROLE = keccak256("MANAGER_ROLE");

    // Constructor to initialize the contract
    constructor() ERC20("Samurai Points", "SPS") Ownable(msg.sender) {
        // Grant the initial manager role to the deployer
        grantManagerRole(msg.sender);
    }

    /**
     * @notice Only addresses with the `MANAGER_ROLE` can call this function.
     * @dev Mints points to a specified address.
     * @param to The address to receive the points.
     * @param numOfPoints The number of points to mint.
     */
    function mint(address to, uint256 numOfPoints) external onlyRole(MANAGER_ROLE) {
        // Mint the corresponding number of tokens
        _mint(to, numOfPoints);
        // Emit an event to notify of the points addition
        emit IPoints.MintedPoints(to, numOfPoints);
    }

    /**
     * @notice Only addresses with the `MANAGER_ROLE` can call this function.
     * @dev Burns points from a specified address.
     * @param from The address from which to burn the points.
     * @param numOfPoints The number of points to burn.
     * require The specified address has sufficient points to burn.
     */
    function burn(address from, uint256 numOfPoints) external onlyRole(MANAGER_ROLE) {
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
     * @dev Grants the `MANAGER_ROLE` to a specified address.
     * @param account The address to grant the role to.
     */
    function grantManagerRole(address account) public onlyOwner {
        // Grant the role using AccessControl
        _grantRole(MANAGER_ROLE, account);
    }

    /**
     * @notice Only the contract owner can call this function.
     * @dev Revokes the `MANAGER_ROLE` from a specified address.
     * @param account The address to revoke the role from.
     */
    function revokeManagerRole(address account) public onlyOwner {
        // Revoke the role using AccessControl
        _revokeRole(MANAGER_ROLE, account);
    }
}
