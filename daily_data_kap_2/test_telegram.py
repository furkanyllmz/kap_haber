import os
import json
import requests
from dotenv import load_dotenv

load_dotenv()

TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN")
SUBSCRIBERS_FILE = "subscribers.json"

def main():
    print(f"Token: {TOKEN}")
    
    if os.path.exists(SUBSCRIBERS_FILE):
        with open(SUBSCRIBERS_FILE, 'r') as f:
            subs = json.load(f)
        print(f"Subscribers: {subs}")
        
        url = f"https://api.telegram.org/bot{TOKEN}/sendMessage"
        
        for chat_id in subs:
            print(f"Sending test to {chat_id}...")
            payload = {
                "chat_id": chat_id,
                "text": "🧪 Test Mesajı (Antigravity)",
                "parse_mode": "Markdown"
            }
            resp = requests.post(url, json=payload)
            print(f"Status: {resp.status_code}")
            print(f"Response: {resp.text}")
    else:
        print("Subscribers file not found.")

if __name__ == "__main__":
    main()
