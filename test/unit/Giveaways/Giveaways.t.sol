// SPDX-License-Identifier: UNLINCENSED
pragma solidity 0.8.28;

import {Test} from "forge-std/Test.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Giveaways} from "../../../src/Giveaways.sol";
import {IGiveaways} from "../../../src/interfaces/IGiveaways.sol";
import {IPoints} from "../../../src/interfaces/IPoints.sol";
import {DeployGiveaways} from "../../../script/DeployGiveaways.s.sol";
import {UD60x18, ud, convert} from "@prb/math/src/UD60x18.sol";
import {BokkyPooBahsDateTimeLibrary} from "@BokkyPooBahsDateTimeLibrary/contracts/BokkyPooBahsDateTimeLibrary.sol";

contract GiveawaysTest is Test {
    uint256 fork;
    string public RPC_URL;

    DeployGiveaways deployer;
    Giveaways _contract;
    address _points;

    address owner;
    address bob;
    address mary;
    address paul;

    IPoints points;

    function setUp() public virtual {
        RPC_URL = vm.envString("BASE_RPC_URL");
        fork = vm.createFork(RPC_URL);
        vm.selectFork(fork);

        deployer = new DeployGiveaways();
        (_contract, _points) = deployer.run();
        owner = _contract.owner();

        bob = vm.addr(1);
        vm.label(bob, "bob");

        mary = vm.addr(2);
        vm.label(mary, "mary");

        paul = vm.addr(3);
        vm.label(paul, "paul");

        points = IPoints(_points);

        vm.startPrank(owner);
        points.grantRole(IPoints.Roles.BURNER, address(_contract));
        vm.stopPrank();
    }

    function testConstructor() public view {
        assertEq(address(_contract.points()), address(0xDf0fDc572849f01CdaB35b80cA41Ce67051C8Dfe));
        assertEq(_contract.paused(), false);
        assertEq(_contract.getIDs().length, 0);
    }

    function testRevertGiveawayCreationWithInvalidArguments() external {
        IGiveaways.Giveaway memory giveaway = IGiveaways.Giveaway({
            id: 1,
            name: "",
            priceInPoints: 0,
            tickets: 0,
            minTickets: 0,
            startAt: 0,
            endAt: 0,
            drawAt: 0,
            winners: new address[](1)
        });

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IGiveaways.IGiveaways__Error.selector, "Id must be zero"));
        _contract.create(giveaway);

        giveaway.id = 0;
        vm.expectRevert(abi.encodeWithSelector(IGiveaways.IGiveaways__Error.selector, "Name cannot be empty"));
        _contract.create(giveaway);

        giveaway.name = "Giveaway";
        vm.expectRevert(
            abi.encodeWithSelector(IGiveaways.IGiveaways__Error.selector, "PriceInPoints must be greater than zero")
        );
        _contract.create(giveaway);

        giveaway.priceInPoints = 100 ether;
        vm.expectRevert(
            abi.encodeWithSelector(IGiveaways.IGiveaways__Error.selector, "Min tickets must be greater than zero")
        );
        _contract.create(giveaway);

        giveaway.minTickets = 10;
        vm.expectRevert(
            abi.encodeWithSelector(IGiveaways.IGiveaways__Error.selector, "Start at must be greater than zero")
        );
        _contract.create(giveaway);

        giveaway.startAt = block.timestamp + 1 days;
        vm.expectRevert(
            abi.encodeWithSelector(IGiveaways.IGiveaways__Error.selector, "End at must be greater than zero")
        );
        _contract.create(giveaway);

        giveaway.endAt = giveaway.startAt;
        vm.expectRevert(
            abi.encodeWithSelector(IGiveaways.IGiveaways__Error.selector, "Draw at must be greater than zero")
        );
        _contract.create(giveaway);

        giveaway.drawAt = giveaway.endAt;
        vm.expectRevert(
            abi.encodeWithSelector(IGiveaways.IGiveaways__Error.selector, "EndAt must be greater than StartAt")
        );
        _contract.create(giveaway);

        giveaway.endAt = block.timestamp + 2 days;
        vm.expectRevert(
            abi.encodeWithSelector(IGiveaways.IGiveaways__Error.selector, "DrawAt must be greater than EndAt")
        );
        _contract.create(giveaway);

        giveaway.drawAt = block.timestamp + 3 days;
        vm.expectRevert(abi.encodeWithSelector(IGiveaways.IGiveaways__Error.selector, "Winners must be empty"));
        _contract.create(giveaway);
        vm.stopPrank();
    }

    function testCancreate() external {
        IGiveaways.Giveaway memory giveaway = IGiveaways.Giveaway({
            id: 0,
            name: "Giveaway 1",
            priceInPoints: 20_000 ether,
            tickets: 0,
            minTickets: 10,
            startAt: block.timestamp + 1 days,
            endAt: block.timestamp + 2 days,
            drawAt: block.timestamp + 3 days,
            winners: new address[](0)
        });

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IGiveaways.Created(0);
        _contract.create(giveaway);
        vm.stopPrank();

        assertEq(_contract.getIDs().length, 1);

        (
            uint256 id,
            string memory name,
            uint256 priceInPoints,
            uint256 tickets,
            uint256 minTickets,
            uint256 startAt,
            uint256 endAt,
            uint256 drawAt
        ) = _contract.giveaways(0);

        assertEq(id, 0);
        assertEq(name, "Giveaway 1");
        assertEq(priceInPoints, 20_000 ether);
        assertEq(tickets, 0);
        assertEq(minTickets, 10);
        assertEq(startAt, block.timestamp + 1 days);
        assertEq(endAt, block.timestamp + 2 days);
        assertEq(drawAt, block.timestamp + 3 days);

        address[] memory winners = _contract.winnersOf(0);
        assertEq(winners.length, 0);
    }

    modifier created() {
        IGiveaways.Giveaway memory giveaway = IGiveaways.Giveaway({
            id: 0,
            name: "Giveaway 1",
            priceInPoints: 20_000 ether,
            tickets: 0,
            minTickets: 10,
            startAt: block.timestamp + 1 days,
            endAt: block.timestamp + 2 days,
            drawAt: block.timestamp + 3 days,
            winners: new address[](0)
        });

        vm.startPrank(owner);
        _contract.create(giveaway);
        vm.stopPrank();
        _;
    }

    function testRevertPartipations() external created {
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(IGiveaways.IGiveaways__Error.selector, "Giveaway does not exist"));
        _contract.participate(10, 0);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(IGiveaways.IGiveaways__Error.selector, "Giveaway has not started yet"));
        _contract.participate(0, 0);
        vm.stopPrank();

        (,,,,, uint256 startAt, uint256 endAt,) = _contract.giveaways(0);

        vm.warp(endAt + 1 days);
        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(IGiveaways.IGiveaways__Error.selector, "Giveaway has ended"));
        _contract.participate(0, 10);
        vm.stopPrank();

        vm.warp(startAt);
        vm.startPrank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(IGiveaways.IGiveaways__Error.selector, "Tickets is less than min tickets")
        );
        _contract.participate(0, 5);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert(abi.encodeWithSelector(IGiveaways.IGiveaways__Error.selector, "Insufficient points"));
        _contract.participate(0, 10);
        vm.stopPrank();
    }

    function testCanParticipate() external created {
        (,, uint256 priceInPoints, uint256 tickets, uint256 minTickets, uint256 startAt,,) = _contract.giveaways(0);
        assertEq(tickets, 0);

        deal(address(points), bob, minTickets * priceInPoints);
        assertEq(points.balanceOf(bob), minTickets * priceInPoints);

        vm.warp(startAt);

        vm.startPrank(bob);
        vm.expectEmit(true, true, true, true);
        emit IGiveaways.Participated(bob, 0, 10);
        _contract.participate(0, 10);
        vm.stopPrank();

        (,,, tickets,, startAt,,) = _contract.giveaways(0);

        assertEq(_contract.participations(0, bob), 10);
        assertEq(tickets, 10);

        address[] memory participants = _contract.participantsOf(0);
        assertEq(_contract.participantsOf(0).length, 1);
        assertEq(participants[0], bob);
    }

    modifier inPeriod() {
        (,,,,, uint256 startAt,,) = _contract.giveaways(0);
        vm.warp(startAt);
        _;
    }

    modifier participated(address account, uint256 giveawayId, uint256 numOfTickets, uint256 price) {
        deal(address(points), account, numOfTickets * price);

        vm.startPrank(account);
        _contract.participate(giveawayId, numOfTickets);
        vm.stopPrank();
        _;
    }

    function testRevertSetWinnerInBadConditions() external created {
        (,,,,,,, uint256 drawAt) = _contract.giveaways(0);

        vm.startPrank(owner);
        vm.expectRevert(abi.encodeWithSelector(IGiveaways.IGiveaways__Error.selector, "Giveaway does not exist"));
        _contract.setWinner(1, new address[](0));

        vm.expectRevert(abi.encodeWithSelector(IGiveaways.IGiveaways__Error.selector, "DrawAt has not passed"));
        _contract.setWinner(0, new address[](0));

        vm.warp(drawAt);
        vm.expectRevert(abi.encodeWithSelector(IGiveaways.IGiveaways__Error.selector, "No participants"));
        _contract.setWinner(0, new address[](1));
        vm.stopPrank();
    }

    function testCanSetWinners()
        external
        created
        inPeriod
        participated(bob, 0, 10, 20_000 ether)
        participated(mary, 0, 15, 20_000 ether)
        participated(paul, 0, 20, 20_000 ether)
    {
        address[] memory winners = new address[](2);
        winners[0] = mary;
        winners[1] = paul;

        (,,,,,,, uint256 drawAt) = _contract.giveaways(0);

        vm.warp(drawAt);

        vm.startPrank(owner);
        vm.expectEmit(true, true, true, true);
        emit IGiveaways.Ended(0, winners);
        _contract.setWinner(0, winners);
        vm.stopPrank();

        address[] memory actualWinners = _contract.winnersOf(0);
        assertEq(actualWinners.length, 2);
        assertEq(actualWinners[0], mary);
        assertEq(actualWinners[1], paul);
    }
}
