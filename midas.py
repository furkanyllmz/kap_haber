import asyncio
import requests
import json
import logging
from datetime import datetime
from pymongo import MongoClient
import os

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("midas")

# MongoDB Configuration
MONGO_URI = os.environ.get("MONGO_URI", "mongodb://localhost:27017")
MONGO_DB = "kap_news"
MONGO_COLLECTION = "prices"
MONGO_INDICES_COLLECTION = "indices"

# Global storage for Midas data
# Key: Stock Code (Hisse Adı), Value: Data Dict
DATA = {}
INDEX_DATA = {}

# Important indices to track
TRACKED_INDICES = [
    "XU100",      # BIST 100
    "XAUTRY",     # Altın TL
    "XAGTRY",     # Gümüş TL
    "USDTRY",     # Dolar
    "EURTRY",     # Euro
    "GBPTRY",     # Sterlin
    "GAUTRY",     # Gram Altın
    "BRENT:CFD",  # Brent Petrol
    "CRUDEOIL:CFD",  # WTI Petrol
    "BTCUSD",     # Bitcoin
    "NATURALGAS:CFD",  # Doğalgaz
]

def get_mongo_collection():
    try:
        client = MongoClient(MONGO_URI)
        db = client[MONGO_DB]
        return db[MONGO_COLLECTION]
    except Exception as e:
        logger.error(f"Failed to connect to MongoDB: {e}")
        return None

def get_indices_collection():
    try:
        client = MongoClient(MONGO_URI)
        db = client[MONGO_DB]
        return db[MONGO_INDICES_COLLECTION]
    except Exception as e:
        logger.error(f"Failed to connect to MongoDB indices: {e}")
        return None

def get_stored_data():
    """Returns the current stored data."""
    return DATA

def get_stored_indices():
    """Returns the current stored index data."""
    return INDEX_DATA

async def fetch_loop():
    """Background task to fetch Midas data every 60 seconds."""
    url = "https://www.getmidas.com/wp-json/midas-api/v1/midas_table_data?return=all"
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36",
        "Accept": "application/json"
    }

    collection = get_mongo_collection()

    while True:
        try:
            # Run blocking request in a separate thread to avoid blocking asyncio loop
            response = await asyncio.to_thread(requests.get, url, headers=headers, timeout=30)
            
            if response.status_code == 200:
                raw_data = response.json()
                
                # Fix for "str object has no attribute get"
                if isinstance(raw_data, str):
                    try:
                        raw_data = json.loads(raw_data)
                    except json.JSONDecodeError:
                        logger.error("Failed to parse string response as JSON")
                        continue

                if isinstance(raw_data, list):
                    parsed_data = {}
                    mongo_ops = [] # If using bulk write, but for simplicity loop first
                    
                    for item in raw_data:
                        # Ensure item is a dict
                        if isinstance(item, str):
                             try:
                                item = json.loads(item)
                             except:
                                 continue
                        
                        if isinstance(item, dict):
                            code = item.get("Code")
                            if code:
                                parsed_data[code] = item
                                
                                # Prepare for Mongo
                                # Add timestamp
                                item["_updated_at"] = datetime.now()
                                
                                # Upsert to MongoDB
                                if collection is not None:
                                    try:
                                        collection.update_one(
                                            {"Code": code},
                                            {"$set": item},
                                            upsert=True
                                        )
                                    except Exception as e:
                                        logger.error(f"Mongo update error for {code}: {e}")
                    
                    global DATA
                    DATA = parsed_data
                    logger.info(f"Midas data updated. {len(DATA)} symbols processed and synced to MongoDB.")
                else:
                    logger.error(f"Unexpected data format: {type(raw_data)}")
            else:
                logger.error(f"Failed to fetch Midas data: {response.status_code}")
        
        except Exception as e:
            logger.error(f"Error fetching Midas data: {e}")
        
        # Wait for 60 seconds before next fetch
        await asyncio.sleep(60)


async def fetch_indices_loop():
    """Background task to fetch index/forex/commodity data every 60 seconds."""
    url = "https://www.getmidas.com/wp-json/midas-api/v1/midas_table_data?return=cards"
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36",
        "Accept": "application/json"
    }

    collection = get_indices_collection()

    while True:
        try:
            response = await asyncio.to_thread(requests.get, url, headers=headers, timeout=30)
            
            if response.status_code == 200:
                raw_data = response.json()
                
                if isinstance(raw_data, str):
                    try:
                        raw_data = json.loads(raw_data)
                    except json.JSONDecodeError:
                        logger.error("Failed to parse indices string response as JSON")
                        continue

                if isinstance(raw_data, list):
                    parsed_indices = {}
                    
                    for item in raw_data:
                        if isinstance(item, str):
                            try:
                                item = json.loads(item)
                            except:
                                continue
                        
                        if isinstance(item, dict):
                            code = item.get("Code")
                            if code:
                                parsed_indices[code] = item
                                
                                # Add timestamp
                                item["_updated_at"] = datetime.now()
                                
                                # Upsert to MongoDB
                                if collection is not None:
                                    try:
                                        collection.update_one(
                                            {"Code": code},
                                            {"$set": item},
                                            upsert=True
                                        )
                                    except Exception as e:
                                        logger.error(f"Mongo update error for index {code}: {e}")
                    
                    global INDEX_DATA
                    INDEX_DATA = parsed_indices
                    logger.info(f"Indices data updated. {len(INDEX_DATA)} indices synced to MongoDB.")
                else:
                    logger.error(f"Unexpected indices data format: {type(raw_data)}")
            else:
                logger.error(f"Failed to fetch indices data: {response.status_code}")
        
        except Exception as e:
            logger.error(f"Error fetching indices data: {e}")
        
        # Wait for 60 seconds before next fetch
        await asyncio.sleep(60)

