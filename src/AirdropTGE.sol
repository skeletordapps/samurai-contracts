// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {console} from "forge-std/console.sol";

contract AirdropTGE is Ownable {
    using SafeERC20 for ERC20;

    ERC20 public token;
    address[] public wallets;
    uint256[] public amounts;
    bool public canAirdrop;
    uint256 public totalToAirdrop;
    uint256 public totalAirdroped;

    constructor(address _token, address[] memory _wallets, uint256[] memory _amounts) Ownable(msg.sender) {
        require(_token != address(0), "Invalid address");
        require(_wallets.length == _amounts.length, "Invalid length");

        uint256 _totalToAirdrop;
        for (uint256 i = 0; i < _amounts.length; i++) {
            _totalToAirdrop += _amounts[i];
        }

        token = ERC20(_token);
        totalToAirdrop = _totalToAirdrop;
        wallets = _wallets;
        amounts = _amounts;
        canAirdrop = true;
    }

    function send() external onlyOwner {
        require(canAirdrop, "Already airdroped");
        require(token.balanceOf(owner()) >= totalToAirdrop, "Insufficient balance");

        uint256 _totalAirdroped;

        for (uint256 i = 0; i < wallets.length; i++) {
            _totalAirdroped += amounts[i];
            token.safeTransferFrom(msg.sender, wallets[i], amounts[i]);
        }

        require(totalToAirdrop == _totalAirdroped, "Transfers failed");
        canAirdrop = false;
        totalAirdroped = _totalAirdroped;
    }
}
