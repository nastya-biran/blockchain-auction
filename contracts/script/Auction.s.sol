// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";

import {AuctionAggregator} from "../src/AuctionAggregator.sol";


import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

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

contract AuctionScript is Script {

    function setUp() public {}

    function run() public {
        uint private_key = vm.envUint("PRIVATE_KEY");
        address me = vm.addr(private_key);
        vm.startBroadcast(private_key);

        AuctionAggregator agg = new AuctionAggregator();

        TestToken token = new TestToken(10000000, 1000);
        TestNFT nft = new TestNFT();

        uint256 token_id = nft.mint();
        nft.approve(address(agg), token_id);
        agg.CreateEnglishAuction(address(token), 10000, 0, address(nft), token_id);

        token_id = nft.mint();
        nft.approve(address(agg), token_id);
        agg.CreateDutchAuction(address(token), 10000, 100, address(nft), token_id, 1, 0);

        token_id = nft.mint();
        nft.approve(address(agg), token_id);
        agg.CreateMostFairAuction(address(token), 10000, 100, address(nft), token_id);



       vm.stopBroadcast();
    }
}
