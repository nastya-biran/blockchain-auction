import json
import os
from web3 import Web3

AGGREGATOR_ABI = json.load(open('../contracts/abi/AuctionAggregator.json'))
DUTCH_ABI = json.load(open('../contracts/abi/DutchAuction.json'))
ENGLISH_ABI = json.load(open('../contracts/abi/EnglishAuction.json'))
MOST_FAIR_ABI = json.load(open('../contracts/abi/MostFairAuction.json'))
ERC20_ABI = json.load(open('../contracts/abi/ERC20.json'))
ERC721_ABI = json.load(open('../contracts/abi/ERC721.json'))
OWNABLE_ABI = json.load(open('../contracts/abi/Ownable.json'))


def makeEtherscanUrl(address):
    return f"https://sepolia.etherscan.io/address/{address}"

def makeEtherscanTokenUrl(address):
    return f"https://sepolia.etherscan.io/token/{address}"

class Blockchain:
    def __init__(self):
        INFURA_URL = f'https://sepolia.infura.io/v3/{os.environ.get("INFURA_TOKEN")}'
        self.web3 = Web3(Web3.HTTPProvider(INFURA_URL))

    def get_events(self):
        aggregator = self.web3.eth.contract("0xc7Fa3CaEB7d9BAD5C95EDC238f83101D7803B4b2", abi=AGGREGATOR_ABI)

        return aggregator.events.AuctionCreated().get_logs(
            from_block=0,
            to_block='latest'
        )

    def get_erc20_name(self, address):
        token = self.web3.eth.contract(address=address, abi=ERC20_ABI)
        return token.functions.name().call()

    def get_nft_name(self, address):
        nft = self.web3.eth.contract(address=address, abi=ERC721_ABI)
        return nft.functions.name().call()

    def get_english_price(self, address):
        english = self.web3.eth.contract(address=address, abi=ENGLISH_ABI)
        return max(english.functions.best_bid().call(), english.functions.bid_limit().call())

    def get_fair_price(self, address):
        english = self.web3.eth.contract(address=address, abi=MOST_FAIR_ABI)
        return english.functions.best_bid().call()

    def get_dutch_price(self, address):
        dutch = self.web3.eth.contract(address=address, abi=DUTCH_ABI)
        return dutch.functions.getCurrentPrice().call()

    def get_price(self, event):
        type = event["args"]["auction_type"]
        if type == 0:
            return self.get_english_price(event["args"]["auc_address"])
        elif type == 1:
            return self.get_dutch_price(event["args"]["auc_address"])
        elif type == 2:
            return self.get_fair_price(event["args"]["auc_address"])

    def get_event_type(self, event):
        id = event["args"]["auction_type"]
        if id == 0:
            return "English"
        elif id == 1:
            return "Dutch  "
        elif id == 2:
            return "Fair      "

    def get_owner(self, address):
        ownable = self.web3.eth.contract(address=address, abi=OWNABLE_ABI)
        return ownable.functions.owner().call()

    def get_end_time(self, address):
        ownable = self.web3.eth.contract(address=address, abi=ENGLISH_ABI)
        return ownable.functions.end_time().call()

    def info(self, event):
        type = self.get_event_type(event)
        price = self.get_price(event)
        token = event["args"]["token"]
        token_name = self.get_erc20_name(token)
        owner = self.get_owner(event["args"]["auc_address"])
        nft_address = event["args"]["nft"]
        nft_name = self.get_nft_name(nft_address)
        end_time = self.get_end_time(event["args"]["auc_address"])

        info = {
            "type" : type,
            "price" : price,
            "token_name" : token_name,
            "token_url" : makeEtherscanTokenUrl(token),
            "nft_name" : nft_name,
            "nft_url": makeEtherscanTokenUrl(nft_address),
            "nft_id": event["args"]["nft_token_id"],
            "owner_url" : makeEtherscanUrl(owner),
            "end_time": end_time
        }
        print(info)
        return info
