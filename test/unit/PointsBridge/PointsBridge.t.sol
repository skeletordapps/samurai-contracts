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

    event PointsFulfilled(uint256 indexed batchId, uint256 amount);

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
        assertEq(pointsBridge.MAX_REQUESTS(), 50);
        assertEq(pointsBridge.currentBatchId(), 0);
        assertEq(pointsBridge.fulfillmentsCounter(), 0);
    }

    function testFulFillRequestsRevert() public {
        vm.startPrank(owner);
        vm.expectRevert("Invalid chain ID");
        pointsBridge.fulfillRequests(0, new ILockS.Request[](0));
        vm.stopPrank();
    }

    function getMockedRequests() internal pure returns (ILockS.Request[] memory) {
        ILockS.Request[] memory requests = new ILockS.Request[](50);
        requests[0] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 2.5 ether, 1, false);
        requests[1] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 0.8 ether, 0, false);
        requests[2] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 5.1 ether, 2, false);
        requests[3] = ILockS.Request(0x2191ef87e392377EC08E7c08EB105Ef95c8BE750, 1.3 ether, 0, false);
        requests[4] = ILockS.Request(0x0dcD1bF9A1BeE7340baDf5659BA68AD3fbDE220c, 3.7 ether, 0, false);
        requests[5] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 1.9 ether, 1, false);
        requests[6] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 0.5 ether, 3, false);
        requests[7] = ILockS.Request(0x2191ef87e392377EC08E7c08EB105Ef95c8BE750, 4.2 ether, 1, false);
        requests[8] = ILockS.Request(0x0dcD1bF9A1BeE7340baDf5659BA68AD3fbDE220c, 2.1 ether, 1, false);
        requests[9] = ILockS.Request(0x5Fc8d32690cc91d4C39D9d3aBCbD1690f8776314, 1.1 ether, 0, false);
        requests[10] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 3.1 ether, 4, false);
        requests[11] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 0.9 ether, 2, false);
        requests[12] = ILockS.Request(0x2191ef87e392377EC08E7c08EB105Ef95c8BE750, 2.8 ether, 2, false);
        requests[13] = ILockS.Request(0x0dcD1bF9A1BeE7340baDf5659BA68AD3fbDE220c, 4.5 ether, 2, false);
        requests[14] = ILockS.Request(0x5Fc8d32690cc91d4C39D9d3aBCbD1690f8776314, 0.6 ether, 1, false);
        requests[15] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 1.7 ether, 5, false);
        requests[16] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 3.3 ether, 3, false);
        requests[17] = ILockS.Request(0x2191ef87e392377EC08E7c08EB105Ef95c8BE750, 0.7 ether, 3, false);
        requests[18] = ILockS.Request(0x0dcD1bF9A1BeE7340baDf5659BA68AD3fbDE220c, 1.5 ether, 3, false);
        requests[19] = ILockS.Request(0x5Fc8d32690cc91d4C39D9d3aBCbD1690f8776314, 2.9 ether, 2, false);
        requests[20] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 4.1 ether, 6, false);
        requests[21] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 2.2 ether, 4, false);
        requests[22] = ILockS.Request(0x2191ef87e392377EC08E7c08EB105Ef95c8BE750, 1.8 ether, 4, false);
        requests[23] = ILockS.Request(0x0dcD1bF9A1BeE7340baDf5659BA68AD3fbDE220c, 0.9 ether, 4, false);
        requests[24] = ILockS.Request(0x5Fc8d32690cc91d4C39D9d3aBCbD1690f8776314, 3.5 ether, 3, false);
        requests[25] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 0.7 ether, 7, false);
        requests[26] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 1.4 ether, 5, false);
        requests[27] = ILockS.Request(0x2191ef87e392377EC08E7c08EB105Ef95c8BE750, 3.9 ether, 5, false);
        requests[28] = ILockS.Request(0x0dcD1bF9A1BeE7340baDf5659BA68AD3fbDE220c, 2.7 ether, 5, false);
        requests[29] = ILockS.Request(0x5Fc8d32690cc91d4C39D9d3aBCbD1690f8776314, 1.2 ether, 4, false);
        requests[30] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 2.9 ether, 8, false);
        requests[31] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 4.3 ether, 6, false);
        requests[32] = ILockS.Request(0x2191ef87e392377EC08E7c08EB105Ef95c8BE750, 0.6 ether, 6, false);
        requests[33] = ILockS.Request(0x0dcD1bF9A1BeE7340baDf5659BA68AD3fbDE220c, 3.1 ether, 6, false);
        requests[34] = ILockS.Request(0x5Fc8d32690cc91d4C39D9d3aBCbD1690f8776314, 0.8 ether, 5, false);
        requests[35] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 1.5 ether, 9, false);
        requests[36] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 3.8 ether, 7, false);
        requests[37] = ILockS.Request(0x2191ef87e392377EC08E7c08EB105Ef95c8BE750, 2.3 ether, 7, false);
        requests[38] = ILockS.Request(0x0dcD1bF9A1BeE7340baDf5659BA68AD3fbDE220c, 1.1 ether, 7, false);
        requests[39] = ILockS.Request(0x5Fc8d32690cc91d4C39D9d3aBCbD1690f8776314, 4.7 ether, 6, false);
        requests[40] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 0.9 ether, 10, false);
        requests[41] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 2.6 ether, 8, false);
        requests[42] = ILockS.Request(0x2191ef87e392377EC08E7c08EB105Ef95c8BE750, 4.1 ether, 8, false);
        requests[43] = ILockS.Request(0x0dcD1bF9A1BeE7340baDf5659BA68AD3fbDE220c, 0.6 ether, 8, false);
        requests[44] = ILockS.Request(0x5Fc8d32690cc91d4C39D9d3aBCbD1690f8776314, 2.1 ether, 7, false);
        requests[45] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 3.5 ether, 11, false);
        requests[46] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 1.7 ether, 9, false);
        requests[47] = ILockS.Request(0x2191ef87e392377EC08E7c08EB105Ef95c8BE750, 0.5 ether, 9, false);
        requests[48] = ILockS.Request(0x0dcD1bF9A1BeE7340baDf5659BA68AD3fbDE220c, 3.9 ether, 9, false);
        requests[49] = ILockS.Request(0x5Fc8d32690cc91d4C39D9d3aBCbD1690f8776314, 1.8 ether, 8, false);

        return requests;
    }

    function get51Requests() internal pure returns (ILockS.Request[] memory) {
        ILockS.Request[] memory requests = new ILockS.Request[](51);
        requests[0] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 2.5 ether, 1, false);
        requests[1] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 0.8 ether, 0, false);
        requests[2] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 5.1 ether, 2, false);
        requests[3] = ILockS.Request(0x2191ef87e392377EC08E7c08EB105Ef95c8BE750, 1.3 ether, 0, false);
        requests[4] = ILockS.Request(0x0dcD1bF9A1BeE7340baDf5659BA68AD3fbDE220c, 3.7 ether, 0, false);
        requests[5] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 1.9 ether, 1, false);
        requests[6] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 0.5 ether, 3, false);
        requests[7] = ILockS.Request(0x2191ef87e392377EC08E7c08EB105Ef95c8BE750, 4.2 ether, 1, false);
        requests[8] = ILockS.Request(0x0dcD1bF9A1BeE7340baDf5659BA68AD3fbDE220c, 2.1 ether, 1, false);
        requests[9] = ILockS.Request(0x5Fc8d32690cc91d4C39D9d3aBCbD1690f8776314, 1.1 ether, 0, false);
        requests[10] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 3.1 ether, 4, false);
        requests[11] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 0.9 ether, 2, false);
        requests[12] = ILockS.Request(0x2191ef87e392377EC08E7c08EB105Ef95c8BE750, 2.8 ether, 2, false);
        requests[13] = ILockS.Request(0x0dcD1bF9A1BeE7340baDf5659BA68AD3fbDE220c, 4.5 ether, 2, false);
        requests[14] = ILockS.Request(0x5Fc8d32690cc91d4C39D9d3aBCbD1690f8776314, 0.6 ether, 1, false);
        requests[15] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 1.7 ether, 5, false);
        requests[16] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 3.3 ether, 3, false);
        requests[17] = ILockS.Request(0x2191ef87e392377EC08E7c08EB105Ef95c8BE750, 0.7 ether, 3, false);
        requests[18] = ILockS.Request(0x0dcD1bF9A1BeE7340baDf5659BA68AD3fbDE220c, 1.5 ether, 3, false);
        requests[19] = ILockS.Request(0x5Fc8d32690cc91d4C39D9d3aBCbD1690f8776314, 2.9 ether, 2, false);
        requests[20] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 4.1 ether, 6, false);
        requests[21] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 2.2 ether, 4, false);
        requests[22] = ILockS.Request(0x2191ef87e392377EC08E7c08EB105Ef95c8BE750, 1.8 ether, 4, false);
        requests[23] = ILockS.Request(0x0dcD1bF9A1BeE7340baDf5659BA68AD3fbDE220c, 0.9 ether, 4, false);
        requests[24] = ILockS.Request(0x5Fc8d32690cc91d4C39D9d3aBCbD1690f8776314, 3.5 ether, 3, false);
        requests[25] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 0.7 ether, 7, false);
        requests[26] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 1.4 ether, 5, false);
        requests[27] = ILockS.Request(0x2191ef87e392377EC08E7c08EB105Ef95c8BE750, 3.9 ether, 5, false);
        requests[28] = ILockS.Request(0x0dcD1bF9A1BeE7340baDf5659BA68AD3fbDE220c, 2.7 ether, 5, false);
        requests[29] = ILockS.Request(0x5Fc8d32690cc91d4C39D9d3aBCbD1690f8776314, 1.2 ether, 4, false);
        requests[30] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 2.9 ether, 8, false);
        requests[31] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 4.3 ether, 6, false);
        requests[32] = ILockS.Request(0x2191ef87e392377EC08E7c08EB105Ef95c8BE750, 0.6 ether, 6, false);
        requests[33] = ILockS.Request(0x0dcD1bF9A1BeE7340baDf5659BA68AD3fbDE220c, 3.1 ether, 6, false);
        requests[34] = ILockS.Request(0x5Fc8d32690cc91d4C39D9d3aBCbD1690f8776314, 0.8 ether, 5, false);
        requests[35] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 1.5 ether, 9, false);
        requests[36] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 3.8 ether, 7, false);
        requests[37] = ILockS.Request(0x2191ef87e392377EC08E7c08EB105Ef95c8BE750, 2.3 ether, 7, false);
        requests[38] = ILockS.Request(0x0dcD1bF9A1BeE7340baDf5659BA68AD3fbDE220c, 1.1 ether, 7, false);
        requests[39] = ILockS.Request(0x5Fc8d32690cc91d4C39D9d3aBCbD1690f8776314, 4.7 ether, 6, false);
        requests[40] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 0.9 ether, 10, false);
        requests[41] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 2.6 ether, 8, false);
        requests[42] = ILockS.Request(0x2191ef87e392377EC08E7c08EB105Ef95c8BE750, 4.1 ether, 8, false);
        requests[43] = ILockS.Request(0x0dcD1bF9A1BeE7340baDf5659BA68AD3fbDE220c, 0.6 ether, 8, false);
        requests[44] = ILockS.Request(0x5Fc8d32690cc91d4C39D9d3aBCbD1690f8776314, 2.1 ether, 7, false);
        requests[45] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 3.5 ether, 11, false);
        requests[46] = ILockS.Request(0x7A0B27dC41545564eF19744179764F7076D591F8, 1.7 ether, 9, false);
        requests[47] = ILockS.Request(0x2191ef87e392377EC08E7c08EB105Ef95c8BE750, 0.5 ether, 9, false);
        requests[48] = ILockS.Request(0x0dcD1bF9A1BeE7340baDf5659BA68AD3fbDE220c, 3.9 ether, 9, false);
        requests[49] = ILockS.Request(0x5Fc8d32690cc91d4C39D9d3aBCbD1690f8776314, 1.8 ether, 8, false);
        requests[50] = ILockS.Request(0x93984DFAeC995AD4f6b04f226E94A0b0dAA981B8, 2.5 ether, 1, false);

        return requests;
    }

    function testFulFillRequestsRevertInvalidChainId() public {
        vm.startPrank(owner);
        ILockS.Request[] memory requests = getMockedRequests();
        vm.expectRevert("Invalid chain ID");
        pointsBridge.fulfillRequests(0, requests);
        vm.stopPrank();
    }

    function testFulFillRequestsRevertNoRequests() public {
        vm.startPrank(owner);
        ILockS.Request[] memory requests = new ILockS.Request[](0);
        vm.expectRevert("No requests provided");
        pointsBridge.fulfillRequests(8453, requests);
        vm.stopPrank();
    }

    function testFulFillRequestsRevertTooManyRequests() public {
        vm.startPrank(owner);
        ILockS.Request[] memory requests = get51Requests();
        vm.expectRevert("Too many requests");
        pointsBridge.fulfillRequests(8453, requests);
        vm.stopPrank();
    }

    function testFulFillRequestsRevertRequestAlreadyFulfilled() public {
        vm.startPrank(owner);
        ILockS.Request[] memory requests = getMockedRequests();
        pointsBridge.fulfillRequests(8453, requests);
        vm.expectRevert("Requests already fulfilled");
        pointsBridge.fulfillRequests(8453, requests);
        vm.stopPrank();
    }

    function testFulFillRequestsRevertInvalidWallet() public {
        vm.startPrank(owner);
        ILockS.Request[] memory requests = getMockedRequests();
        requests[0].wallet = address(0);
        vm.expectRevert("Invalid wallet address");
        pointsBridge.fulfillRequests(8453, requests);
        vm.stopPrank();
    }

    function testFulFillRequestsRevertInvalidAmount() public {
        vm.startPrank(owner);
        ILockS.Request[] memory requests = getMockedRequests();
        requests[0].amount = 0;
        vm.expectRevert("Invalid amount");
        pointsBridge.fulfillRequests(8453, requests);
        vm.stopPrank();
    }

    function testCanFulfillRequests() public {
        ILockS.Request[] memory requests = getMockedRequests();
        uint256 chainId = 8453;
        uint256 timestamp = block.timestamp;

        uint256 expectedAmountFulfilled = 114.4 ether;

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit PointsFulfilled(0, expectedAmountFulfilled);
        pointsBridge.fulfillRequests(8453, requests);
        vm.stopPrank();

        assertEq(pointsBridge.fulfillmentsCounter(), 50);

        ILockS.Request[] memory requestsFulfilled = pointsBridge.getRequests(chainId, timestamp);

        for (uint256 i = 0; i < requestsFulfilled.length; i++) {
            assertEq(requestsFulfilled[i].isFulfilled, true);
            assert(iPoints.balanceOf(requestsFulfilled[i].wallet) >= requestsFulfilled[i].amount);
        }
    }
}
