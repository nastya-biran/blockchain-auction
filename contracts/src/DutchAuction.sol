// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IAuction} from "./AuctionInterface.sol";



contract DutchAuction is IAuction {
    uint256 price_decrease_per_second = 0;
    uint256 start_price;
    uint256 start_time;
    event BidSet(address bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);

    constructor(address _token, uint256 _biddingTime, uint256 _bid_limit,
                address _nft, uint256 _token_id, uint256 _price_decrease_per_second,
                uint256 _start_price)
                IAuction(_token, _biddingTime, _bid_limit, _nft, _token_id) {
        price_decrease_per_second = _price_decrease_per_second;
        start_price = _start_price;
        start_time = block.timestamp;
    }

    function bid(uint256 amount) public override {
        require(block.timestamp < end_time, "Auction already ended");
        require(best_bidder == address(0), "The bid was set already");
        require(amount == getCurrentPrice(), "Wrong bid amount");

        require(
            ERC20(auction_token).transferFrom(msg.sender, address(this), amount),
            "Transfer failed"
        );

        best_bidder = msg.sender;
        best_bid = amount;
        emit BidSet(msg.sender, amount);
    }

    function getCurrentPrice() view public returns (uint256) {
        uint256 price_decrease = (block.timestamp - start_time) * price_decrease_per_second;
        if (start_price >= price_decrease + bid_limit) {
            return start_price - price_decrease;
        }
        return bid_limit;
    }

    function withdraw() public override {}

    function endAuction() public override returns (bool, uint256) {
        require(block.timestamp >= end_time, "Auction not yet ended");
        require(!ended, "Auction has already been ended");

        ended = true;
        emit AuctionEnded(best_bidder, best_bid);

        if (best_bidder != address(0)) {
            uint256 amount =  best_bid;

            ERC721(nft).safeTransferFrom(address(this), best_bidder, token_id);

            ERC20(auction_token).transfer(owner(), best_bid);

            return (true, amount);
        }
        return (false, 0);
    }
}
