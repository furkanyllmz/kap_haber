import os
import json
import requests
import argparse
from bs4 import BeautifulSoup
import time
import re

def parse_symbols(html_path):
    """Parses stock symbols from the provided HTML file."""
    if not os.path.exists(html_path):
        print(f"Error: {html_path} does not exist.")
        return []
        
    with open(html_path, 'r', encoding='utf-8') as f:
        html_content = f.read()
        
    soup = BeautifulSoup(html_content, 'html.parser')
    select_element = soup.find('select', {'id': 'ddlMenuShareSearch'})
    
    if not select_element:
        print("Error: Could not find select element with id 'ddlMenuShareSearch'")
        return []
        
    symbols = []
    options = select_element.find_all('option')
    for option in options:
        value = option.get('value')
        if value and value != "Hisse Seçiniz...":
            symbols.append(value)
            
    return symbols

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
        
        # Example of data extraction - needs to be refined based on actual page structure
        # User asked for "company size, profit, revenue"
        # These are usually in summary tables. 
        # Since I can't browse the page right now, I'll dump some common selectors or just text that looks like financials.
        # But to start, I'll just check if I can get the page title or something unique.
        
        page_title = soup.title.text.strip() if soup.title else "No Title"
        data['page_title'] = page_title
        
        # Parse Market Cap (Piyasa Değeri)
        # Structure: <th>Piyasa Değeri</th><td>7.674,8 mnTL</td>
        market_cap_th = soup.find('th', string=re.compile(r"Piyasa Değeri"))
        if market_cap_th:
            data['market_cap'] = market_cap_th.find_next_sibling('td').text.strip()
            
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

        return data

    except Exception as e:
        print(f"Error fetching data for {symbol}: {e}")
        return None

def main():
    parser = argparse.ArgumentParser(description="Fetch financial data for BIST stocks.")
    parser.add_argument("--html", default="symbols.html", help="Path to HTML file with symbols")
    parser.add_argument("--output_dir", default="daily_data_kap/financials", help="Directory to save JSON files")
    parser.add_argument("--test_one", help="Test fetching for a single symbol", type=str)

    args = parser.parse_args()
    
    # Create output directory
    if not os.path.exists(args.output_dir):
        os.makedirs(args.output_dir)
        
    symbols = parse_symbols(args.html)
    print(f"Found {len(symbols)} symbols.")
    
    if args.test_one:
        print(f"Testing fetch for {args.test_one}...")
        data = fetch_financial_data(args.test_one)
        print(json.dumps(data, indent=2, ensure_ascii=False))
        return

    print("Starting batch fetch...")
    for i, symbol in enumerate(symbols):
        print(f"[{i+1}/{len(symbols)}] Fetching {symbol}...")
        
        # Check if already exists to allow resuming
        output_file = os.path.join(args.output_dir, f"{symbol}_financials.json")
        if os.path.exists(output_file):
            print(f"  Skipping {symbol}, already exists.")
            continue
            
        data = fetch_financial_data(symbol)
        
        if data:
            with open(output_file, 'w', encoding='utf-8') as f:
                json.dump(data, f, indent=2, ensure_ascii=False)
        
        # Respectful delay
        time.sleep(0.5)
        
    print("Done!")

if __name__ == "__main__":
    main()
