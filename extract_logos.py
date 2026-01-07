import os
import re
import urllib.request
import ssl
import time

# Create context to ignore SSL issues if any
ctx = ssl.create_default_context()
ctx.check_hostname = False
ctx.verify_mode = ssl.CERT_NONE

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

def get_symbol_logo(symbol):
    # TradingView URL structure
    url = f"https://tr.tradingview.com/symbols/BIST-{symbol}/"
    print(f"Processing {symbol}...")
    
    save_path_svg = f"logos/{symbol}.svg"
    # Check if file already exists to skip
    if os.path.exists(save_path_svg):
        # We assume if SVG exists we are good. If we fell back to PNG it would have a different ext
        print(f"File {save_path_svg} already exists. Skipping.")
        return

    # Check for possible png fallback
    if os.path.exists(f"logos/{symbol}.png"):
         print(f"File logos/{symbol}.png already exists. Skipping.")
         return

    try:
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
            
            # Extract slug
            filename = og_image_url.split('/')[-1]
            slug = filename
            
            if '--' in slug:
                slug = slug.split('--')[0]
            elif '.' in slug:
                slug = slug.split('.')[0]
            
            # Construct SVG URL
            svg_url = f"https://s3-symbol-logo.tradingview.com/{slug}.svg"
            
            if download_file(svg_url, save_path_svg):
                print(f"Saved SVG: {save_path_svg}")
            else:
                # Fallback to og:image (likely PNG)
                ext = og_image_url.split('.')[-1]
                save_path_orig = f"logos/{symbol}.{ext}"
                if download_file(og_image_url, save_path_orig):
                    print(f"Saved fallback {ext}: {save_path_orig}")
                else:
                    print(f"Failed to download logo for {symbol}")
        else:
            print(f"og:image not found for {symbol}")
            
    except Exception as e:
        print(f"Error processing {symbol}: {e}")

def extract_symbols_from_html(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Regex to find value="SYMBOL"
    symbols = re.findall(r'<option value="([^"]+)">', content)
    # Filter out potential placeholder
    return [s for s in symbols if s != "Hisse Seçiniz..." and len(s) > 1]

def main():
    if not os.path.exists('logos'):
        os.makedirs('logos')
        
    symbols_file = 'symbols.html'
    if not os.path.exists(symbols_file):
        print(f"File {symbols_file} not found.")
        return

    symbols = extract_symbols_from_html(symbols_file)
    print(f"Found {len(symbols)} symbols in {symbols_file}.")
    
    for i, symbol in enumerate(symbols):
        get_symbol_logo(symbol)
        # Moderate delay to be kind
        time.sleep(0.5)

if __name__ == "__main__":
    main()
