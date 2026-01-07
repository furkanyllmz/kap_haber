# twitter_bot.py
# news_items.json dosyasını izler, Google Gemini (Nano Banana) ile görsel üretir ve X'e atar.
# Gereksinimler: pip install google-genai tweepy

import os
import json
import time
import base64
import tweepy
from datetime import datetime
from dotenv import load_dotenv
from google import genai
from google.genai import types
import random

load_dotenv()

# ======================
# CONFIG
# ======================
# Twitter (X)
CONSUMER_KEY = os.environ.get("X_CONSUMER_KEY")
CONSUMER_SECRET = os.environ.get("X_CONSUMER_KEY_SECRET")
ACCESS_TOKEN = os.environ.get("X_ACCESS_TOKEN")
ACCESS_TOKEN_SECRET = os.environ.get("X_ACCESS_TOKEN_SECRET")

# Google Gemini (Zaten var olan anahtarın)
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")

# Dosyalar
NEWS_FILE = "./news/news_items.json"
STATE_FILE = "./news/posted_tweets.json"
DAILY_STATE_FILE = "./news/daily_limit_state.json"
TEMP_IMAGE_PATH = "./temp_news_image.png"

# Ayarlar
POLL_INTERVAL = 60 
IMAGE_MODEL_NAME = "gemini-3-pro-preview"
DAILY_TWEET_LIMIT = 17

def setup_twitter_api_v1():
    auth = tweepy.OAuth1UserHandler(
        CONSUMER_KEY, CONSUMER_SECRET, ACCESS_TOKEN, ACCESS_TOKEN_SECRET
    )
    return tweepy.API(auth)

def setup_twitter_client_v2():
    return tweepy.Client(
        consumer_key=CONSUMER_KEY,
        consumer_secret=CONSUMER_SECRET,
        access_token=ACCESS_TOKEN,
        access_token_secret=ACCESS_TOKEN_SECRET
    )

def setup_gemini():
    if not GEMINI_API_KEY:
        print("[ERROR] GEMINI_API_KEY eksik.")
        return None
    return genai.Client(api_key=GEMINI_API_KEY)

# Gerekli importları dosyanın en başına eklemeyi unutma:
from PIL import Image
import io

# ... (Diğer importlar ve ayarlar aynı kalsın) ...

def generate_gemini_image(client, prompt, ana_mesaj, ana_rakam, unique_id):
    """
    Google Gemini 2.0 Flash / 2.5 Flash Image kullanarak görsel üretir.
    Görselleri ./news/images altında unique_id ile cache'ler.
    """
    if not client or not prompt:
        return None

    # Cache klasörü oluştur
    IMAGES_DIR = "./news/images"
    os.makedirs(IMAGES_DIR, exist_ok=True)

    # Güvenli dosya adı
    safe_id = "".join([c if c.isalnum() or c in "._- " else "_" for c in unique_id])
    image_path = os.path.join(IMAGES_DIR, f"{safe_id}.png")

    # 1. CACHE KONTROLÜ
    if os.path.exists(image_path):
        print(f"♻️ Görsel cache'den alındı: {image_path}")
        return image_path
    
    print(f"🎨 Görsel Çiziliyor: '{prompt[:50]}...'")
    try:
        # Prompt zenginleştirme
        # Haberden gelen ana veriyi bir değişkene atayalım (Örn: Alım Bedeli)
    # Bu veriyi JSON'daki 'key_numbers' -> 'amount_raw' veya 'facts' kısmından çekebilirsiniz.


        enhanced_prompt = f"""
        Fotoğrafını üret: {prompt}.
        Görselin üzerine, minimal ve profesyonel bir finansal infografik tarzında, sadece şu iki bilgiyi içeren büyük ve dikkat çekici bir metin katmanı ekle:
        1. Ana Başlık: "{ana_mesaj}"
        2. Büyük Rakam: "{ana_rakam}"
        

        Kurallar:
        - Asla başka bir rakam, döviz kuru, hisse fiyatı, tarih veya büyüme oranı gibi veri EKLEME. Sadece yukarıda belirtilen başlık ve rakamı kullan.
        - Yüksek kontrastlı, mavi ve beyaz tonlarda, profesyonel bir kurumsal görsel olsun.
        - Asla meme, stok foto veya kalabalık metin kullanma. Yazılan her şey Türkçe olsun.
        - Büyük rakam "none" ise büyük rakam yazma.
        """
        # --- DÜZELTİLEN KISIM BURASI ---
        # Config parametresini sildik. Sadece model ve prompt yeterli.
        response = client.models.generate_content(
            model="gemini-3-pro-image-preview",  # veya "gemini-2.5-flash-image" (hangisi açıksa)
            contents=enhanced_prompt
        )

        # Yanıtı işle (Inline Data varsa resimdir)
        if response.parts:
            for part in response.parts:
                if part.inline_data:
                    # PIL ile resmi işle ve kaydet
                    image = part.as_image()
                    image.save(image_path)
                    print(f"✅ Görsel üretildi ve kaydedildi: {image_path}")
                    return image_path
        
        print("❌ Model metin döndü veya görsel üretemedi.")
        # Debug için ne döndüğünü görelim (belki 'Resim çizemem' demiştir)
        if response.text:
            print(f"Model Yanıtı: {response.text[:100]}...")
            
        return None

    except Exception as e:
        print(f"❌ Görsel Üretme Hatası: {e}")
        return None


from pymongo import MongoClient, DESCENDING
import os
import requests
from requests_oauthlib import OAuth1

# MongoDB Ayarları
MONGO_URI = os.environ.get("MONGO_URI", "mongodb://localhost:27017")
MONGO_DB = "kap_news"
NEWS_COLLECTION = "news_items"      # Haberlerin okunduğu yer
POSTED_COLLECTION = "posted_tweets" # Atılan tweetlerin loglandığı yer

def check_twitter_rate_limits():
    """Twitter API rate limitlerini kontrol eder ve reset zamanını döndürür."""
    try:
        auth = OAuth1(
            CONSUMER_KEY,
            CONSUMER_SECRET,
            ACCESS_TOKEN,
            ACCESS_TOKEN_SECRET
        )
        
        # Basit bir test request at (sadece header'ları almak için)
        url = "https://api.twitter.com/2/tweets"
        test_payload = {"text": "test"}
        response = requests.post(url, auth=auth, json=test_payload, headers={"Content-Type": "application/json"})
        
        # Header'lardan limit bilgilerini al
        remaining = int(response.headers.get('x-app-limit-24hour-remaining', -1))
        reset_timestamp = int(response.headers.get('x-app-limit-24hour-reset', 0))
        
        return {
            'remaining': remaining,
            'reset_timestamp': reset_timestamp,
            'is_limited': remaining == 0
        }
    except Exception as e:
        print(f"⚠️ Rate limit kontrolü yapılamadı: {e}")
        return {'remaining': -1, 'reset_timestamp': 0, 'is_limited': False}

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
    
    # Sadece unique_id alanlarını çekelim
    cursor = db[POSTED_COLLECTION].find({}, {"unique_id": 1, "_id": 0})
    return {doc["unique_id"] for doc in cursor if "unique_id" in doc}

def save_posted_tweet_mongo(tweet_data):
    """Atılan tweeti MongoDB'ye kaydeder."""
    db = get_mongo_db()
    if db is None: return
    
    try:
        tweet_data["created_at"] = datetime.now()
        db[POSTED_COLLECTION].insert_one(tweet_data)
        # print(f"✅ Tweet loglandı: {tweet_data.get('unique_id')}")
    except Exception as e:
        print(f"⚠️ Tweet loglama hatası: {e}")

def load_news_mongo():
    """MongoDB'den son 24 saatin haberlerini çeker (ya da son 100 haber)."""
    db = get_mongo_db()
    if db is None: return []

    # Son eklenenleri önce getir
    cursor = db[NEWS_COLLECTION].find().sort("_inserted_at", DESCENDING)
    return list(cursor)

# Eski dosya tabanlı fonksiyonları (load_posted_ids, save_posted_ids, load_news) siliyoruz 
# ya da wrapper olarak bırakabiliriz ama Mongo'ya geçiyoruz.
# İleriki adımlarda main fonksiyonunu bu yeni fonksiyonları kullanacak şekilde güncelleyeceğiz.

def format_tweet(item):
    """
    Öncelikli Tweet Formatlayıcı:
    1. Ana Metin + Link + Etiketler (Kesinlikle sığmalı)
    2. Editör Notu (SADECE yer kalırsa eklenir, yoksa atlanır)
    """
    tweet_data = item.get("tweet", {})
    notes = item.get("notes", {})
    
    # --- GİRDİLERİ AL ---
    base_text = tweet_data.get("text", "")
    if not base_text: base_text = f"🚨 #{item.get('ticker')}: {item.get('headline')}"

    editor_comment = notes.get("editor_comment")
    kap_url = item.get("url")
    hashtags = tweet_data.get("hashtags", [])

    # --- ADIM 1: ZORUNLU ALT KISMI (Footer) HAZIRLA VE ÖLÇ ---
    # Link, Uyarı ve Etiketler. Bunlar kesin olacak.
    footer_str = ""
    # Twitter'ın karakter sayma mantığına göre uzunluk hesabı:
    footer_twitter_len = 0 

    # Link (Her zaman ~23 karakter sayılır + başındaki \n\n için 2 karakter)
    if kap_url:
        footer_str += f"\n\n🔗 {kap_url}"
        footer_twitter_len += 2 + 23 

    # Yasal Uyarı (\n\n + ikon + boşluk + metin uzunluğu)

    # Hashtagler (\n\n + toplam metin uzunluğu)
    if hashtags:
        tags_str = " ".join(hashtags)
        footer_str += f"\n\n{tags_str}"
        footer_twitter_len += 2 + len(tags_str)

    # --- ADIM 2: ANA METNİ YERLEŞTİR ---
    # Senin dediğine göre ana metinler kısa ve hep sığıyor.
    # Yine de güvenlik için çok küçük bir ihtimal sığmazsa diye önlem alalım.
    
    MAX_LEN = 280
    BUFFER = 3 # Emojiler vs için güvenlik payı
    
    # Ana metin için mevcut alan = 280 - Footer - Tampon
    available_for_text = MAX_LEN - footer_twitter_len - BUFFER
    
    current_body = base_text
    # Eğer ana metin bile sığmıyorsa (çok nadir), mecburen onu kısalt.
    if len(current_body) > available_for_text:
        current_body = current_body[:available_for_text-3] + "..."

    # --- ADIM 3: EDİTÖR NOTUNU SIĞDIRMAYA ÇALIŞ ---
    # Şu anki toplam uzunluk nedir?
    current_total_len = len(current_body) + footer_twitter_len + BUFFER
    
    # Ne kadar boş yer kaldı?
    remaining_space = MAX_LEN - current_total_len
    
    if editor_comment and not notes.get("is_routine_spam"):
        # Notu eklersek formatı nasıl olacak? (\n\nℹ️ Not: ...)
        formatted_note = f"\n\nℹ️ Not: {editor_comment}"
        note_len = len(formatted_note)
        
        # KRİTİK KONTROL: Kalan boşluğa sığıyor mu?
        if note_len <= remaining_space:
            # SIĞIYOR! Gövdeye ekle.
            current_body += formatted_note
        else:
            # SIĞMIYOR! Hiç ekleme, pas geç.
            pass

    # --- SONUÇ ---
    final_tweet = current_body + footer_str
    return final_tweet

def get_today_str():
    return datetime.now().strftime("%Y-%m-%d")

def load_daily_state():
    if not os.path.exists(DAILY_STATE_FILE):
        return {"date": get_today_str(), "count": 0}
    try:
        with open(DAILY_STATE_FILE, "r", encoding="utf-8") as f:
            data = json.load(f)
            # Eğer tarih eskimişse sıfırla
            if data.get("date") != get_today_str():
                return {"date": get_today_str(), "count": 0}
            return data
    except:
        return {"date": get_today_str(), "count": 0}

def save_daily_state(state):
    with open(DAILY_STATE_FILE, "w", encoding="utf-8") as f:
        json.dump(state, f, indent=2)

def main():
    print("🤖 Twitter Bot (Google Vision Destekli) Başlatılıyor...")
    
    api_v1 = setup_twitter_api_v1()
    client_v2 = setup_twitter_client_v2()
    gemini_client = setup_gemini()

    if not api_v1 or not client_v2 or not gemini_client:
        print("API Bağlantı Hatası. Çıkılıyor.")
        return

    print(f"[INFO] MongoDB ({MONGO_DB}) izleniyor... Günlük Limit: KAPALI (Sınırsız)")
    posted_ids = load_posted_ids_mongo()

    while True:
        try:
            # İLK OLARAK: Twitter API limitini kontrol et
            rate_status = check_twitter_rate_limits()
            if rate_status['is_limited'] and rate_status['reset_timestamp'] > 0:
                reset_time = datetime.fromtimestamp(rate_status['reset_timestamp'])
                now = datetime.now()
                wait_seconds = (reset_time - now).total_seconds()
                
                if wait_seconds > 0:
                    print(f"⏰ Twitter API limiti dolmuş!")
                    print(f"   Reset zamanı: {reset_time.strftime('%H:%M:%S')}")
                    print(f"   Bekleme süresi: {int(wait_seconds/60)} dakika {int(wait_seconds%60)} saniye")
                    print(f"💤 Reset zamanına kadar bekleniyor...")
                    time.sleep(wait_seconds + 10)  # +10 saniye güvenlik payı
                    print(f"✅ Reset zamanı geldi! Tweet atmaya devam ediliyor...")
            
            news_items = load_news_mongo()
            print(f"🔍 MongoDB'den {len(news_items)} haber çekildi")
            # daily_state = load_daily_state()  # DEVRE DIŞI
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
                    # DB'ye "SKIPPED" olarak da kaydedebiliriz ama şimdilik sadece sete ekleyip geçiyoruz
                    posted_ids.add(unique_id)
                    skipped_web_only += 1
                    continue

                # --- 1. KURAL: ESKİ TARİHLİ HABERLERİ ELE ---
                published_at_raw = item.get("published_at")
                if isinstance(published_at_raw, dict):
                    item_date = published_at_raw.get("date")
                else:
                    # String ise veya başka formatta ise parse etmeye çalış ya da bugünü al
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
                
                # --- 2. KURAL: GÜNLÜK LİMİT KONTROLÜ --- (DEVRE DIŞI)
                # Günlük limit kontrolü kaldırıldı, sınırsız tweet atılacak
                
                print(f"✅ Queue'ya ekleniyor: {item.get('primary_ticker')} - {item.get('headline')[:50]}")
                queue.append((unique_id, item))
            
            print(f"📊 Filtreleme Özeti: Zaten atılmış={skipped_already_posted}, WEB_ONLY={skipped_web_only}, Eski={skipped_old}, Queue={len(queue)}")

            if queue:
                print(f"[INFO] {len(queue)} adet yeni flaş haber var.")

            for unique_id, item in queue:
                # Limit kontrolü kaldırıldı
                pass

                text = format_tweet(item)
                visual_prompt = item.get("visual_prompt")
                ana_mesaj = item.get("headline")
                key_numbers = item.get("key_numbers", {})
                ana_rakam = key_numbers.get("amount_raw")
                media_id = None

                # 1. GÖRSEL ÜRETİMİ
                if visual_prompt:
                    image_path = generate_gemini_image(gemini_client, visual_prompt, ana_mesaj, ana_rakam, unique_id)
                    
                    if image_path:
                        try:
                            media = api_v1.media_upload(filename=image_path)
                            media_id = media.media_id
                            print(f"✅ Görsel Twitter'a yüklendi (ID: {media_id})")
                        except Exception as e:
                            print(f"⚠️ Görsel yükleme hatası: {e}")
                            media_id = None

                # 2. TWEETİ AT
                print(f"🐦 Tweet Atılıyor: {item.get('primary_ticker')}...")
                try:
                    tweet_response = None
                    if media_id:
                        tweet_response = client_v2.create_tweet(text=text, media_ids=[media_id])
                    else:
                        tweet_response = client_v2.create_tweet(text=text)
                    
                    tweet_id = tweet_response.data['id']
                    print(f"🚀 GÖNDERİLDİ! Tweet ID: {tweet_id}")
                    
                    # Limit devre dışı - sayaç yok

                    posted_ids.add(unique_id)
                    
                    # MongoDB'ye Logla
                    save_posted_tweet_mongo({
                        "unique_id": unique_id,
                        "tweet_id": tweet_id,
                        "status": "SENT",
                        "headline": ana_mesaj,
                        "ticker": item.get("primary_ticker"),
                        "text": text
                    })
                    
                except Exception as e:
                    print(f"❌ Tweet Hatası: {e}")
                    print(f"🔍 Hata Tipi: {type(e).__name__}")
                    print(f"🔍 Hata Detayı: {str(e)}")
                    
                    # Eğer tweepy exception ise daha fazla bilgi al
                    if hasattr(e, 'response'):
                        print(f"🔍 API Response Status: {e.response.status_code if hasattr(e.response, 'status_code') else 'N/A'}")
                        print(f"🔍 API Response Text: {e.response.text if hasattr(e.response, 'text') else 'N/A'}")
                    
                    # ÖNEMLİ: 429 hatası alındığında akıllıca bekle
                    if "429" in str(e) or "Too Many Requests" in str(e):
                        print("⚠️ RATE LIMIT! Tweet atılamadı.")
                        
                        # API'den reset zamanını al ve ona göre bekle
                        if hasattr(e, 'response') and hasattr(e.response, 'headers'):
                            reset_timestamp = int(e.response.headers.get('x-app-limit-24hour-reset', 0))
                            if reset_timestamp > 0:
                                reset_time = datetime.fromtimestamp(reset_timestamp)
                                now = datetime.now()
                                wait_seconds = (reset_time - now).total_seconds()
                                
                                if wait_seconds > 0:
                                    print(f"⏰ Reset zamanı: {reset_time.strftime('%Y-%m-%d %H:%M:%S')}")
                                    print(f"⏳ {int(wait_seconds/3600)}sa {int((wait_seconds%3600)/60)}dk sonra tekrar denenecek")
                                    print(f"💤 Beklemeye geçiliyor...")
                                    time.sleep(wait_seconds + 10)  # +10 saniye güvenlik
                                    print(f"✅ Reset zamanı geldi! Devam ediliyor...")
                                    # Döngüyü kır, yeni cycle'da bu haber tekrar denenecek
                                    break
                        
                        # Eğer reset zamanı bulunamazsa, queue'yu temizle ve bekle
                        print("📋 Queue temizleniyor, sonraki cycle bekleniyor...")
                        break
            
            # MongoDB kullandığımız için toplu save_posted_ids yapmaya gerek yok, 
            # save_posted_tweet_mongo ile her işlem anlık loglanıyor.
            
            bekleme_suresi = random.randint(60, 90)
            print(f"⏸️ {bekleme_suresi} saniye sonra tekrar kontrol edilecek...")
            time.sleep(bekleme_suresi)

        except KeyboardInterrupt:
            break
        except Exception as e:
            print(f"[CRITICAL] Döngü hatası: {e}")
            time.sleep(60)

if __name__ == "__main__":
    main()