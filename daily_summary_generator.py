#!/usr/bin/env python3
"""
Borsa İstanbul Günlük Özet Generator
====================================
Bu script günlük piyasa özetini LLM ile oluşturup news_items koleksiyonuna kaydeder.

Çalışma mantığı:
1. prices koleksiyonundan fiyat verilerini çeker
2. Değerli hisseler arasından top 3 yükselen/düşen belirler
3. Spike (volatilite patlaması) tespiti yapar
4. O günkü yüksek newsworthiness haberlerini çeker
5. Gemini LLM ile profesyonel özet oluşturur
6. news_items formatında MongoDB'ye kaydeder

Kullanım:
    python daily_summary_generator.py

Cron Job (hafta içi 18:30):
    30 18 * * 1-5 /root/kap_haber/venv/bin/python /root/kap_haber/daily_summary_generator.py
"""

import os
import json
from datetime import datetime
from statistics import median
from typing import Dict, Any, List, Optional
from dotenv import load_dotenv
from pymongo import MongoClient
from google import genai
from google.genai import types


# Load environment variables
load_dotenv()

# Configuration
MONGO_URI = os.environ.get("MONGO_URI", "mongodb://localhost:27017")
MONGO_DB = os.environ.get("MONGO_DB", "kap_news")
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
TELEGRAM_BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN")
TELEGRAM_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID")

# Minimum market value for "valuable" stocks (1 billion TL)
MIN_MARKET_VALUE = 1_000_000_000

# Minimum turnover for liquidity (50 million TL)
MIN_TURNOVER = 50_000_000

# Minimum absolute change to filter noise (1%)
MIN_ABS_CHANGE = 1.0

# Minimum newsworthiness for important news
MIN_NEWSWORTHINESS = 0.6


def get_mongo_client():
    """MongoDB bağlantısı oluştur"""
    return MongoClient(MONGO_URI)


def get_prices_data(db) -> List[Dict[str, Any]]:
    """prices koleksiyonundan tüm fiyat verilerini çek"""
    prices_col = db["prices"]
    return list(prices_col.find({}))


def filter_valuable_stocks(prices: List[Dict]) -> List[Dict]:
    """Düşük değerli ve düşük hacimli hisseleri filtrele"""
    valuable = []
    for p in prices:
        # Prices yapısı: veriler root'ta, ticker = Code
        market_value = p.get("MarketValue", 0) or 0
        # MarketValue bazen dict olabilir (MongoDB $numberLong)
        if isinstance(market_value, dict):
            market_value = int(market_value.get("$numberLong", 0))
        
        last_price = p.get("Last", 0) or 0
        daily_change = p.get("DailyChangePercent", 0) or 0
        ticker = p.get("Code", "")
        total_turnover = p.get("TotalTurnover", 0) or 0
        volatility = p.get("Volatility", 0) or 0
        free_float = p.get("FreeFloatRate", 50) or 50
        
        # Kalite filtreleri:
        # 1. Minimum piyasa değeri (1 milyar TL)
        # 2. Minimum hacim (50 milyon TL)
        # 3. Minimum değişim (%1 en az)
        if (
            market_value >= MIN_MARKET_VALUE
            and total_turnover >= MIN_TURNOVER
            and abs(daily_change) >= MIN_ABS_CHANGE
            and last_price > 0
            and ticker
        ):
            valuable.append({
                "ticker": ticker,
                "price": last_price,
                "change": daily_change,
                "market_value": market_value,
                "volume": total_turnover,
                "volatility": volatility,
                "free_float": free_float
            })
    return valuable


# ============================================================================
# SPIKE DETECTION SYSTEM
# ============================================================================

def detect_spike(stock: Dict[str, Any], has_news: bool = False) -> Dict[str, Any]:
    daily_change = abs(stock.get("change", 0))
    volatility = stock.get("volatility", 0) or 0
    volume = stock.get("volume", 0) or 0
    market_value = stock.get("market_value", 1) or 1

    # Devir Hızı (Turnover)
    volume_mv_ratio = (volume / market_value) * 100 if market_value > 0 else 0

    label = "NORMAL"
    reason = "-"  # Prompt'un hata vermemesi için boş da olsa string lazım
    score = 0.0

    # KURAL 1: Tavan/Taban'a yakın hareket (%9.5+)
    if daily_change >= 9.5:
        label = "YUKSEK_VOLATILITE"
        score = 10.0
        reason = "Tavan/Taban Hareketi"
        
    # KURAL 2: Sert Fiyat (%6+) VE Yüksek Hacim (%5+)
    # Günlük işlem, piyasa değerinin %5'ini aşmış (çok yüksek devir)
    elif daily_change >= 6.0 and volume_mv_ratio >= 5.0:
        label = "YUKSEK_VOLATILITE"
        score = 8.0
        reason = "Sert Fiyat ve Yüksek Giriş/Çıkış"

    # KURAL 3: Haber Yokken Anormal Hacim (%15+)
    # Fiyat çok oynamasa bile tahtanın %15'i el değiştirmiş (olağanüstü)
    elif volume_mv_ratio >= 15.0 and not has_news:
        label = "ORTA_VOLATILITE"
        score = 6.0
        reason = "Olağanüstü Hacim (Habersiz)"
        
    # KURAL 4 KALDIRILDI: Sadece %5 hareket spike değildir, borsada olağandır.

    return {
        "spike_score": score,
        "spike_label": label,
        "spike_reason": reason, # ARTIK BU KEY VAR, PROMPT PATLAMAZ
        "volume_ratio": round(volume_mv_ratio, 2),
        "volatility_ratio": round(volatility, 2),
        "change_pct": round(daily_change, 2)
    }



def get_top_movers(valuable_stocks: List[Dict], top_n: int = 3):
    """En çok yükselen ve düşen hisseleri bul"""
    # Spike olanları hariç tut (Prompt'ta tekrar etmemesi için)
    
    gainers = sorted(
        [s for s in valuable_stocks if s["change"] > 0 and not s.get("is_spike")],
        key=lambda x: x["change"],
        reverse=True
    )[:top_n]
    
    losers = sorted(
        [s for s in valuable_stocks if s["change"] < 0 and not s.get("is_spike")],
        key=lambda x: x["change"]
    )[:top_n]


    return gainers, losers


def get_todays_important_news(db, today_date: str) -> List[Dict]:
    """Bugünün yüksek newsworthiness haberlerini çek"""
    news_col = db["news_items"]
    
    query = {
        "published_at.date": today_date,
        "newsworthiness": {"$gte": MIN_NEWSWORTHINESS},
        "topic": {"$ne": "GUNLUK_PIYASA_OZETI"}  # Önceki özetleri dahil etme
    }
    
    news = list(news_col.find(query).sort("newsworthiness", -1).limit(10))
    
    return [{
        "ticker": n.get("primary_ticker", ""),
        "headline": n.get("headline", ""),
        "category": n.get("category", ""),
        "newsworthiness": n.get("newsworthiness", 0),
        "summary": n.get("seo", {}).get("meta_description", "")[:200] if n.get("seo") else ""
    } for n in news]


# Index name mapping for Turkish display
INDEX_NAMES = {
    "XU100": "BIST 100",
    "XAUTRY": "Altın",
    "XAGTRY": "Gümüş",
    "USDTRY": "Dolar",
    "EURTRY": "Euro",
    "GBPTRY": "Sterlin",
    "GAUTRY": "Gram Altın",
    "BRENT:CFD": "Brent Petrol",
    "CRUDEOIL:CFD": "WTI Petrol",
    "BTCUSD": "Bitcoin",
    "NATURALGAS:CFD": "Doğalgaz",
    "SG14BIL": "Tahvil"
}


def get_indices_data(db) -> List[Dict]:
    """indices koleksiyonundan endeks verilerini çek"""
    indices_col = db["indices"]
    
    indices = list(indices_col.find({}))
    
    result = []
    for idx in indices:
        code = idx.get("Code", "")
        if code:
            result.append({
                "code": code,
                "name": INDEX_NAMES.get(code, code),
                "last": idx.get("Last", 0),
                "change": idx.get("DailyChangePercent", 0),
                "weekly_change": idx.get("WeeklyChangePercent", 0)
            })
    
    return result



def format_number_turkish(value: float) -> str:
    """Sayıları Türkçe formatta formatla"""
    if value >= 1e12:
        return f"{value/1e12:.2f} Trilyon ₺"
    if value >= 1e9:
        return f"{value/1e9:.2f} Milyar ₺"
    if value >= 1e6:
        return f"{value/1e6:.2f} Milyon ₺"
    return f"{value:,.0f} ₺"


def build_llm_prompt(gainers: List[Dict], losers: List[Dict], news: List[Dict], indices: List[Dict], spike_stocks: List[Dict], today_date: str) -> str:
    """LLM için prompt oluştur"""
    
    gainers_text = "\n".join([
        f"- {g['ticker']}: ₺{g['price']:.2f} (+{g['change']:.2f}%)"
        for g in gainers
    ]) if gainers else "- Bugün öne çıkan yükselen hisse yok"

    
    losers_text = "\n".join([
        f"- {l['ticker']}: ₺{l['price']:.2f} ({l['change']:.2f}%)"
        for l in losers
    ]) if losers else "- Bugün öne çıkan düşen hisse yok"
    
    # Haberleri daha detaylı formatla
    news_text = "\n".join([
        f"- **{n['ticker']}** ({n['category']}): {n['headline']}\n  Özet: {n['summary']}" if n['summary'] else f"- **{n['ticker']}** ({n['category']}): {n['headline']}"
        for n in news
    ]) if news else "- Bugün önemli KAP haberi yok"
    
    # Önemli endeksler - sadece gerekli olanlar
    # Ana endeks: XU100
    # Kurlar: USDTRY, EURTRY
    # Faiz algısı: SG14BIL (14 yıl vadeli tahvil)
    # Altın: XAUTRY
    core_indices = ["XU100", "USDTRY", "EURTRY", "SG14BIL", "XAUTRY"]
    
    # Enerji haberi var mı kontrol et (Brent için)
    energy_tickers = ["TUPRS", "PETKM", "AYGAZ", "IPEKE", "AKSEN", "ODAS", "ENERY"]
    has_energy_news = any(
        n["ticker"] in energy_tickers or "enerji" in n.get("headline", "").lower() or "petrol" in n.get("headline", "").lower()
        for n in news
    )
    
    if has_energy_news:
        core_indices.append("BRENT:CFD")
    
    indices_text_lines = []
    for idx in indices:
        if idx["code"] in core_indices:
            change_sign = "+" if idx["change"] > 0 else ""
            # Format based on index type
            if idx["code"] == "XU100":
                indices_text_lines.insert(0, f"- **BIST 100**: {idx['last']:,.2f} puan ({change_sign}{idx['change']:.2f}%)")
            elif idx["code"] == "USDTRY":
                indices_text_lines.append(f"- Dolar/TL: {idx['last']:.4f} ({change_sign}{idx['change']:.2f}%)")
            elif idx["code"] == "EURTRY":
                indices_text_lines.append(f"- Euro/TL: {idx['last']:.4f} ({change_sign}{idx['change']:.2f}%)")
            elif idx["code"] == "SG14BIL":
                indices_text_lines.append(f"- Tahvil (14Y): {idx['last']:,.2f} ({change_sign}{idx['change']:.2f}%)")
            elif idx["code"] == "XAUTRY":
                indices_text_lines.append(f"- Altın (TL/Ons): {idx['last']:,.2f} ({change_sign}{idx['change']:.2f}%)")
            elif idx["code"] == "BRENT:CFD":
                indices_text_lines.append(f"- Brent Petrol: ${idx['last']:.2f} ({change_sign}{idx['change']:.2f}%)")
    
    indices_text = "\n".join(indices_text_lines) if indices_text_lines else "- Endeks verisi yok"

    # Spike (volatil hareket) metni oluştur
    spike_text = "\n".join([
        f"- **{s['ticker']}**: %{s['change']:.2f} | "
        f"Sebep: {s['spike']['spike_reason']} | "  # Burası artık çalışır
        f"Hacim x{s['spike']['volume_ratio']} | "
        f"→ {s['spike']['spike_label']} "
        for s in spike_stocks[:5]
    ]) if spike_stocks else "- Bugün anormal volatilite tespit edilmedi"
    
    prompt = f"""Sen profesyonel bir borsa editörüsün ve KAP Haber sitesi için günlük piyasa özeti yazıyorsun.
    Aşağıdaki piyasa verilerini kullanarak kapsamlı bir "Borsa İstanbul Günlük Özeti" yaz.

    ## Tarih: {today_date}

    ## ENDEKSLER VE DÖVİZ (ÇOK ÖNEMLİ - MUTLAKA KULLAN):
    {indices_text}

    ## EN ÇOK YÜKSELEN 3 HİSSE:
    {gainers_text}

    ## EN ÇOK DÜŞEN 3 HİSSE:
    {losers_text}

    ## DİKKAT ÇEKEN VOLATİL HAREKETLER (Spike):
    {spike_text}

    ⚠️ Bu hisseler yüksek volatilite nedeniyle öne çıkmıştır.
    Bu durum fiyat hareketine dayalıdır, olumlu veya olumsuz olarak yorumlanmamalıdır.

    ## GÜNÜN ÖNEMLİ KAP HABERLERİ (Detaylı):
    {news_text}

    Aşağıda verilen VERİLER DIŞINDA hiçbir bilgi kullanma.


    ⚠️ ÖNEMLİ KURALLAR (ÇOK KRİTİK):
    - Verilmeyen hiçbir veri hakkında tahmin yürütme
    - Yukarıda verilen endeks ve döviz verilerini MUTLAKA "Piyasa Genel Görünümü" bölümünde kullan
    - BIST 100, Dolar, Euro, Altın değerlerini özette belirt
    - Spekülasyon yapma, sadece verilen fiyat hareketleri ve KAP haberlerine dayan
    - Nedensellik kurarken yalnızca sağlanan haberleri referans al

    Markdown formatında yaz.
    Başlıkları ve vurguları düzgün kullan.

    ---

    ## YAZIM KURALLARI:
    1. Profesyonel, akıcı Türkçe kullan
    2. Markdown formatında yaz (## başlıklar, **kalın** vurgular, madde işaretleri)
    3. Aşağıdaki bölümleri MUTLAKA içer ve her bölümü detaylı yaz:

    ### ## Piyasa Genel Görünümü
    - 3-4 cümle ile günün genel havasını özetle
    - Endeksin genel yönü hakkında yorum yap
    - Yatırımcı davranışını fiyat hareketlerine dayanarak değerlendir
    - Veri olmayan konularda genelleme yapma

    ### ## Günün Yıldızları
    - Her yükselen hisse için 2-3 cümle yaz
    - Fiyat hareketini net şekilde belirt
    - Eğer ilgili bir KAP haberi varsa ilişkilendir
    - Haber yoksa “haber akışı sınırlı” gibi nötr ifade kullan
    - Her hisseyi **TICKER** formatında yaz

    ### ## Baskı Altındaki Hisseler
    - Her düşen hisse için 2-3 cümle yaz
    - Düşüşü fiyat verisiyle açıkla
    - İlgili KAP haberi varsa mutlaka bağ kur
    - Yoksa düşüşün veri bazlı olduğunu belirt
    - Her hisseyi **TICKER** formatında yaz

    ### ## Gündem ve Gelişmeler (ÇOK ÖNEMLİ - DETAYLI YAZ)
    - Yukarıda verilen KAP haberlerinin TAMAMINI işle
    - Haberleri mantıklı kategorilere ayır:
    (Finansal Sonuçlar, Sözleşmeler, Yatırımlar, Borçlanma, Diğer)
    - Her haber için 2-3 cümle yaz
    - Haberlerin piyasa üzerindeki olası etkisini
    sadece fiyat ve haber içeriğine dayanarak değerlendir
    - Madde işaretleri veya alt başlıklar kullan
    - BU BÖLÜM EN AZ 150 KELİME OLSUN
    - Hiçbir haberi atlama

    ### ## Yatırımcı Notu
    - 2-3 cümle ile günün genel özetini yap
    - Kısa ve net çıkarımlar sun
    - Yatırım tavsiyesi verme
    - Risk ve volatilite vurgusu yapabilirsin

    4. Her hisse için ticker kodunu **TICKER** formatında yaz
    5. Toplam 600-800 kelime arası yaz
    (İçerik yetersizse gereksiz tekrar veya laf kalabalığı yapma)
    6. Spekülasyon yapma, sadece verilere dayalı yorumla
    7. Haberleri ASLA es geçme, hepsini değerlendir


    ---

    Aşağıdaki verileri kullanarak
    **“Borsa İstanbul Günlük Özeti”** başlıklı kapsamlı analizi yaz.

    Şimdi özeti yaz:
    """

    return prompt



def generate_summary_with_llm(prompt: str) -> Optional[str]:
    """Gemini LLM ile özet oluştur"""
    if not GEMINI_API_KEY:
        print("[ERROR] GEMINI_API_KEY not set")
        return None
    
    try:
        client = genai.Client(api_key=GEMINI_API_KEY)
        
        response = client.models.generate_content(
            model="gemini-3-flash-preview",
            contents=prompt,
            config=types.GenerateContentConfig(
                temperature=0.7,
                max_output_tokens=5000,
            )
        )
        
        if response and response.text:
            return response.text.strip()
        return None
        
    except Exception as e:
        print(f"[ERROR] LLM generation failed: {e}")
        return None


from bson import ObjectId

def create_news_item(
    summary_md: str,
    gainers: List[Dict],
    losers: List[Dict],
    spike_stocks: List[Dict],
    today_date: str
) -> Dict[str, Any]:
    """news_items formatında döküman oluştur"""
    
    # Pre-generate ID for URL
    doc_id = ObjectId()
    
    # İlgili tickerları birleştir
    related_tickers = (
    [g["ticker"] for g in gainers] +
    [l["ticker"] for l in losers] 
    )

    
    # Şu anki saat
    now = datetime.now() # Use now() instead of fixed date if possible, but keep consistent
    time_str = now.strftime("%H:%M")
    
    today_dt = datetime.strptime(today_date, "%Y-%m-%d")
    
    # Türkçe Ay İsimleri (locale güvenilmez sunucuda)
    months_tr = {
        1: "Ocak", 2: "Şubat", 3: "Mart", 4: "Nisan", 5: "Mayıs", 6: "Haziran",
        7: "Temmuz", 8: "Ağustos", 9: "Eylül", 10: "Ekim", 11: "Kasım", 12: "Aralık"
    }
    date_formatted = f"{today_dt.day} {months_tr[today_dt.month]} {today_dt.year}"
    
    # Headline Formatı: "Borsa İstanbul Günlük Özeti: 11 Ocak 2026"
    headline = f"Borsa İstanbul Günlük Özeti: {date_formatted}"
    
    # Meta description (Headline'dan farklı, içerik özeti olsun)
    # Markdown temizle (# ve * gibi karakterler)
    clean_summary = summary_md.replace("#", "").replace("**", "").replace("- ", "").replace("\n\n", " ").strip()
    # İlk 155 karakteri al (SEO için ideal uzunluk)
    if len(clean_summary) > 155:
        meta_desc = clean_summary[:152] + "..."
    else:
        meta_desc = clean_summary



    # İlgi çekici Tweet Metni
    # Emoji ve merak uyandırıcı dil
    tweet_lines = [f"🚨 Borsa Günü Tamamladı! ({date_formatted})"]

    tweet_lines.append("")
    
    if gainers:
        top3_g = [g['ticker'] for g in gainers[:3]]
        tweet_lines.append(f"🚀 Piyasayı Sırtlayanlar: {', '.join(top3_g)}")
    
    if spike_stocks:
        tweet_lines.append(f"⚡️ Dikkat Çeken Hareketler: {spike_stocks[0]['ticker']} ve dahası...")
    elif losers:
         top3_l = [l['ticker'] for l in losers[:3]]
         tweet_lines.append(f"🔻 Kar Satışı Yiyenler: {', '.join(top3_l)}")
         
    tweet_lines.append("")
    tweet_lines.append("Günün kazananları, kaybedenleri ve kritik detaylar analizde! 👇")
    # Link artık url alanında gönderiliyor, metne eklenmiyor.
    
    tweet_text = "\n".join(tweet_lines)
    
    news_item = {
        "_id": doc_id,
        "primary_ticker": "BIST",
        "publisher_ticker": "BIST",
        "related_tickers": related_tickers,
        "published_at": {
            "date": today_date,
            "time": time_str,
            "timezone": "Europe/Istanbul"
        },
        "topic": "GUNLUK_PIYASA_OZETI",
        "subtype": "AI_OZET",
        "category": "Piyasa Özeti",
        "newsworthiness": 0.99,
        "key_numbers": {
            "amount_raw": None,
            "ratio_to_market_cap": None,
            "ratio_to_revenue": None
        },
        "headline": headline,
        "facts": [
            {"k": "En Çok Yükselen", "v": gainers[0]["ticker"] if gainers else "-"},
            {"k": "En Çok Düşen", "v": losers[0]["ticker"] if losers else "-"},
            {"k": "Özet Tarihi", "v": today_date}
        ],
        "tweet": {
            "text": tweet_text,
            "hashtags": ["#BIST100", "#Borsa", "#Hisse", "#Yatırım", "#Ekonomi"] + [f"#{t}" for t in related_tickers[:3]],
            "disclaimer": "YTD"
        },
        "seo": {
            "title": f"Borsa İstanbul Günlük Özet | {date_formatted}",
            "meta_description": meta_desc,
            "article_md": summary_md
        },
        "visual_prompt": "Professional stock market dashboard with green and red charts, Istanbul skyline background, financial data visualization, 4k cinematic.",
        "publish_target": "ALL_CHANNELS",
        "notes": {
            "is_routine_spam": False,
            "editor_comment": "Otomatik oluşturulan günlük piyasa özeti."
        },

        "_source_file": "daily_summary_generator.py",
        "_generated_at": now.isoformat(),
        "url": f"https://kaphaber.com/news/{doc_id}",
        "ticker": "BIST",
        "imageUrl": "/banners/piyasa.jpg"
    }
    
    return news_item


def save_to_mongodb(db, news_item: Dict) -> str:
    """news_items koleksiyonuna kaydet"""
    news_col = db["news_items"]
    
    # Aynı gün için özet var mı kontrol et
    # Eğer varsa, ID'yi koruyarak güncellememiz lazım ama URL değişecek mi?
    # Kullanıcı her gün 1 tane olsun ister muhtemelen url sabit kalsın
    
    existing = news_col.find_one({
        "topic": "GUNLUK_PIYASA_OZETI",
        "published_at.date": news_item["published_at"]["date"]
    })
    
    if existing:
        # Mevcut ID'yi koru, URL'deki ID değişmesin diye
        # Ancak tweet içindeki ID yeni ID ile oluşturuldu.
        # Bu durumda tweet'teki linki eski ID ile güncellememiz lazım.
        old_id = existing["_id"]
        
        # Tweet text'indeki yeni ID'yi eski ID ile değiştir
        new_id_str = str(news_item["_id"])
        old_id_str = str(old_id)
        news_item["tweet"]["text"] = news_item["tweet"]["text"].replace(new_id_str, old_id_str)
        
        # _id alanını kaldır (update işleminde _id değiştirilemez)
        del news_item["_id"]
        
        news_col.update_one(
            {"_id": old_id},
            {"$set": news_item}
        )
        print(f"[INFO] Existing summary updated for {news_item['published_at']['date']}")
        return str(old_id)
    else:
        # Yeni ekle (_id zaten item içinde var)
        result = news_col.insert_one(news_item)
        print(f"[INFO] New summary created with ID: {result.inserted_id}")
        return str(result.inserted_id)


def send_telegram_notification(message: str):
    """Telegram bildirimi gönder (opsiyonel)"""
    if not TELEGRAM_BOT_TOKEN or not TELEGRAM_CHAT_ID:
        return
    
    try:
        import requests
        url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
        requests.post(url, data={
            "chat_id": TELEGRAM_CHAT_ID,
            "text": message,
            "parse_mode": "HTML"
        }, timeout=10)
    except Exception as e:
        print(f"[WARN] Telegram notification failed: {e}")


def main():
    print("=" * 60)
    print("BORSA İSTANBUL GÜNLÜK ÖZET GENERATOR")
    print("=" * 60)
    
    today_date = datetime.now().strftime("%Y-%m-%d")
    # Test için manuel tarih gerekirse:
    # today_date = "2026-01-09"
    
    print(f"[INFO] Generating summary for: {today_date}")
    
    # MongoDB bağlantısı
    client = get_mongo_client()
    db = client[MONGO_DB]
    
    try:
        # 1. Fiyat verilerini çek
        print("[INFO] Fetching price data...")
        prices = get_prices_data(db)
        print(f"[INFO] Found {len(prices)} stocks")
        
        # 2. Değerli hisseleri filtrele
        valuable = filter_valuable_stocks(prices)
        print(f"[INFO] {len(valuable)} valuable stocks (MV > 1B TL)")
        
        # 3. Günün önemli haberlerini çek (Spike için gerekli)
        print("[INFO] Fetching today's important news...")
        important_news = get_todays_important_news(db, today_date)
        print(f"[INFO] Found {len(important_news)} important news items")

        # 4. Spike (volatilite patlaması) tespiti ve işaretleme
        print("[INFO] Detecting spike movements...")
        spike_stocks = []
        for stock in valuable:
            # Haber var mı kontrol et
            has_news = any(
                n["ticker"] == stock["ticker"]
                for n in important_news
            )
            
            # Spike tespiti
            spike = detect_spike(stock, has_news)
            spike["has_news"] = has_news
            
            stock["spike"] = spike
            # is_spike işaretlemesi burada yapılıyor
            stock["is_spike"] = spike["spike_label"] != "NORMAL"

            if stock["is_spike"]:
                spike_stocks.append(stock)
        
        # Spike skoruna göre sırala
        spike_stocks.sort(key=lambda x: x["spike"]["spike_score"], reverse=True)
        print(f"[INFO] Found {len(spike_stocks)} spike stocks")

        # 5. Top movers bul (Spike olanlar hariç - is_spike kullanılarak)
        gainers, losers = get_top_movers(valuable, top_n=3)
        print(f"[INFO] Top gainers: {[g['ticker'] for g in gainers]}")
        print(f"[INFO] Top losers: {[l['ticker'] for l in losers]}")
        
        # 6. Endeks verilerini çek
        print("[INFO] Fetching indices data...")
        indices = get_indices_data(db)
        print(f"[INFO] Found {len(indices)} indices")
        
        # 7. LLM prompt oluştur ve özet üret
        print("[INFO] Generating summary with LLM...")
        prompt = build_llm_prompt(gainers, losers, important_news, indices, spike_stocks, today_date)
        summary_md = generate_summary_with_llm(prompt)

        if not summary_md:
            print("[ERROR] Failed to generate summary")
            return
        
        print("[INFO] Summary generated successfully!")
        print("-" * 40)
        print(summary_md[:500] + "..." if len(summary_md) > 500 else summary_md)
        print("-" * 40)
        
        # 8. news_items formatına dönüştür ve kaydet
        print("[INFO] Saving to MongoDB...")
        news_item = create_news_item(summary_md, gainers, losers, spike_stocks, today_date)
        doc_id = save_to_mongodb(db, news_item)
        
        print(f"[SUCCESS] Daily summary saved! ID: {doc_id}")
        
        # 9. Telegram bildirimi (opsiyonel)
        send_telegram_notification(
            f"📊 <b>Günlük Özet Oluşturuldu</b>\n\n"
            f"📅 Tarih: {today_date}\n"
            f"📈 Yükselenler: {', '.join([g['ticker'] for g in gainers])}\n"
            f"📉 Düşenler: {', '.join([l['ticker'] for l in losers])}\n\n"
            f"🔗 kaphaber.com'da yayında!"
        )
        
    except Exception as e:
        print(f"[ERROR] {e}")
        import traceback
        traceback.print_exc()
    finally:
        client.close()


if __name__ == "__main__":
    main()
