// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {AirdropTGE} from "../../../src/AirdropTGE.sol";
import {DeployAirdropTGE} from "../../../script/DeployAirdropTGE.s.sol";
import {console} from "forge-std/console.sol";

contract AirdropTGETest is Test {
    uint256 fork;
    string public RPC_URL;

    DeployAirdropTGE deployer;
    AirdropTGE airdrop;
    address owner;

    ERC20 token;
    bool canAirdrop;
    uint256 totalToAirdrop;

    uint256 tgeAmount = 115657.149 ether;

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployAirdropTGE();
        airdrop = deployer.run();
        owner = airdrop.owner();
        token = airdrop.token();
        canAirdrop = airdrop.canAirdrop();
        totalToAirdrop = airdrop.totalToAirdrop();
    }

    function testConstructor() public view {
        assertTrue(canAirdrop);
        assertEq(totalToAirdrop, tgeAmount);
    }

    function testCanAirdrop() external {
        assertTrue(airdrop.canAirdrop());

        uint256 wallet2Start = token.balanceOf(airdrop.wallets(1));
        uint256 wallet8Start = token.balanceOf(airdrop.wallets(7));

        deal(address(token), owner, tgeAmount);

        vm.startPrank(owner);
        token.approve(address(airdrop), tgeAmount);
        airdrop.send();
        vm.stopPrank();

        uint256 wallet2End = token.balanceOf(airdrop.wallets(1));
        uint256 wallet8End = token.balanceOf(airdrop.wallets(7));

        assertTrue(wallet2End > wallet2Start);
        assertTrue(wallet8End > wallet8Start);

        assertFalse(airdrop.canAirdrop());
        assertEq(airdrop.totalAirdroped(), totalToAirdrop);
    }
}
