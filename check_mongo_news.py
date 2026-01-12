from pymongo import MongoClient
import os
from dotenv import load_dotenv
from bson import ObjectId

load_dotenv()

MONGO_URI = os.environ.get("MONGO_URI", "mongodb://localhost:27017")
client = MongoClient(MONGO_URI)
db = client["kap_news"]
col = db["news_items"]

target_id_hex = "6963d7d770f34a00c7b350ac"

print(f"Checking for ID: {target_id_hex}")

try:
    oid = ObjectId(target_id_hex)
    doc = col.find_one({"_id": oid})
    if doc:
        print(f"✅ Found Document: {doc.get('headline')} (Date: {doc.get('published_at', {}).get('date')})")
    else:
        print("❌ Document NOT found by ObjectId.")
        
    # Also check string match just in case
    doc_str = col.find_one({"_id": target_id_hex})
    if doc_str:
         print(f"✅ Found Document (String ID): {doc_str.get('headline')}")

except Exception as e:
    print(f"Invalid ObjectId format: {e}")

print("\n--- Recent 5 News Items ---")
for item in col.find().sort("published_at.date", -1).limit(5):
    print(f"ID: {item.get('_id')} - Headline: {item.get('headline')} - Date: {item.get('published_at', {}).get('date')}")
