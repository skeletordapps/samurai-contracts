// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDCMock is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 100_000_000 * (10 ** uint256(decimals())));
    }

    function decimals() public view override returns (uint8) {
        return 6;
    }

    function testMock() public {}
}
