// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IPoints} from "./interfaces/IPoints.sol";
import {IGiveaways} from "./interfaces/IGiveaways.sol";

contract Giveaways is Ownable, Pausable, ReentrancyGuard {
    IPoints public immutable points;
    uint256[] public ids;

    mapping(uint256 id => IGiveaways.Giveaway) public giveaways;
    mapping(uint256 giveawayId => mapping(address account => uint256 tickets)) public participations;
    mapping(uint256 giveawayId => address[] participants) public participants;

    constructor(address _points) Ownable(msg.sender) {
        require(_points != address(0), IGiveaways.IGiveaways__Error("Points address cannot be zero"));
        points = IPoints(_points);
    }

    modifier isValid(IGiveaways.Giveaway memory giveaway) {
        require(giveaway.id == 0, IGiveaways.IGiveaways__Error("Id must be zero"));
        require(bytes(giveaway.name).length > 0, IGiveaways.IGiveaways__Error("Name cannot be empty"));
        require(giveaway.priceInPoints > 0, IGiveaways.IGiveaways__Error("PriceInPoints must be greater than zero"));
        require(giveaway.minTickets > 0, IGiveaways.IGiveaways__Error("Min tickets must be greater than zero"));
        require(giveaway.startAt > 0, IGiveaways.IGiveaways__Error("Start at must be greater than zero"));
        require(giveaway.endAt > 0, IGiveaways.IGiveaways__Error("End at must be greater than zero"));
        require(giveaway.drawAt > 0, IGiveaways.IGiveaways__Error("Draw at must be greater than zero"));
        require(giveaway.endAt > giveaway.startAt, IGiveaways.IGiveaways__Error("EndAt must be greater than StartAt"));
        require(giveaway.drawAt > giveaway.endAt, IGiveaways.IGiveaways__Error("DrawAt must be greater than EndAt"));
        require(giveaway.winners.length == 0, IGiveaways.IGiveaways__Error("Winners must be empty"));
        _;
    }

    modifier canParticipate(uint256 giveawayId, uint256 tickets) {
        require(giveawayId < ids.length, IGiveaways.IGiveaways__Error("Giveaway does not exist"));
        IGiveaways.Giveaway memory giveaway = giveaways[giveawayId];

        require(block.timestamp >= giveaway.startAt, IGiveaways.IGiveaways__Error("Giveaway has not started yet"));
        require(block.timestamp <= giveaway.endAt, IGiveaways.IGiveaways__Error("Giveaway has ended"));
        require(tickets >= giveaway.minTickets, IGiveaways.IGiveaways__Error("Tickets is less than min tickets"));

        uint256 pointsToBurn = tickets * giveaway.priceInPoints;

        require(
            IPoints(points).balanceOf(msg.sender) >= pointsToBurn, IGiveaways.IGiveaways__Error("Insufficient points")
        );
        _;
    }

    function participate(uint256 giveawayId, uint256 tickets)
        external
        whenNotPaused
        nonReentrant
        canParticipate(giveawayId, tickets)
    {
        IGiveaways.Giveaway storage giveaway = giveaways[giveawayId];

        if (participations[giveawayId][msg.sender] == 0) {
            participants[giveawayId].push(msg.sender);
        }

        participations[giveawayId][msg.sender] += tickets;
        giveaway.tickets += tickets;
        emit IGiveaways.Participated(msg.sender, giveawayId, tickets);

        uint256 pointsToBurn = tickets * giveaway.priceInPoints;

        points.burn(msg.sender, pointsToBurn);
    }

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

    function create(IGiveaways.Giveaway memory giveaway) external onlyOwner isValid(giveaway) {
        uint256 id = ids.length;

        giveaway.id = id;
        giveaways[id] = giveaway;
        ids.push(id);
        emit IGiveaways.Created(id);
    }

    function setWinner(uint256 giveawayId, address[] memory winners) external onlyOwner {
        require(giveawayId < ids.length, IGiveaways.IGiveaways__Error("Giveaway does not exist"));
        require(block.timestamp >= giveaways[giveawayId].drawAt, IGiveaways.IGiveaways__Error("DrawAt has not passed"));
        require(giveaways[giveawayId].winners.length == 0, IGiveaways.IGiveaways__Error("Winners already set"));
        require(participants[giveawayId].length > 0, IGiveaways.IGiveaways__Error("No participants"));

        IGiveaways.Giveaway storage giveaway = giveaways[giveawayId];

        for (uint256 i = 0; i < winners.length; i++) {
            giveaway.winners.push(winners[i]);
        }

        emit IGiveaways.Ended(giveawayId, winners);
    }

    function getIDs() external view returns (uint256[] memory) {
        return ids;
    }

    function participantsOf(uint256 giveawayId) public view returns (address[] memory) {
        return participants[giveawayId];
    }

    function winnersOf(uint256 giveawayId) public view returns (address[] memory) {
        return giveaways[giveawayId].winners;
    }
}
