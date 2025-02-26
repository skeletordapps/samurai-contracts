// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.28;

interface IGiveaways {
    struct Giveaway {
        uint256 id;
        string name;
        uint256 priceInPoints;
        uint256 tickets;
        uint256 minTickets;
        uint256 startAt;
        uint256 endAt;
        uint256 drawAt;
        address[] winners;
    }

    error IGiveaways__Error(string message);

    event Created(uint256 indexed id);
    event Participated(address indexed account, uint256 giveawayId, uint256 tickets);
    event Ended(uint256 indexed id, address[] winners);
}
