// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import {IAuction} from "./AuctionInterface.sol";

import {console} from "forge-std/Script.sol";



contract EnglishAuction is IAuction {
    event HighestBidIncreased(address bidder, uint256 amount);
    event AuctionEnded(address winner, uint256 amount);

    constructor(address _token, uint256 _biddingTime,
                uint256 _bid_limit, address _nft, uint256 _token_id)
                IAuction(_token, _biddingTime, _bid_limit, _nft, _token_id) {}

    function bid(uint256 amount) public override {
        require(block.timestamp < end_time, "Auction already ended");
        require (amount >= bid_limit, "Bid is less than minimal");
        require(amount > best_bid, "There is already a higher bid");

        uint256 cur_bid = pending_returns[msg.sender];
        if (msg.sender == best_bidder) {
            cur_bid = best_bid;
        }

        require(
            ERC20(auction_token).transferFrom(msg.sender, address(this), amount - cur_bid),
            "Transfer failed"
        );

        if (best_bidder != address(0) && best_bidder != msg.sender) {
            pending_returns[best_bidder] = best_bid;
            pending_addresses.push(best_bidder);
        }

        best_bidder = msg.sender;
        best_bid = amount;
        emit HighestBidIncreased(msg.sender, amount);
    }

    function withdraw() public override {
        require(msg.sender != best_bidder, "Current auction winner can not withdraw assets");
        _returnAssets(msg.sender);
    }

    function endAuction() public override returns (bool, uint256) {
        require(block.timestamp >= end_time, "Auction not yet ended");
        require(!ended, "Auction has already been ended");

        ended = true;
        emit AuctionEnded(best_bidder, best_bid);

        for (uint i = 0; i < pending_addresses.length; i++) {
            _returnAssets(pending_addresses[i]);
        }

        if (best_bidder != address(0)) {
            uint256 amount =  best_bid;

            ERC721(nft).safeTransferFrom(address(this), best_bidder, token_id);

            ERC20(auction_token).transfer(owner(), best_bid);

            return (true, amount);
        }
        return (false, 0);
    }
}
