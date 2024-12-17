// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

import {EnglishAuction} from "./EnglishAuction.sol";
import {DutchAuction} from "./DutchAuction.sol";
import {MostFairAuction} from "./MostFairAuction.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";

contract AuctionAggregator is Ownable {
    event AuctionCreated(
        string auction_type,
        address auc_address,
        address token,
        uint256 end_time,
        uint256 bid_limit,
        address nft,
        uint256 nft_token_id
    );

    address[] public auctions;

    constructor () Ownable(msg.sender) {}

    function CreateEnglishAuction(address _token, uint256 _bidding_time,
                uint256 _bid_limit, address _nft, uint256 _token_id) public returns (EnglishAuction) {
        require (ERC721(_nft).getApproved(_token_id) == address(this), "You should pass NFT approval to aggregator");
        EnglishAuction auction = new EnglishAuction(_token, _bidding_time, _bid_limit, _nft, _token_id);
        ERC721(_nft).safeTransferFrom(msg.sender, address(auction), _token_id);
        auction.transferOwnership(msg.sender);
        auctions.push(address(auction));
        emit AuctionCreated("english", address(auction), _token, auction.end_time(), auction.bid_limit(), _nft, _token_id);
        return auction;
    }

    function CreateDutchAuction(address _token, uint256 _bidding_time,
                uint256 _bid_limit, address _nft, uint256 _token_id, uint256 _price_decrease_per_second,
                uint256 _start_price) public returns (DutchAuction) {
        require (ERC721(_nft).getApproved(_token_id) == address(this), "You should pass NFT approval to aggregator");
        DutchAuction auction = new DutchAuction(_token, _bidding_time, _bid_limit, _nft, _token_id, _price_decrease_per_second, _start_price);
        ERC721(_nft).safeTransferFrom(msg.sender, address(auction), _token_id);
        auction.transferOwnership(msg.sender);
        auctions.push(address(auction));
        emit AuctionCreated("dutch", address(auction), _token, auction.end_time(), auction.bid_limit(), _nft, _token_id);
        return auction;
    }

    function CreateMostFairAuction(address _token, uint256 _bidding_time,
                uint256 _bid_limit, address _nft, uint256 _token_id) public returns (MostFairAuction) {
        require (ERC721(_nft).getApproved(_token_id) == address(this), "You should pass NFT approval to aggregator");
        MostFairAuction auction = new MostFairAuction(_token, _bidding_time, _bid_limit, _nft, _token_id);
        ERC721(_nft).safeTransferFrom(msg.sender, address(auction), _token_id);
        auction.transferOwnership(msg.sender);
        auctions.push(address(auction));
        emit AuctionCreated("most_fair", address(auction), _token, auction.end_time(), auction.bid_limit(), _nft, _token_id);
        return auction;
    }

}