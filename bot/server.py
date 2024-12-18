from fastapi import FastAPI
from fastapi.responses import FileResponse, HTMLResponse
from fastapi.staticfiles import StaticFiles
import uvicorn
import os
import base64
import json

app = FastAPI()

HTML = open("html/index.html").read()

AGGREGATOR_ABI = json.load(open('../contracts/abi/AuctionAggregator.json'))
ERC721_ABI = json.load(open('../contracts/abi/ERC721.json'))

@app.get("/create/{data}")
async def root(data):
    data = base64.b64decode(
        data.encode('utf-8')
    ).decode('utf-8')

    doc = HTML.replace("<<data>>", data) \
        .replace("<<aggregator_abi>>", json.dumps(AGGREGATOR_ABI)) \
        .replace("<<erc721_abi>>", json.dumps(ERC721_ABI))
    return HTMLResponse(doc)


def main():
    uvicorn.run(app, host="0.0.0.0", port=8080, loop="asyncio")

if __name__ == "__main__":
    main()
