// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {DeployNFTLock} from "../script/DeployNFTLock.s.sol";
import {IPoints} from "../src/interfaces/IPoints.sol";
import {NFTLock} from "../src/NFTLock.sol";
import {INFTLock} from "../src/interfaces/INFTLock.sol";
import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {BokkyPooBahsDateTimeLibrary} from "@BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";

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
        vm.expectRevert(abi.encodeWithSelector(INFTLock.INFTLock__Error.selector, "Not the owner"));
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
        assertEq(nftLock.locksCounter(WALLET_A), 1);
        assertEq(nftLock.getTokenId(WALLET_A, 0), 907);
    }

    function testCanLockMaxOf10Tokens() external {
        uint256[] memory tokensToLock = new uint256[](10);
        tokensToLock[0] = 907;
        tokensToLock[1] = 1075;
        tokensToLock[2] = 1076;
        tokensToLock[3] = 1077;
        tokensToLock[4] = 1074;
        tokensToLock[5] = 1078;
        tokensToLock[6] = 1079;
        tokensToLock[7] = 1080;
        tokensToLock[8] = 1081;
        tokensToLock[9] = 1082;

        for (uint256 i = 0; i < tokensToLock.length; i++) {
            if (i < 10) {
                vm.startPrank(WALLET_A);
                samNFT.approve(address(nftLock), tokensToLock[i]);
                nftLock.lockNFT(tokensToLock[i]);
                vm.stopPrank();

                assertEq(samNFT.ownerOf(tokensToLock[i]), address(nftLock));
            } else {
                vm.startPrank(WALLET_A);
                samNFT.approve(address(nftLock), tokensToLock[i]);
                vm.expectRevert(abi.encodeWithSelector(INFTLock.INFTLock__Error.selector, "Exceeds limit"));
                nftLock.lockNFT(tokensToLock[i]);
                vm.stopPrank();
            }
        }

        assertEq(nftLock.locksCounter(WALLET_A), 10);
        assertEq(nftLock.totalLocked(), 10);
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

    function testRevertUnlockWhenNotTheOwner() external locked(WALLET_A, 907) {
        uint8 index = nftLock.locksCounter(WALLET_A) - 1;
        vm.startPrank(WALLET_B);
        vm.expectRevert(abi.encodeWithSelector(INFTLock.INFTLock__Error.selector, "Not the owner"));
        nftLock.unlockNFT(index, 907);
        vm.stopPrank();
    }

    function testRevertUnlockBeforeMinPeriod() external locked(WALLET_A, 907) {
        uint8 index = nftLock.locksCounter(WALLET_A) - 1;
        vm.warp(BokkyPooBahsDateTimeLibrary.addMonths(block.timestamp, 5));
        vm.startPrank(WALLET_A);
        vm.expectRevert(
            abi.encodeWithSelector(INFTLock.INFTLock__Error.selector, "Not allowed to unlock before min period")
        );
        nftLock.unlockNFT(index, 907);
        vm.stopPrank();
    }

    function testRevertUnlockWithWrongId() external locked(WALLET_A, 907) {
        uint8 index = nftLock.locksCounter(WALLET_A) - 1;
        vm.warp(BokkyPooBahsDateTimeLibrary.addMonths(block.timestamp, nftLock.MIN_MONTHS_LOCKED()));
        vm.startPrank(WALLET_A);
        vm.expectRevert(abi.encodeWithSelector(INFTLock.INFTLock__Error.selector, "Not the owner"));
        nftLock.unlockNFT(index, 905);
        vm.stopPrank();
    }

    function testRevertUnlockWithWrongIndex() external locked(WALLET_A, 907) {
        uint8 index = 9;
        vm.warp(BokkyPooBahsDateTimeLibrary.addMonths(block.timestamp, nftLock.MIN_MONTHS_LOCKED()));
        vm.startPrank(WALLET_A);
        vm.expectRevert(abi.encodeWithSelector(INFTLock.INFTLock__Error.selector, "Wrong index"));
        nftLock.unlockNFT(index, 907);
        vm.stopPrank();
    }

    function testCanUnlock() external locked(WALLET_A, 907) {
        uint8 index = nftLock.locksCounter(WALLET_A) - 1;
        vm.warp(BokkyPooBahsDateTimeLibrary.addMonths(block.timestamp, nftLock.MIN_MONTHS_LOCKED()));
        vm.startPrank(WALLET_A);
        vm.expectEmit(true, true, true, true);
        emit INFTLock.NFTUnlocked(WALLET_A, 907);
        nftLock.unlockNFT(index, 907);
        vm.stopPrank();

        assertEq(samNFT.ownerOf(907), WALLET_A);
        assertEq(nftLock.locksCounter(WALLET_A), 0);
        assertEq(nftLock.totalWithdrawal(), 1);
        assertEq(nftLock.getTokenId(WALLET_A, 0), 0);
        assertEq(samuraiPoints.boostOf(WALLET_A), 0);
    }

    function testCanUnlockBeforePeriodWhenPeriodDisabled() external locked(WALLET_A, 907) {
        uint8 index = nftLock.locksCounter(WALLET_A) - 1;
        vm.warp(block.timestamp + 30 days); // 30 days after lock

        assertTrue(
            BokkyPooBahsDateTimeLibrary.diffMonths(nftLock.locksAt(907), block.timestamp) < nftLock.MIN_MONTHS_LOCKED()
        );

        vm.startPrank(owner);
        nftLock.toggleLockPeriod();
        vm.stopPrank();

        vm.startPrank(WALLET_A);
        vm.expectEmit(true, true, true, true);
        emit INFTLock.NFTUnlocked(WALLET_A, 907);
        nftLock.unlockNFT(index, 907);
        vm.stopPrank();

        assertEq(samNFT.ownerOf(907), WALLET_A);
        assertEq(nftLock.locksCounter(WALLET_A), 0);
        assertEq(nftLock.totalWithdrawal(), 1);
        assertEq(samuraiPoints.boostOf(WALLET_A), 0);
    }

    function testOwnerCanUnlockAnytimeForAWallet() external locked(WALLET_A, 907) {
        uint8 index = nftLock.locksCounter(WALLET_A) - 1;
        vm.warp(block.timestamp + 30 days); // 30 days after lock

        assertTrue(
            BokkyPooBahsDateTimeLibrary.diffMonths(nftLock.locksAt(907), block.timestamp) < nftLock.MIN_MONTHS_LOCKED()
        );

        vm.startPrank(owner);
        emit INFTLock.NFTUnlocked(WALLET_A, 907);
        nftLock.unlockNFTForWallet(WALLET_A, index, 907);
        vm.stopPrank();

        assertEq(samNFT.ownerOf(907), WALLET_A);
        assertEq(nftLock.locksCounter(WALLET_A), 0);
        assertEq(nftLock.totalWithdrawal(), 1);
        assertEq(samuraiPoints.boostOf(WALLET_A), 0);
    }
}
