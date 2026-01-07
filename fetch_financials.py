import os
import json
import requests
import argparse
from bs4 import BeautifulSoup
import time
import re
from pymongo import MongoClient
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
        print(f"❌ MongoDB Bağlantı Hatası: {e}")
        return None

def get_symbols_from_mongo():
    """Fetches stock symbols from MongoDB."""
    db = get_mongo_db()
    if db is None:
        return []
    
    try:
        cursor = db[TICKERS_COLLECTION].find({}, {"symbol": 1})
        symbols = [doc["symbol"] for doc in cursor]
        return symbols
    except Exception as e:
        print(f"❌ Error fetching symbols from MongoDB: {e}")
        return []

def fetch_financial_data(symbol):
    """
    Fetches financial data for a given symbol from isyatirim.com.tr
    """
    url = f"https://www.isyatirim.com.tr/tr-tr/analiz/hisse/Sayfalar/sirket-karti.aspx?hisse={symbol}"
    
    # IsYatirim might require headers to behave like a browser
    headers = {
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36'
    }
    
    try:
        response = requests.get(url, headers=headers, timeout=10)
        response.raise_for_status()
        
        soup = BeautifulSoup(response.content, 'html.parser')
        
        # Initialize data dictionary
        data = {
            'symbol': symbol,
            'fetched_at': time.time()
        }
        
        market_cap_found = False

        # Parse Market Cap (Piyasa Değeri)
        # Structure: <th>Piyasa Değeri</th><td>7.674,8 mnTL</td>
        market_cap_th = soup.find('th', string=re.compile(r"Piyasa Değeri"))
        if market_cap_th:
            val = market_cap_th.find_next_sibling('td').text.strip()
            data['market_cap'] = val
            if val: market_cap_found = True
            
        # Parse Net Profit (Dönem Net Kar/Zararı)
        # Structure: <td>Dönem Net Kar/Zararı</td><td>Value</td> ...
        net_profit_td = soup.find('td', string=re.compile(r"Dönem Net Kar/Zararı"))
        if net_profit_td:
            data['net_profit'] = net_profit_td.find_next_sibling('td').text.strip()
            
        # Parse Revenue (Satış Gelirleri)
        # Structure: <td>Satış Gelirleri</td><td>Value</td> ...
        revenue_td = soup.find('td', string=re.compile(r"Satış Gelirleri"))
        if revenue_td:
            data['revenue'] = revenue_td.find_next_sibling('td').text.strip()

        # Parse Free Float (Halka Açıklık Oranı)
        free_float_th = soup.find('th', string=re.compile(r"Halka Açıklık Oranı"))
        if free_float_th:
            data['free_float_rate'] = free_float_th.find_next_sibling('td').text.strip()

        # VALIDATION: If we didn't find basic info like Market Cap, assume bad fetch
        if not market_cap_found:
            return None

        return data

    except Exception as e:
        # print(f"Error fetching data for {symbol}: {e}")
        return None

def main():
    parser = argparse.ArgumentParser(description="Fetch financial data for BIST stocks.")
    parser.add_argument("--output_dir", default="daily_data_kap/financials", help="Directory to save JSON files")
    parser.add_argument("--test_one", help="Test fetching for a single symbol", type=str)

    args = parser.parse_args()
    
    # Create output directory
    if not os.path.exists(args.output_dir):
        os.makedirs(args.output_dir)
        
    print("🚀 Fetching symbols from MongoDB...")
    symbols = get_symbols_from_mongo()
    
    if not symbols:
        print("❌ No symbols found in MongoDB. Please run fetch_symbols.py first.")
        return

    print(f"Found {len(symbols)} symbols in MongoDB.")
    
    if args.test_one:
        print(f"Testing fetch for {args.test_one}...")
        data = fetch_financial_data(args.test_one)
        print(json.dumps(data, indent=2, ensure_ascii=False))
        return

    print("Starting batch fetch...")
    for i, symbol_key in enumerate(symbols):
        print(f"[{i+1}/{len(symbols)}] Fetching {symbol_key}...")
        
        output_file = os.path.join(args.output_dir, f"{symbol_key}_financials.json")
        if os.path.exists(output_file):
            print(f"  Skipping {symbol_key}, already exists.")
            continue
            
        # Handle composite symbols (e.g. "ALBRK, ALK")
        candidates = [s.strip() for s in symbol_key.split(",")] if "," in symbol_key else [symbol_key]
        
        success_data = None
        for cand in candidates:
             # Clean candidate
             cand = re.sub(r'[\x00-\x1f\x7f-\x9f\s]', '', cand)
             if not cand: continue
             
             data = fetch_financial_data(cand)
             if data:
                 success_data = data
                 # Key point: Ensure the saved symbol matches the DB key for consistency
                 success_data['symbol'] = symbol_key 
                 success_data['fetched_using'] = cand
                 break
        
        if success_data:
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(success_data, f, indent=2, ensure_ascii=False)
        else:
            print(f"  ❌ No valid data found for {symbol_key}")
        
        # Respectful delay
        time.sleep(0.5)
        
    print("Done!")

if __name__ == "__main__":
    main()
