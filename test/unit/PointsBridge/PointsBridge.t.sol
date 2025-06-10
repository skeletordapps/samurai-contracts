// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {console} from "forge-std/console.sol";
import {PointsBridge} from "src/PointsBridge.sol";
import {DeployPointsBridge} from "script/DeployPointsBridge.s.sol";
import {ILockS} from "src/interfaces/ILockS.sol";
import {IPoints} from "src/interfaces/IPoints.sol";
import {UD60x18, ud} from "@prb/math/src/UD60x18.sol";

contract PointsBridgeTest is Test {
    uint256 fork;
    string public RPC_URL;

    DeployPointsBridge deployer;
    PointsBridge pointsBridge;
    IPoints iPoints;
    address points;

    address owner;
    address bob;
    address mary;

    uint256 chainId = 146;

    event PointsFulfilled(uint256 indexed chainId, uint256 batchId, uint256 amount);

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployPointsBridge();

        (pointsBridge, points) = deployer.runForTests();

        iPoints = IPoints(points);

        owner = pointsBridge.owner();

        vm.startPrank(owner);
        iPoints.grantRole(IPoints.Roles.MINTER, address(pointsBridge));
        vm.stopPrank();

        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");
    }

    // CONSTRUCTOR

    function testConstructor() public view {
        assertEq(pointsBridge.owner(), owner);
        assertEq(address(pointsBridge.points()), points);
        assertEq(pointsBridge.maxRequestsPerBatch(), 2);
        assertEq(pointsBridge.currentBatchId(), 0);
        assertEq(pointsBridge.fulfillmentsCounter(), 0);
    }

    function getMockedRequests() internal pure returns (ILockS.Request[] memory) {
        ILockS.Request[] memory requests = new ILockS.Request[](2);
        requests[0] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 2.5 ether, 1, 0, false);
        requests[1] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 0.8 ether, 0, 0, false);

        return requests;
    }

    function get3Requests() internal pure returns (ILockS.Request[] memory) {
        ILockS.Request[] memory requests = new ILockS.Request[](3);
        requests[0] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 2.5 ether, 1, 0, false);
        requests[1] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 0.8 ether, 0, 0, false);
        requests[2] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 5.1 ether, 2, 0, false);

        return requests;
    }

    function testFulFillRequestsRevertInvalidChainId() public {
        vm.startPrank(owner);
        ILockS.Request[] memory requests = getMockedRequests();
        vm.expectRevert("Invalid chain ID");
        pointsBridge.fulfill(0, 0, requests);
        vm.stopPrank();
    }

    function testFulFillRequestsRevertNoRequests() public {
        vm.startPrank(owner);
        ILockS.Request[] memory requests = new ILockS.Request[](0);
        vm.expectRevert("No requests provided");
        pointsBridge.fulfill(chainId, 0, requests);
        vm.stopPrank();
    }

    function testFulFillRequestsRevertTooManyRequests() public {
        vm.startPrank(owner);
        ILockS.Request[] memory requests = get3Requests();
        vm.expectRevert("Too many requests");
        pointsBridge.fulfill(chainId, 0, requests);
        vm.stopPrank();
    }

    function testFulFillRequestsRevertRequestAlreadyFulfilled() public {
        vm.startPrank(owner);
        ILockS.Request[] memory requests = getMockedRequests();
        pointsBridge.fulfill(chainId, 0, requests);
        vm.expectRevert("Requests already fulfilled");
        pointsBridge.fulfill(chainId, 0, requests);
        vm.stopPrank();
    }

    function testFulFillRequestsRevertInvalidWallet() public {
        vm.startPrank(owner);
        ILockS.Request[] memory requests = getMockedRequests();
        requests[0].wallet = address(0);
        vm.expectRevert("Invalid wallet address");
        pointsBridge.fulfill(chainId, 0, requests);
        vm.stopPrank();
    }

    function testFulFillRequestsRevertInvalidAmount() public {
        vm.startPrank(owner);
        ILockS.Request[] memory requests = getMockedRequests();
        requests[0].amount = 0;
        vm.expectRevert("Invalid amount");
        pointsBridge.fulfill(chainId, 0, requests);
        vm.stopPrank();
    }

    function testCanFulfillRequests() public {
        ILockS.Request[] memory requests = getMockedRequests();

        uint256 expectedAmountFulfilled = 114.4 ether;

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, false);
        emit PointsFulfilled(chainId, 0, expectedAmountFulfilled);
        pointsBridge.fulfill(chainId, 0, requests);
        vm.stopPrank();

        assertEq(pointsBridge.fulfillmentsCounter(), 2);

        ILockS.Request[] memory requestsFulfilled = pointsBridge.requestsFrom(chainId, 0);

        for (uint256 i = 0; i < requestsFulfilled.length; i++) {
            assertEq(requestsFulfilled[i].isFulfilled, true);
            assert(iPoints.balanceOf(requestsFulfilled[i].wallet) >= requestsFulfilled[i].amount);
        }
    }
}
