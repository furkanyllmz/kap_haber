import os
import requests
import re
import json
from pymongo import MongoClient, UpdateOne
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# MongoDB Configuration
MONGO_URI = os.environ.get("MONGO_URI", "mongodb://localhost:27017")
MONGO_DB = "kap_news"
TICKERS_COLLECTION = "tickers"

def get_mongo_db():
    try:
        client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
        return client[MONGO_DB]
    except Exception as e:
        print(f"❌ MongoDB Connection Error: {e}")
        return None

def fetch_symbols():
    print("🚀 Starting Symbol Fetcher (Web Source)...")
    
    # 1. MongoDB Connection
    db = get_mongo_db()
    if db is None:
        return

    # 2. Fetch HTML from KAP Website
    url = "https://www.kap.org.tr/tr/bist-sirketler"
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    }

    try:
        print(f"🌐 Fetching URL: {url}...")
        response = requests.get(url, headers=headers)
        if response.status_code != 200:
            print(f"❌ Error: Failed to fetch page. Status: {response.status_code}")
            return
        content = response.text
        print(f"✅ Page Fetched. Content Length: {len(content)}")
    except Exception as e:
        print(f"❌ Error fetching URL: {e}")
        return

    # 3. Parse JSON Data embedded in HTML
    print("🔍 Parsing content for symbols...")
    
    # 3. Parse JSON Data embedded in HTML
    print("🔍 Parsing content for symbols...")
    
    # Veri ESCAPED JSON string içinde duruyor!
    # Örnek: ... \"mkkMemberOid\":\"4028...\" ...
    
    operations = []
    count = 0
    
    # "mkkMemberOid" unique key'ini kullanarak split edelim
    # Ancak escape edildiği için \"mkkMemberOid\" şeklinde aramalıyız
    # Python string içinde backslash için \\ kullanırız. 
    # HTML içinde \" olduğu için python regexinde \\" arayacağız.
    
    # Basitçe tüm escaped JSON yapısını bulalım
    # \"stockCode\":\"AGROT\"
    
    # Regex ile stockCode ve companyName'i çekelim
    # Pattern: \"kapMemberTitle\":\"(.*?)\".*?\"stockCode\":\"(.*?)\"
    # Not: Sırası değişebilir, o yüzden ayrı ayrı aramak daha güvenli olabilir ama genelde aynıdır.
    # Data örneği: ... \"kapMemberTitle\":\"ACISELSAN...\",\"relatedMemberTitle\":\"...\",\"stockCode\":\"ACSEL\", ...
    
    # Tüm stringi tarayıp object bloklarını bulmak zor çünkü {} yok, her şey string içinde.
    # En güvenlisi findall ile tüm stockCode ve kapMemberTitle eşleşmelerini bulup eşleştirmek
    
    # Ancak sırayla geldikleri için iteratif gidebiliriz.
    # Veri yapısı array içinde object olduğu için sıralı olacaklardır.
    
    # Regex pattern:
    # \"kapMemberTitle\":\"(.*?)\".*?\"stockCode\":\"(.*?)\"
    # Bu pattern çalışır çünkü JSON field sırası genelde sabittir.
    
    pattern = r'\\"kapMemberTitle\\":\\"(.*?)\\",.*?\\"stockCode\\":\\"(.*?)\\"'
    matches = re.finditer(pattern, content)
    
    print("🔍 Searching with regex pattern...")
    
    for match in matches:
        try:
            title = match.group(1)
            symbol = match.group(2)
            
            # Unicode escape sequence'ları ve backslash'leri temizle
            # title içinde \\u0130 gibi karakterler olabilir
            try:
                 # Python'un unicode decode yeteneğini kullanarak
                 title = bytes(title, 'utf-8').decode('unicode_escape')
            except:
                pass

            # BIST şirketleri testi
            if len(symbol) > 10 or len(title) < 2: 
                continue

            count += 1
            op = UpdateOne(
                {"symbol": symbol},
                {"$set": {
                    "symbol": symbol,
                    "company_name": title,
                    "source": "kap_website_live",
                    "updated_at": os.popen('date -u +"%Y-%m-%dT%H:%M:%SZ"').read().strip()
                }},
                upsert=True
            )
            operations.append(op)
            
        except Exception as e:
            # print(f"Parse error: {e}")
            continue

    print(f"🔍 Found {count} valid symbols.")

    # 4. Execute Bulk Write
    if operations:
        try:
            result = db[TICKERS_COLLECTION].bulk_write(operations)
            print(f"✅ Database Update Complete.")
            print(f"   Inserted: {result.upserted_count}")
            print(f"   Modified: {result.modified_count}")
            print(f"   Matched: {result.matched_count}")
        except Exception as e:
            print(f"❌ MongoDB Bulk Write Error: {e}")
    else:
        print("⚠️ No symbols found. The website structure might have changed.")

    print("🏁 Symbol Fetcher Completed.")

if __name__ == "__main__":
    fetch_symbols()
