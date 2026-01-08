import os
import json
import time
import requests
from dotenv import load_dotenv

load_dotenv()

TELEGRAM_BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN")
SUBSCRIBERS_FILE = "subscribers.json"

def get_subscribers():
    if not os.path.exists(SUBSCRIBERS_FILE):
        return []
    try:
        with open(SUBSCRIBERS_FILE, 'r') as f:
            return json.load(f)
    except:
        return []

def save_subscribers(subs):
    with open(SUBSCRIBERS_FILE, 'w') as f:
        json.dump(list(set(subs)), f)

def handle_updates(offset=None):
    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/getUpdates"
    params = {"timeout": 100, "offset": offset}
    try:
        resp = requests.get(url, params=params, timeout=110)
        return resp.json()
    except Exception as e:
        print(f"Error getting updates: {e}")
        return None

def main():
    if not TELEGRAM_BOT_TOKEN:
        print("TELEGRAM_BOT_TOKEN not found in .env")
        return

    print("Telegram Subscription Bot Started...")
    offset = None
    
    while True:
        updates = handle_updates(offset)
        if updates and "result" in updates:
            for update in updates["result"]:
                offset = update["update_id"] + 1
                
                if "message" not in update:
                    continue
                    
                message = update["message"]
                chat_id = str(message["chat"]["id"])
                text = message.get("text", "")
                
                subs = get_subscribers()
                
                if text == "/start":
                    if chat_id not in subs:
                        subs.append(chat_id)
                        save_subscribers(subs)
                        print(f"New subscriber: {chat_id}")
                        requests.post(f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage", 
                                      json={"chat_id": chat_id, "text": "✅ KAP Alarmlarına abone oldunuz!"})
                    else:
                        requests.post(f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage", 
                                      json={"chat_id": chat_id, "text": "ℹ️ Zaten abonesiniz."})
                                      
                elif text == "/stop":
                    if chat_id in subs:
                        subs.remove(chat_id)
                        save_subscribers(subs)
                        print(f"Removed subscriber: {chat_id}")
                        requests.post(f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage", 
                                      json={"chat_id": chat_id, "text": "❌ Abonelikten çıktınız."})
        
        time.sleep(1)

if __name__ == "__main__":
    main()
