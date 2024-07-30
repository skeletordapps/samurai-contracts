// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IDO} from "./IDO.sol";
import {IFactory} from "./interfaces/IFactory.sol";

contract Factory is Ownable {
    uint256 public totalIDOs;
    mapping(uint256 index => address idoAddress) public idos;

    constructor() Ownable(msg.sender) {}

    function createIDO(IFactory.InitialConfig memory initialConfig) external onlyOwner returns (IDO ido) {
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
