import os
import re
import urllib.request
import ssl
import time
from pymongo import MongoClient
from dotenv import load_dotenv

# Load environment variables
load_dotenv()

# MongoDB Configuration
MONGO_URI = os.environ.get("MONGO_URI", "mongodb://localhost:27017")
MONGO_DB = "kap_news"
TICKERS_COLLECTION = "tickers"

# Create context to ignore SSL issues if any
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

def get_mongo_db():
    try:
        client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
        return client[MONGO_DB]
    except Exception as e:
        print(f"❌ MongoDB Bağlantı Hatası: {e}")
        return None

def download_file(url, save_path):
    try:
        req = urllib.request.Request(
            url, 
            headers={'User-Agent': 'Mozilla/5.0'}
        )
        with urllib.request.urlopen(req, context=ctx) as response:
            with open(save_path, 'wb') as f:
                f.write(response.read())
        return True
    except Exception as e:
        # print(f"Download failed for {url}: {e}")
        # 404 is common for SVG if it doesn't exist
        return False

def download_logo_for_candidate(candidate_symbol):
    """
    Helper function to try downloading logo for a specific single symbol.
    Returns the path to the temporary downloaded file if successful, otherwise None.
    The caller is responsible for renaming/moving it to the final destination.
    """
    url = f"https://tr.tradingview.com/symbols/BIST-{candidate_symbol}/"
    temp_save_path = f"logos/temp_{candidate_symbol}.svg"
    
    try:
        # Request TradingView Page
        req = urllib.request.Request(
            url, 
            headers={'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.114 Safari/537.36'}
        )
        with urllib.request.urlopen(req, context=ctx) as response:
            html_content = response.read().decode('utf-8')
            
        # Try finding og:image
        match = re.search(r'<meta property="og:image" content="(.*?)"', html_content)
        if match:
            og_image_url = match.group(1)
            
            # Extract slug from og:image URL
            filename = og_image_url.split('/')[-1]
            slug = filename
            if '--' in slug: slug = slug.split('--')[0]
            elif '.' in slug: slug = slug.split('.')[0]
            
            # Construct SVG URL
            svg_url = f"https://s3-symbol-logo.tradingview.com/{slug}.svg"
            
            # Try downloading SVG
            if download_file(svg_url, temp_save_path):
                return temp_save_path
            
            # Fallback to PNG/original extension if SVG fails
            ext = og_image_url.split('.')[-1]
            temp_save_path_orig = f"logos/temp_{candidate_symbol}.{ext}"
            if download_file(og_image_url, temp_save_path_orig):
                return temp_save_path_orig
                
    except Exception as e:
        # print(f"  Failed for candidate {candidate_symbol}: {e}")
        pass
        
    return None

def get_symbol_logo(symbol):
    print(f"Processing {symbol}...")
    
    # Define final save path (using the DB key, even if it has commas, to match frontend lookups)
    # Using .svg as default preferred, but logic will handle extensions
    # Note: If we have multiple formats, we might end up with .png and .svg. Clean up?
    save_path_base = f"logos/{symbol}" # without extension
    
    # Check if already exists (svg or png)
    if os.path.exists(f"{save_path_base}.svg"):
        print(f"File {save_path_base}.svg already exists. Skipping.")
        return
    if os.path.exists(f"{save_path_base}.png"):
        print(f"File {save_path_base}.png already exists. Skipping.")
        return

    # Determine candidates (split by comma if exists)
    candidates = [s.strip() for s in symbol.split(",")] if "," in symbol else [symbol]
    
    success = False
    
    for cand in candidates:
        if not cand: continue
        # Clean candidate (remove control chars just in case)
        cand = re.sub(r'[\x00-\x1f\x7f-\x9f\s]', '', cand)
        
        # print(f"  Trying candidate: {cand}")
        temp_file = download_logo_for_candidate(cand)
        
        if temp_file:
            # Move temp file to final destination
            ext = temp_file.split('.')[-1]
            final_path = f"{save_path_base}.{ext}"
            
            os.rename(temp_file, final_path)
            print(f"✅ Saved logo for '{symbol}' (found via {cand}) -> {final_path}")
            success = True
            break
            
    if not success:
        print(f"❌ Failed to find logo for {symbol} (tried: {candidates})")

def get_symbols_from_mongo():
    db = get_mongo_db()
    if db is None:
        return []
    
    # Tüm sembolleri çek
    cursor = db[TICKERS_COLLECTION].find({}, {"symbol": 1})
    symbols = [doc["symbol"] for doc in cursor]
    return symbols

def main():
    if not os.path.exists('logos'):
        os.makedirs('logos')
        
    print("🚀 Fetching symbols from MongoDB...")
    symbols = get_symbols_from_mongo()
    
    if not symbols:
        print("❌ No symbols found in MongoDB. Please run fetch_symbols.py first.")
        return

    print(f"Found {len(symbols)} symbols in MongoDB.")
    
    for i, symbol in enumerate(symbols):
        get_symbol_logo(symbol)
        # Moderate delay to be kind
        time.sleep(0.5)
        
    print("🏁 Logo extraction completed.")

if __name__ == "__main__":
    main()
