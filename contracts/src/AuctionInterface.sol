// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";


abstract contract IAuction is Ownable, IERC721Receiver {
    address public auction_token;
    address public nft;
    uint256 token_id;

    address public best_bidder = address(0);
    uint256 public best_bid;
    uint256 public bid_limit;

    uint256 public end_time;

    mapping(address => uint256) public pending_returns;
    address[] public pending_addresses;

    bool public ended = false;

    constructor(address _token, uint256 _bidding_time,
                uint256 _bid_limit, address _nft,
                uint256 _token_id) Ownable(msg.sender) {
        auction_token = _token;
        end_time = block.timestamp + _bidding_time;
        bid_limit = _bid_limit;
        nft = _nft;
        token_id = _token_id;
    }

    function bid(uint256 amount) public virtual;

    function withdraw() public virtual;

    function endAuction() public virtual returns (bool, uint256);

    function _returnAssets(address recepient) internal {
        uint256 amount = pending_returns[recepient];
        if (amount > 0) {
            pending_returns[recepient] = 0;
            IERC20(auction_token).transfer(recepient, amount);
        }
    }

    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }

}
