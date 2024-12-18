from aiogram import Bot, Dispatcher, executor, types
from aiogram.contrib.middlewares.logging import LoggingMiddleware
from aiogram.dispatcher import FSMContext
from aiogram.contrib.fsm_storage.memory import MemoryStorage
from aiogram.dispatcher.filters.state import State, StatesGroup
from aiogram.types import ReplyKeyboardMarkup, ReplyKeyboardRemove, InlineKeyboardMarkup, InlineKeyboardButton
from aiogram.utils.callback_data import CallbackData
import json
import base64
from datetime import datetime
import os

from w3 import Blockchain

API_TOKEN = os.environ.get('TG_TOKEN')

bot = Bot(token=API_TOKEN)
storage = MemoryStorage()
dp = Dispatcher(bot, storage=storage)
dp.middleware.setup(LoggingMiddleware())

blockchain = Blockchain()

class EnglishForm(StatesGroup):
    nft_address = State()
    token_id = State()
    erc20_address = State()
    min_price = State()
    duration = State()

class DutchForm(StatesGroup):
    nft_address = State()
    token_id = State()
    erc20_address = State()
    start_price = State()
    decay_rate = State()

# Главная клавиатура
main_keyboard = ReplyKeyboardMarkup(resize_keyboard=True)
main_buttons = ["Список аукционов", "Создать аукцион"]
main_keyboard.add(*main_buttons)

# Клавиатура для выбора типа аукциона
auction_keyboard = ReplyKeyboardMarkup(resize_keyboard=True)
auction_buttons = ["Английский", "Голландский", "Честный"]
auction_keyboard.add(*auction_buttons)

def expand(s, len):
    return s + (" " * len)

def make_row(info):
    type = info["type"]
    price = info["price"]
    token = f"[{info['token_name']}]({info['token_url']})"
    owner = f"[link]({info['owner_url']})"
    nft = f"[{info['nft_name']}:{info['nft_id']}]({info['nft_url']})"
    end_time = datetime.fromtimestamp(info["end_time"]).strftime('%Y-%m-%d %H:%M:%S')

    return f"NFT: {nft} Type: {type} Token: {token} Price: {price} Owner: {owner} End time: {end_time}"


def collectAucs():
    aucs = []
    for event in blockchain.get_events():
        info = blockchain.info(event)
        aucs.append(make_row(info))
    return "\n".join(aucs)

@dp.message_handler(commands=['start'])
async def send_welcome(message: types.Message):
    await message.reply("Выберите действие:", reply_markup=main_keyboard)

@dp.message_handler(lambda message: message.text in main_buttons)
async def handle_buttons(message: types.Message):
    if message.text == "Список аукционов":
        await message.reply(collectAucs(), parse_mode=types.ParseMode.MARKDOWN)
    elif message.text == "Создать аукцион":
        await message.reply("Выберите тип аукциона:", reply_markup=auction_keyboard)

@dp.message_handler(lambda message: message.text == "Английский")
async def auction_details_prompt_english(message: types.Message):
    await EnglishForm.nft_address.set()
    await message.reply("Напишите адрес вашего NFT токена:", reply_markup=ReplyKeyboardRemove())

@dp.message_handler(state=EnglishForm.nft_address)
async def process_nft_address(message: types.Message, state: FSMContext):
    await state.update_data(nft_address=message.text)
    await EnglishForm.next()
    await message.reply("Напишите token_id вашего NFT токена:")

@dp.message_handler(state=EnglishForm.token_id)
async def process_nft_address(message: types.Message, state: FSMContext):
    await state.update_data(token_id=message.text)
    await EnglishForm.next()
    await message.reply("Напишите адрес ERC20 токена, в котором будет производиться оплата:")

@dp.message_handler(state=EnglishForm.erc20_address)
async def process_erc20_address(message: types.Message, state: FSMContext):
    await state.update_data(erc20_address=message.text)
    await EnglishForm.next()
    await message.reply("Напишите минимальную стоимость:")

@dp.message_handler(state=EnglishForm.min_price)
async def process_min_price(message: types.Message, state: FSMContext):
    await state.update_data(min_price=message.text)
    await EnglishForm.next()
    await message.reply("Напишите время, после которого аукцион считается завершенным:")

@dp.message_handler(state=EnglishForm.duration)
async def process_duration(message: types.Message, state: FSMContext):
    await state.update_data(duration=message.text)

    user_data = await state.get_data()

    data = {
        "token" : user_data['erc20_address'],
        "bidding_time" : int(user_data['duration']),
        "bid_limit" : int(user_data['min_price']),
        "nft" : user_data['nft_address'],
        "token_id" : int(user_data['token_id'])
    }

    encoded = base64.b64encode(
        json.dumps(data).encode('utf-8')
    ).decode('utf-8')

    response = (
        f"Английский Аукцион создан с параметрами:\n"
        f"NFT адрес: {user_data['nft_address']}\n"
        f"ERC20 адрес: {user_data['erc20_address']}\n"
        f"Минимальная стоимость: {user_data['min_price']}\n"
        f"Время завершения: {user_data['duration']}\n"
        f"token_id: {user_data['token_id']}\n"
        f"Ссылка: http://158.160.98.188:8080/create/{encoded}"
    )

    await message.reply(response, reply_markup=main_keyboard)
    await state.finish()

@dp.message_handler(lambda message: message.text == "Голландский")
async def auction_details_prompt_dutch(message: types.Message):
    await DutchForm.nft_address.set()
    await message.reply("Напишите адрес вашего NFT токена:", reply_markup=ReplyKeyboardRemove())

@dp.message_handler(state=DutchForm.nft_address)
async def process_nft_address_dutch(message: types.Message, state: FSMContext):
    await state.update_data(nft_address=message.text)
    await DutchForm.next()
    await message.reply("Напишите token_id вашего NFT токена:")

@dp.message_handler(state=DutchForm.token_id)
async def process_nft_address(message: types.Message, state: FSMContext):
    await state.update_data(token_id=message.text)
    await DutchForm.next()
    await message.reply("Напишите адрес ERC20 токена, в котором будет производиться оплата:")

@dp.message_handler(state=DutchForm.erc20_address)
async def process_erc20_address_dutch(message: types.Message, state: FSMContext):
    await state.update_data(erc20_address=message.text)
    await DutchForm.next()
    await message.reply("Напишите начальную стоимость:")

@dp.message_handler(state=DutchForm.start_price)
async def process_start_price_dutch(message: types.Message, state: FSMContext):
    await state.update_data(start_price=message.text)
    await DutchForm.next()
    await message.reply("Напишите скорость убывания стоимости (токен в секунду):")

@dp.message_handler(state=DutchForm.decay_rate)
async def process_decay_rate_dutch(message: types.Message, state: FSMContext):
    await state.update_data(decay_rate=message.text)
    user_data = await state.get_data()
    response = (
        f"Голландский аукцион создан с параметрами:\n"
        f"NFT адрес: {user_data['nft_address']}\n"
        f"ERC20 адрес: {user_data['erc20_address']}\n"
        f"Начальная стоимость: {user_data['start_price']}\n"
        f"Скорость убывания стоимости: {user_data['decay_rate']} токен/сек"
    )
    await message.reply(response, reply_markup=main_keyboard)
    await state.finish()

if __name__ == '__main__':
    executor.start_polling(dp, skip_updates=True)
