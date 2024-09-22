// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.26;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DeployNFTLock} from "../script/DeployNFTLock.s.sol";
import {IPoints} from "../src/interfaces/IPoints.sol";
import {NFTLock} from "../src/NFTLock.sol";
import {INFTLock} from "../src/interfaces/INFTLock.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract NFTLockTest is Test {
    uint256 fork;
    string public RPC_URL;
    DeployNFTLock deployer;

    IPoints samuraiPoints;
    NFTLock nftLock;
    ERC721 samNFT;
    address _points;
    address owner;
    address bob;
    address mary;
    address WALLET_A;
    address WALLET_B;

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployNFTLock();

        (nftLock, _points) = deployer.runForTests();
        samuraiPoints = IPoints(_points);
        owner = nftLock.owner();
        samNFT = ERC721(nftLock.nftAddress());

        bob = vm.addr(1);
        mary = vm.addr(2);
        vm.label(bob, "bob");
        vm.label(mary, "mary");

        WALLET_A = vm.envAddress("WALLET_A");
        WALLET_B = vm.envAddress("WALLET_B");
    }

    function testRevertLockWhenIsNotTheOwner() external {
        vm.startPrank(owner);
        vm.expectRevert("Not the owner");
        nftLock.lockNFT(1);
        vm.stopPrank();
    }

    function testCanLockNft() external {
        uint256 tokenId = 907;

        vm.startPrank(WALLET_A);
        samNFT.approve(address(nftLock), tokenId);
        vm.expectEmit(false, false, false, false);
        emit INFTLock.NFTLocked(WALLET_A, tokenId);
        nftLock.lockNFT(tokenId);

        vm.stopPrank();

        assertEq(samuraiPoints.boostOf(WALLET_A), 0.25 ether);
        assertEq(samNFT.ownerOf(tokenId), address(nftLock));
        assertEq(nftLock.locks(WALLET_A), 1);
    }

    function testCanLockMaxOf5Tokens() external {
        uint256[] memory tokensToLock = new uint256[](6);
        tokensToLock[0] = 907;
        tokensToLock[1] = 1075;
        tokensToLock[2] = 1076;
        tokensToLock[3] = 1077;
        tokensToLock[4] = 1074;
        tokensToLock[5] = 1078;

        for (uint256 i = 0; i < tokensToLock.length; i++) {
            if (i < 5) {
                vm.startPrank(WALLET_A);
                samNFT.approve(address(nftLock), tokensToLock[i]);
                nftLock.lockNFT(tokensToLock[i]);
                vm.stopPrank();

                // (address tokenOwner,,) = nftLock.lockInfos(tokensToLock[i]);
                // assertEq(tokenOwner, WALLET_A);
                assertEq(samNFT.ownerOf(tokensToLock[i]), address(nftLock));
            } else {
                vm.startPrank(WALLET_A);
                samNFT.approve(address(nftLock), tokensToLock[i]);
                vm.expectRevert("Exceeds limit");
                nftLock.lockNFT(tokensToLock[i]);
                vm.stopPrank();
            }
        }

        assertEq(nftLock.locks(WALLET_A), 5);
        assertEq(nftLock.totalLocked(), 5);
        assertEq(nftLock.totalWithdrawal(), 0);
        assertEq(samuraiPoints.boostOf(WALLET_A), 3 ether);
        assertEq(ERC20(address(samuraiPoints)).balanceOf(WALLET_A), 0);
    }

    modifier locked(address wallet, uint256 tokenId) {
        vm.startPrank(wallet);
        samNFT.approve(address(nftLock), tokenId);
        nftLock.lockNFT(tokenId);
        vm.stopPrank();
        _;
    }

    function testRevertUnlockWithWrongId() external locked(WALLET_A, 907) {
        vm.startPrank(WALLET_A);
        vm.expectRevert("Not the owner");
        nftLock.unlockNFT(905);
        vm.stopPrank();
    }

    function testRevertUnlockWhenNotTheOwner() external locked(WALLET_A, 907) {
        vm.startPrank(WALLET_B);
        vm.expectRevert("Not the owner");
        nftLock.unlockNFT(907);
        vm.stopPrank();
    }

    function testCanUnlock() external locked(WALLET_A, 907) {
        vm.warp(block.timestamp + 30 days * 3);
        vm.startPrank(WALLET_A);
        vm.expectEmit(true, true, true, true);
        emit INFTLock.NFTUnlocked(WALLET_A, 907);
        nftLock.unlockNFT(907);
        vm.stopPrank();

        assertEq(samNFT.ownerOf(907), WALLET_A);
        assertEq(nftLock.locks(WALLET_A), 0);
        assertEq(nftLock.totalWithdrawal(), 1);
        assertEq(samuraiPoints.boostOf(WALLET_A), 0);
    }
}
