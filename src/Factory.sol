// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IDO} from "./IDO.sol";
import {IFactory} from "./interfaces/IFactory.sol";

contract Factory is Ownable, Pausable, ReentrancyGuard {
    uint256 public totalIDOs;
    mapping(uint256 index => address idoAddress) public idos;

    constructor() Ownable(msg.sender) {}

    /**
     * @dev Pauses all token transfers.
     * Can only be called by the contract owner.
     */
    function pause() public onlyOwner {
        _pause();
    }

    /**
     * @dev Unpauses token transfers.
     * Can only be called by the contract owner.
     */
    function unpause() public onlyOwner {
        _unpause();
    }

    function createIDO(IFactory.InitialConfig memory initialConfig)
        external
        onlyOwner
        whenNotPaused
        nonReentrant
        returns (IDO ido)
    {
        ido = new IDO(
            initialConfig.samuraiTiers,
            initialConfig.acceptedToken,
            initialConfig.usingETH,
            initialConfig.usingLinkedWallet,
            initialConfig.vestingType,
            initialConfig.amounts,
            initialConfig.periods,
            initialConfig.ranges,
            initialConfig.refund
        );
        idos[totalIDOs] = address(ido);
        totalIDOs += 1;

        ido.transferOwnership(owner());

        emit IFactory.IDOCreated(block.chainid, initialConfig);

        return ido;
    }
}
