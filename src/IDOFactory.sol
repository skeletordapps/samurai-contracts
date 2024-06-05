// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IDOFull} from "./IDOFull.sol";
import {IFactory} from "./interfaces/IFactory.sol";

contract Factory is Ownable {
    uint256 public totalIDOs;
    mapping(uint256 index => address idoAddress) public idos;

    event IDOCreated(uint256 chainId, IFactory.InitialConfig initialConfig);

    modifier canCreateIDO(IFactory.InitialConfig memory initialConfig) {
        if (keccak256(bytes(initialConfig.name)) == keccak256(bytes(""))) revert IFactory.Factory__Cannot_Be_Blank();
        if (keccak256(bytes(initialConfig.symbol)) == keccak256(bytes(""))) revert IFactory.Factory__Cannot_Be_Blank();
        if (keccak256(bytes(initialConfig.description)) == keccak256(bytes(""))) {
            revert IFactory.Factory__Cannot_Be_Blank();
        }
        _;
    }

    constructor() Ownable(msg.sender) {}

    function createIDO(IFactory.InitialConfig memory initialConfig)
        external
        onlyOwner
        canCreateIDO(initialConfig)
        returns (IDOFull ido)
    {
        ido = new IDOFull(initialConfig);
        idos[totalIDOs] = address(ido);
        totalIDOs += 1;

        emit IDOCreated(block.chainid, initialConfig);

        return ido;
    }
}
