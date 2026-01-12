import os
import tweepy
from dotenv import load_dotenv

load_dotenv()

CONSUMER_KEY = os.environ.get("X_CONSUMER_KEY")
CONSUMER_SECRET = os.environ.get("X_CONSUMER_KEY_SECRET")
ACCESS_TOKEN = os.environ.get("X_ACCESS_TOKEN")
ACCESS_TOKEN_SECRET = os.environ.get("X_ACCESS_TOKEN_SECRET")

print(f"Consumer Key Loaded: {'Yes' if CONSUMER_KEY else 'No'}")
print(f"Access Token Loaded: {'Yes' if ACCESS_TOKEN else 'No'}")

client = tweepy.Client(
    consumer_key=CONSUMER_KEY,
    consumer_secret=CONSUMER_SECRET,
    access_token=ACCESS_TOKEN,
    access_token_secret=ACCESS_TOKEN_SECRET
)

print("\n--- TEST 1: Authentication (Get Me) ---")
try:
    me = client.get_me()
    print(f"✅ Success! Connected as: @{me.data.username} (ID: {me.data.id})")
except Exception as e:
    print(f"❌ Auth Failed: {e}")
    exit(1)

print("\n--- TEST 2: Write Permission (Create Tweet) ---")
try:
    import random
    text = f"Test Tweet {random.randint(1000, 9999)} - API Check"
    response = client.create_tweet(text=text)
    print(f"✅ Success! Tweet ID: {response.data['id']}")
    print("Write permission is working correctly.")
except Exception as e:
    print(f"❌ Write Failed: {e}")
    if "403" in str(e):
        print(">>> REASON: 403 Forbidden indicates the Access Token does NOT have Write permission.")
        print(">>> SOLUTION: Regenerate Access Token & Secret in Developer Portal -> Keys and Tokens.")
