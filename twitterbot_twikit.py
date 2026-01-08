# twitterbot_twikit.py
# Twikit kütüphanesi ile Twitter'a post atan bot.
# API Anahtarı GEREKMEZ - Kullanıcı adı ve şifre ile giriş yapar.
# Gereksinimler: pip install twikit google-genai pymongo python-dotenv pillow

import os
import json
import time
import asyncio
from datetime import datetime
from dotenv import load_dotenv
from google import genai
import random

load_dotenv()

# ======================
# CONFIG
# ======================
# Twitter (X) - Kullanıcı Bilgileri (API yerine)
TWITTER_USERNAME = os.environ.get("TWITTER_USERNAME")  # @kullanici_adi (@ olmadan)
TWITTER_EMAIL = os.environ.get("TWITTER_EMAIL")        # Hesaba bağlı e-posta
TWITTER_PASSWORD = os.environ.get("TWITTER_PASSWORD")  # Twitter şifresi

# Google Gemini
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

# Dosyalar
COOKIES_FILE = "./news/twikit_cookies.json"
IMAGES_DIR = "./news/images"

# Ayarlar
POLL_INTERVAL = 60
TWEET_INTERVAL = 120  # Tweetler arası bekleme (saniye)
ERROR_COOLDOWN = 600  # Hata sonrası bekleme (saniye)

# ======================
# IMPORTS
# ======================
from PIL import Image
import io
from pymongo import MongoClient, DESCENDING
from twikit import Client

# MongoDB Ayarları
MONGO_URI = os.environ.get("MONGO_URI", "mongodb://localhost:27017")
MONGO_DB = "kap_news"
NEWS_COLLECTION = "news_items"
POSTED_COLLECTION = "posted_tweets"  # Ayrı collection (tweepy ile karışmasın)

# ======================
# HELPER FUNCTIONS
# ======================

def get_mongo_db():
    try:
        client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
        return client[MONGO_DB]
    except Exception as e:
        print(f"❌ MongoDB Bağlantı Hatası: {e}")
        return None

def load_posted_ids_mongo():
    """MongoDB'den atılmış tweetlerin unique ID'lerini çeker."""
    db = get_mongo_db()
    if db is None: return set()
    
    cursor = db[POSTED_COLLECTION].find({}, {"unique_id": 1, "_id": 0})
    return {doc["unique_id"] for doc in cursor if "unique_id" in doc}

def save_posted_tweet_mongo(tweet_data):
    """Atılan tweeti MongoDB'ye kaydeder."""
    db = get_mongo_db()
    if db is None: return
    
    try:
        tweet_data["created_at"] = datetime(2026, 1, 7)
        tweet_data["source"] = "twikit"  # Kaynak belirt
        db[POSTED_COLLECTION].insert_one(tweet_data)
    except Exception as e:
        print(f"⚠️ Tweet loglama hatası: {e}")

def load_news_mongo():
    """MongoDB'den haberleri çeker."""
    db = get_mongo_db()
    if db is None: return []

    cursor = db[NEWS_COLLECTION].find().sort("_inserted_at", DESCENDING)
    return list(cursor)

def setup_gemini():
    if not GEMINI_API_KEY:
        print("[ERROR] GEMINI_API_KEY eksik.")
        return None
    return genai.Client(api_key=GEMINI_API_KEY)

def generate_gemini_image(client, prompt, ana_mesaj, ana_rakam, unique_id):
    """Google Gemini ile görsel üretir ve cache'ler."""
    if not client or not prompt:
        return None

    os.makedirs(IMAGES_DIR, exist_ok=True)
    safe_id = "".join([c if c.isalnum() or c in "._- " else "_" for c in unique_id])
    image_path = os.path.join(IMAGES_DIR, f"{safe_id}.png")

    if os.path.exists(image_path):
        print(f"♻️ Görsel cache'den alındı: {image_path}")
        return image_path
    
    print(f"🎨 Görsel Çiziliyor: '{prompt[:50]}...'")
    try:
        enhanced_prompt = f"""
        Fotoğrafını üret: {prompt}.
        Görselin üzerine, minimal ve profesyonel bir finansal infografik tarzında, sadece şu iki bilgiyi içeren büyük ve dikkat çekici bir metin katmanı ekle:
        1. Ana Başlık: "{ana_mesaj}"
        2. Büyük Rakam: "{ana_rakam}"
        
        Kurallar:
        - Asla başka bir rakam, döviz kuru, hisse fiyatı, tarih veya büyüme oranı gibi veri EKLEME.
        - Yüksek kontrastlı, mavi ve beyaz tonlarda, profesyonel bir kurumsal görsel olsun.
        - Asla meme, stok foto veya kalabalık metin kullanma. Yazılan her şey Türkçe olsun.
        - Büyük rakam "none" ise fotoğrafa "none" yazma.
        """
        
        response = client.models.generate_content(
            model="gemini-3-pro-image-preview",
            contents=enhanced_prompt
        )

        if response.parts:
            for part in response.parts:
                if part.inline_data:
                    image = part.as_image()
                    image.save(image_path)
                    print(f"✅ Görsel üretildi ve kaydedildi: {image_path}")
                    return image_path
        
        print("❌ Model metin döndü veya görsel üretemedi.")
        return None

    except Exception as e:
        print(f"❌ Görsel Üretme Hatası: {e}")
        return None

def format_tweet(item):
    """Tweet metnini formatlar."""
    tweet_data = item.get("tweet", {})
    notes = item.get("notes", {})
    
    base_text = tweet_data.get("text", "")
    if not base_text: 
        base_text = f"🚨 #{item.get('ticker')}: {item.get('headline')}"

    editor_comment = notes.get("editor_comment")
    kap_url = item.get("url")
    hashtags = tweet_data.get("hashtags", [])

    footer_str = ""
    footer_twitter_len = 0 

    if kap_url:
        footer_str += f"\n\n🔗 {kap_url}"
        footer_twitter_len += 2 + 23 

    if hashtags:
        tags_str = " ".join(hashtags)
        footer_str += f"\n\n{tags_str}"
        footer_twitter_len += 2 + len(tags_str)

    MAX_LEN = 280
    BUFFER = 3
    
    available_for_text = MAX_LEN - footer_twitter_len - BUFFER
    current_body = base_text
    
    if len(current_body) > available_for_text:
        current_body = current_body[:available_for_text-3] + "..."

    current_total_len = len(current_body) + footer_twitter_len + BUFFER
    remaining_space = MAX_LEN - current_total_len
    
    if editor_comment and not notes.get("is_routine_spam"):
        formatted_note = f"\n\nℹ️ Not: {editor_comment}"
        note_len = len(formatted_note)
        
        if note_len <= remaining_space:
            current_body += formatted_note

    final_tweet = current_body + footer_str
    return final_tweet

def get_today_str():
    return datetime(2026, 1, 7).strftime("%Y-%m-%d")

# ======================
# TWIKIT CLIENT SETUP
# ======================

async def setup_twikit_client():
    """Twikit client'ı başlatır ve cookie'lerden giriş yapar."""
    client = Client('tr-TR')  # Türkçe locale
    
    print("🍪 Cookie'ler manuel olarak ayarlanıyor...")
    try:
        # Cookie'leri manuel olarak ayarla
        # Bu değerler tarayıcıdan alındı
        client.set_cookies({
            'auth_token': '29eba4ea487789f75c52a6ea2a41c25f91502094',
            'ct0': 'a99c51fe150dd8372bb51b739c0f9c5ca58dc908871f04b428eea4c615cf7aa07be5effe754e1b2707eeef517e62d33f70ade106abdc81d1cc906c8cd6e06bb185657d6036ed07338013374cd17155f4',
        })
        print("✅ Cookie'ler ayarlandı! Tweet atmaya hazır.")
        return client
    except Exception as e:
        print(f"❌ Cookie ayarlama hatası: {e}")
        # Alternatif: Doğrudan httpx client'ına cookie ekle
        try:
            print("🔄 Alternatif yöntem deneniyor...")
            client._client.cookies.set('auth_token', '29eba4ea487789f75c52a6ea2a41c25f91502094', domain='.x.com')
            client._client.cookies.set('ct0', 'a99c51fe150dd8372bb51b739c0f9c5ca58dc908871f04b428eea4c615cf7aa07be5effe754e1b2707eeef517e62d33f70ade106abdc81d1cc906c8cd6e06bb185657d6036ed07338013374cd17155f4', domain='.x.com')
            print("✅ Alternatif yöntem başarılı!")
            return client
        except Exception as e2:
            print(f"❌ Alternatif yöntem de başarısız: {e2}")
            return None

async def post_tweet_with_media(client, text, image_path=None):
    """Twikit ile tweet atar (opsiyonel görsel ile)."""
    try:
        # Debug: text'in tipini ve içeriğini göster
        print(f"📝 Tweet metni tipi: {type(text)}")
        print(f"📝 Tweet metni uzunluğu: {len(str(text)) if text else 0}")
        
        # text'in string olduğundan emin ol
        if not isinstance(text, str):
            print(f"⚠️ Text string değil, dönüştürülüyor: {type(text)}")
            text = str(text)
        
        media_id = None
        
        if image_path and os.path.exists(image_path):
            print(f"📤 Görsel yükleniyor: {image_path}")
            try:
                media_id = await client.upload_media(image_path)
                print(f"✅ Görsel yüklendi (ID: {media_id}, Type: {type(media_id)})")
            except Exception as upload_err:
                print(f"⚠️ Görsel yükleme hatası: {upload_err}")
                print("📝 Görselsiz tweet atılacak...")
                media_id = None
        
        # Tweet oluştur
        print("🔄 create_tweet çağrılıyor...")
        if media_id:
            # media_id'yi string'e çevir ve listeye koy
            tweet = await client.create_tweet(text=text, media_ids=[str(media_id)])
        else:
            tweet = await client.create_tweet(text=text)
        
        print(f"🚀 Tweet gönderildi! ID: {tweet.id}")
        return tweet
        
    except Exception as e:
        print(f"❌ Tweet atma hatası: {e}")
        import traceback
        traceback.print_exc()
        raise e

# ======================
# MAIN ASYNC LOOP
# ======================

async def main():
    print("🤖 Twitter Bot (Twikit - API'siz) Başlatılıyor...")
    print("=" * 50)
    
    # Twikit client'ı başlat
    twitter_client = await setup_twikit_client()
    if not twitter_client:
        print("❌ Twitter bağlantısı kurulamadı. Çıkılıyor.")
        return
    
    # Gemini client'ı başlat
    gemini_client = setup_gemini()
    if not gemini_client:
        print("⚠️ Gemini bağlantısı kurulamadı. Görselsiz devam edilecek.")
    
    print(f"[INFO] MongoDB ({MONGO_DB}) izleniyor...")
    posted_ids = load_posted_ids_mongo()
    
    while True:
        try:
            news_items = load_news_mongo()
            print(f"🔍 MongoDB'den {len(news_items)} haber çekildi")
            today_str = get_today_str()
            print(f"📅 Bugünün tarihi: {today_str}")
            
            queue = []
            skipped_already_posted = 0
            skipped_web_only = 0
            skipped_old = 0
            
            for item in news_items:
                unique_id = f"{item.get('primary_ticker')}_{item.get('published_at')}_{item.get('headline')}"
                
                if unique_id in posted_ids:
                    skipped_already_posted += 1
                    continue
                
                if item.get("publish_target") != "ALL_CHANNELS":
                    posted_ids.add(unique_id)
                    skipped_web_only += 1
                    continue

                published_at_raw = item.get("published_at")
                if isinstance(published_at_raw, dict):
                    item_date = published_at_raw.get("date")
                else:
                    item_date = today_str 

                if item_date and item_date < today_str:
                    print(f"🚫 Eski Haber Atlandı (Tarih: {item_date}): {item.get('headline')}")
                    posted_ids.add(unique_id)
                    save_posted_tweet_mongo({
                        "unique_id": unique_id,
                        "status": "SKIPPED_OLD",
                        "reason": f"News date {item_date} is older than {today_str}",
                        "headline": item.get('headline')
                    })
                    skipped_old += 1
                    continue
                
                print(f"✅ Queue'ya ekleniyor: {item.get('primary_ticker')} - {item.get('headline')[:50]}")
                queue.append((unique_id, item))
            
            print(f"📊 Filtreleme Özeti: Zaten atılmış={skipped_already_posted}, WEB_ONLY={skipped_web_only}, Eski={skipped_old}, Queue={len(queue)}")

            if queue:
                print(f"[INFO] {len(queue)} adet yeni flaş haber var.")

            for unique_id, item in queue:
                text = format_tweet(item)
                visual_prompt = item.get("visual_prompt")
                ana_mesaj = item.get("headline")
                key_numbers = item.get("key_numbers", {})
                ana_rakam = key_numbers.get("amount_raw")
                image_path = None

                # 1. GÖRSEL ÜRETİMİ
                if visual_prompt and gemini_client:
                    image_path = generate_gemini_image(gemini_client, visual_prompt, ana_mesaj, ana_rakam, unique_id)

                # 2. TWEETİ AT
                print(f"🐦 Tweet Atılıyor: {item.get('primary_ticker')}...")
                try:
                    tweet = await post_tweet_with_media(twitter_client, text, image_path)
                    
                    posted_ids.add(unique_id)
                    save_posted_tweet_mongo({
                        "unique_id": unique_id,
                        "tweet_id": str(tweet.id),
                        "status": "SENT",
                        "headline": ana_mesaj,
                        "ticker": item.get("primary_ticker"),
                        "text": text
                    })

                    print(f"⏳ Tweet aralığı: {TWEET_INTERVAL//60} dakika bekleniyor...")
                    await asyncio.sleep(TWEET_INTERVAL)
                    
                except Exception as e:
                    print(f"❌ Tweet Hatası: {e}")
                    print(f"🔍 Hata Tipi: {type(e).__name__}")
                    
                    # Rate limit veya diğer hatalar için cooldown
                    if "rate" in str(e).lower() or "limit" in str(e).lower():
                        print(f"⚠️ Rate limit algılandı. {ERROR_COOLDOWN//60} dakika bekleniyor...")
                        await asyncio.sleep(ERROR_COOLDOWN)
                    else:
                        print(f"💤 Hata Cooldown: {ERROR_COOLDOWN//60} dakika bekleniyor...")
                        await asyncio.sleep(ERROR_COOLDOWN)
                    continue

            # Ana döngü beklemesi
            bekleme_suresi = random.randint(60, 90)
            print(f"⏸️ {bekleme_suresi} saniye sonra tekrar kontrol edilecek...")
            await asyncio.sleep(bekleme_suresi)

        except KeyboardInterrupt:
            print("\n🛑 Kullanıcı tarafından durduruldu.")
            break
        except Exception as e:
            print(f"[CRITICAL] Döngü hatası: {e}")
            await asyncio.sleep(60)

if __name__ == "__main__":
    asyncio.run(main())
