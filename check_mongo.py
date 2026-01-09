from pymongo import MongoClient
import json
import os

client = MongoClient("mongodb://localhost:27017")
db = client["kap_news"]
collection = db["prices"]

# Get one document
item = collection.find_one()

if item:
    # Convert ObjectId to str for printing
    if '_id' in item:
        item['_id'] = str(item['_id'])
    if '_updated_at' in item:
        item['_updated_at'] = str(item['_updated_at'])
        
    print(json.dumps(item, indent=2, ensure_ascii=False))
else:
    print("No data found in prices collection.")
