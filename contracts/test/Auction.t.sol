// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import {EnglishAuction} from "../src/EnglishAuction.sol";
import {DutchAuction} from "../src/DutchAuction.sol";
import {MostFairAuction} from "../src/MostFairAuction.sol";
import {IAuction} from "../src/AuctionInterface.sol";

import {AuctionAggregator} from "../src/AuctionAggregator.sol";

contract TestToken is ERC20 {
    uint256 public mint_amount;
    mapping(address => uint256) public minted;

    constructor(uint256 initial_supply, uint256 _mint_amount) ERC20("TestToken", "TToken") {
        _mint(msg.sender, initial_supply);
        mint_amount = _mint_amount;
    }

    function mint() external returns (uint256) {
        if (minted[msg.sender] == 0) {
            _mint(msg.sender, mint_amount);
            minted[msg.sender] = mint_amount;
            return mint_amount;
        } else {
            return 0;
        }
    }
}

contract TestNFT is ERC721URIStorage, Ownable {
    using Strings for uint256;

    uint256 private _tokenIds;


    constructor () ERC721("TestNFT", "TNFT") Ownable(msg.sender) {
        mint();
    }

    function mint() public onlyOwner() returns (uint256) {
        _tokenIds++;
        uint256 newItemId = _tokenIds;

        _safeMint(msg.sender, newItemId);
        _setTokenURI(newItemId, Strings.toString(newItemId));
        return newItemId;
    }
}

import {Test, console} from "forge-std/Test.sol";

contract AuctionTest is Test {
    TestToken token;
    TestNFT nft;
    AuctionAggregator aggregator;
    uint private_key = vm.envUint("PRIVATE_KEY");
    address me = vm.addr(private_key);

    function setUp() public {
        vm.startBroadcast(private_key);

        token = new TestToken(1000000, 100);
        nft = new TestNFT();
        aggregator = new AuctionAggregator();
        vm.stopBroadcast();
    }

    function make_bid(IAuction auction, uint256 amount, uint client_private_key) public {
        address client = vm.addr(client_private_key);
        vm.startBroadcast(client_private_key);

        token.mint();

        token.approve(address(auction), 1000);

        auction.bid(amount);

        assertEq(token.balanceOf(client), token.mint_amount() - amount);

        vm.stopBroadcast();
    }

    function test_english() public {
        vm.startBroadcast(private_key);

        uint256 token_id = nft.mint();

        vm.expectRevert("You should pass NFT approval to aggregator");
        EnglishAuction auction = aggregator.CreateEnglishAuction(address(token), 120, 5, address(nft), token_id);

        nft.approve(address(aggregator), token_id);

        uint256 startTime = block.timestamp;

        auction = aggregator.CreateEnglishAuction(address(token), 120, 5, address(nft), token_id);
        assertEq(nft.ownerOf(token_id), address(auction));
        
        vm.stopBroadcast();
        
        uint pk_client_1 = vm.envUint("PRIVATE_KEY_ACCOUNT_2");
        uint pk_client_2 = vm.envUint("PRIVATE_KEY_ACCOUNT_3");


        vm.startBroadcast(pk_client_1);
        vm.expectRevert("Bid is less than minimal");
        auction.bid(1);
        vm.stopBroadcast();

        make_bid(auction, 10, pk_client_1);

        vm.startBroadcast(pk_client_1);
        vm.expectRevert("Current auction winner can not withdraw assets");
        auction.withdraw();
        vm.stopBroadcast();

        vm.startBroadcast(pk_client_2);
        vm.expectRevert("There is already a higher bid");
        auction.bid(5);
        vm.stopBroadcast();

        make_bid(auction, 15, pk_client_2);

        make_bid(auction, 25, pk_client_2);

        vm.startBroadcast(pk_client_1);
        auction.withdraw();
        vm.stopBroadcast();
        assertEq(token.balanceOf(vm.addr(pk_client_1)), token.mint_amount());

        make_bid(auction, 30, pk_client_1);

        vm.warp(startTime + 120 seconds);

        vm.startBroadcast(private_key);

        (bool success, uint256 received_amount) = auction.endAuction();
        assertEq(success, true);
        assertEq(received_amount, 30);
        assertEq(token.balanceOf(me), 1000030);

        assertEq(nft.ownerOf(token_id),  vm.addr(pk_client_1));
        assertEq(token.balanceOf(vm.addr(pk_client_1)), token.mint_amount() - 30);
        assertEq(token.balanceOf(vm.addr(pk_client_2)), token.mint_amount());

        assertEq(auction.ended(), true);
        vm.stopBroadcast();

        vm.startBroadcast(pk_client_2);
        vm.expectRevert("Auction already ended");
        auction.bid(30);
        vm.stopBroadcast();
    }

    function test_dutch() public {
        vm.startBroadcast(private_key);

        uint256 token_id = nft.mint();

        uint256 start_price = 50;
        uint256 price_descrease_per_second = 5;

        vm.expectRevert("You should pass NFT approval to aggregator");
        DutchAuction auction = aggregator.CreateDutchAuction(address(token), 120, 5, address(nft), token_id, price_descrease_per_second, start_price);

        nft.approve(address(aggregator), token_id);

        uint256 startTime = block.timestamp;

        auction = aggregator.CreateDutchAuction(address(token), 120, 5, address(nft), token_id, price_descrease_per_second, start_price);
        assertEq(nft.ownerOf(token_id), address(auction));
        
        vm.stopBroadcast();
        
        uint pk_client_1 = vm.envUint("PRIVATE_KEY_ACCOUNT_2");
        uint pk_client_2 = vm.envUint("PRIVATE_KEY_ACCOUNT_3");


        vm.startBroadcast(pk_client_1);
        vm.expectRevert("Wrong bid amount");
        auction.bid(1);
        vm.stopBroadcast();

        uint256 cur_price = auction.getCurrentPrice();
        assertEq(cur_price, 50);

        vm.warp(startTime + 5 seconds);

        cur_price = auction.getCurrentPrice();
        assertEq(cur_price, 25);
        make_bid(auction, cur_price, pk_client_1);

        vm.warp(startTime + 100 seconds);

        cur_price = auction.getCurrentPrice();
        assertEq(cur_price, 5);

        vm.startBroadcast(pk_client_2);
        token.mint();
        token.approve(address(auction), 1000);
        vm.expectRevert("The bid was set already");
        auction.bid(cur_price);
        vm.stopBroadcast();

        vm.warp(startTime + 1000 seconds);
        vm.startBroadcast(private_key);

        (bool success, uint256 received_amount) = auction.endAuction();
        assertEq(success, true);
        assertEq(received_amount, 25);
        assertEq(token.balanceOf(me), 1000025);

        assertEq(nft.ownerOf(token_id),  vm.addr(pk_client_1));
        assertEq(token.balanceOf(vm.addr(pk_client_1)), token.mint_amount() - 25);
        assertEq(token.balanceOf(vm.addr(pk_client_2)), token.mint_amount());

        assertEq(auction.ended(), true);
        vm.stopBroadcast();

        vm.startBroadcast(pk_client_2);
        vm.expectRevert("Auction already ended");
        auction.bid(30);
        vm.stopBroadcast();
    }

    function test_most_fair() public {
        vm.startBroadcast(private_key);

        uint256 token_id = nft.mint();

        vm.expectRevert("You should pass NFT approval to aggregator");
        MostFairAuction auction = aggregator.CreateMostFairAuction(address(token), 120, 5, address(nft), token_id);

        nft.approve(address(aggregator), token_id);

        uint256 startTime = block.timestamp;

        auction = aggregator.CreateMostFairAuction(address(token), 120, 5, address(nft), token_id);
        assertEq(nft.ownerOf(token_id), address(auction));
        
        vm.stopBroadcast();
        
        uint pk_client_1 = vm.envUint("PRIVATE_KEY_ACCOUNT_2");
        uint pk_client_2 = vm.envUint("PRIVATE_KEY_ACCOUNT_3");


        vm.startBroadcast(pk_client_1);
        vm.expectRevert("Bid is less than minimal");
        auction.bid(1);
        vm.stopBroadcast();

        make_bid(auction, 10, pk_client_1);

        vm.startBroadcast(pk_client_2);
        vm.expectRevert("There is already a higher bid");
        auction.bid(5);
        vm.stopBroadcast();

        make_bid(auction, 15, pk_client_2);

        make_bid(auction, 25, pk_client_2);

        vm.warp(startTime + 120 seconds);

        vm.startBroadcast(private_key);

        (bool success, uint256 received_amount) = auction.endAuction();
        assertEq(success, true);
        assertEq(received_amount, 10);
        assertEq(token.balanceOf(me), 1000010);

        assertEq(nft.ownerOf(token_id),  vm.addr(pk_client_2));
        assertEq(token.balanceOf(vm.addr(pk_client_1)), token.mint_amount() - 10);
        assertEq(token.balanceOf(vm.addr(pk_client_2)), token.mint_amount() - 25);

        assertEq(auction.ended(), true);
        vm.stopBroadcast();

        vm.startBroadcast(pk_client_2);
        vm.expectRevert("Auction already ended");
        auction.bid(30);
        vm.stopBroadcast();
    }
}
