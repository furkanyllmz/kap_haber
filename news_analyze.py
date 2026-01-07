# news_engine.py
# KAP gemini JSON -> LLM tabanlı Haber JSON üretir (financials + memory context dahil)
# FIX: Kesin yazma (absolute path + jsonl append + atomic json update + debug)

import os
import json
import glob
import time
from datetime import datetime
import re
from dotenv import load_dotenv
from pymongo import MongoClient
from pymongo.errors import ConnectionFailure

import google.generativeai as genai
from google.generativeai import types

# Hafıza modülleri
from chroma_kap_memory import load_embedder, KapMemory, handle_new_kap, store_kap

load_dotenv()

# ======================
# CONFIG
# ======================
API_KEY = os.environ.get("GEMINI_API_KEY")

DATA_DIR = "./daily_data_kap/gemini"
FIN_DIR = "./daily_data_kap/financials"

OUT_DIR = "./news"  # senin istediğin gibi
OUTPUT_FILE = os.path.join(OUT_DIR, "news_items.json")
OUTPUT_JSONL = os.path.join(OUT_DIR, "news_items.jsonl")
PROCESSED_TRACKER_FILE = os.path.join(OUT_DIR, "processed_news_files.json")

MODEL_NAME = "gemini-3-flash-preview"

# Memory settings
USE_MEMORY = True
MEMORY_DIR = "./chroma_kap_memory"
MEMORY_COLLECTION = "kap_memory"
MEMORY_TOPK = 4

# Rate limit / loop
SLEEP_NO_NEW = 10
SLEEP_BETWEEN_FILES = 2

# Write / filter
MIN_NEWS_SCORE = 0.25

# MongoDB settings
MONGO_URI = os.environ.get("MONGO_URI", "mongodb://localhost:27017")
MONGO_DB = "kap_news"
MONGO_COLLECTION = "news_items"


# ======================
# SYSTEM PROMPT (GAZETECİ MODU)
# ======================
NEWS_SYSTEM_PROMPT = r"""
Sen "KAP Haber Merkezi"nin Baş Editörüsün.
Görevin: Verilen NEW_KAP metnini, FINANCIALS_JSON ve HISTORY_CONTEXT ile analiz edip;
Doğru Ticker'ı tespit etmek, Haberi Sınıflandırmak ve Spam'i Önlemektir.

--- 1. TICKER TESPİT KURALLARI (ÇOK ÖNEMLİ) ---
KAP bildirimini gönderen kurum (Publisher) ile haberin konusu olan şirket (Subject) farklı olabilir.
- **publisher_ticker**: Bildirimi gönderen kurumun kodu (Örn: BMK, ALNUS, ISMEN, YKBNK).
- **primary_ticker**: Haberin ASIL konusu olan şirketin kodu (Örn: KONTR, MEYSU, ASELS).
- **related_tickers**: Haberde adı geçen diğer tüm borsa kodları.

Senaryo Örnekleri:
- BMK (Bizim Menkul) bildirimi, metin "KONTR rüçhan hakları..." diyorsa -> primary_ticker: "KONTR", publisher_ticker: "BMK".
- MEYSU Gıda halka arzını ALNUS (Alnus Yatırım) bildiriyorsa -> primary_ticker: "MEYSU", publisher_ticker: "ALNUS".
- Şirket (ASELS) kendi bildirimini atıyorsa -> primary_ticker: "ASELS", publisher_ticker: "ASELS".
- Eğer primary_ticker BIST'te işlem görmüyorsa veya emin değilsen null bırak.

--- 2. KONU VE ALT TÜR (TOPIC & SUBTYPE) ---
Her haberi gruplamak için bir "topic" ve "subtype" ata.
- **topic**: Olayı özetleyen benzersiz ID (Örn: HALKA_ARZ_MEYSU, BEDELLI_KONTR, GUNLUK_RAPOR_EUKYO).
- **subtype**:
  - Halka Arz İçin: IZAHNAME (Ana Haber), FIYAT_TESPIT (Önemli), EK (Detay), ANALIST_RAPORU (Yan).
  - Rutin İçin: GUNLUK_BULTEN, DEVRE_KESICI, FON_DAGILIM.
  - Diğer: GENEL.

--- 3. YAYIN HEDEFİ (PUBLISH TARGET) ---
Puanına ve Alt Türüne göre karar ver:
- **ALL_CHANNELS**: Puan > 0.7 VE (Ana Haber, İzahname, Dev İş, Bedelsiz Onayı).
- **WEB_ONLY**: Puan 0.4-0.7 VEYA (Ekler, Analist Raporları, Rutin Finansallar).
- **NONE**: Puan < 0.4 VEYA (Günlük Rutin Raporlar, Tekrarlar, Fon Bültenleri).

ÇIKTI FORMATI (JSON):
{
  "primary_ticker": "XXXX",
  "publisher_ticker": "YYYY",
  "related_tickers": ["XXXX", "YYYY"],
  "published_at": {"date":"YYYY-MM-DD","time":"HH:MM","timezone":"Europe/Istanbul"},
  
  "topic": "OLAY_BAZLI_UNIQ_ID",
  "subtype": "IZAHNAME | EK | FIYAT | GENEL | RAPOR",
  
  "category": "Sözleşme | Yatırım | Sermaye | Halka Arz | SPK | Diğer",
  "newsworthiness": 0.0,
  
  "key_numbers": {
    "amount_raw": "...",
    "ratio_to_market_cap": "...", 
    "ratio_to_revenue": "..."
  },

  "headline": "Çarpıcı Manşet",
  "facts": [{"k":"...","v":"..."}],
  
  "tweet": {
    "text": "X formatında metin",
    "hashtags": ["#BIST","#KAP","#PrimaryTicker"],
    "disclaimer": "YTD"
  },
  
  "seo": {"title":"...","meta_description":"...","article_md":"..."},
  "visual_prompt": "...",
  
  "publish_target": "ALL_CHANNELS | WEB_ONLY | NONE",
  
  "notes": {
    "is_routine_spam": true/false,
    "editor_comment": "..."
  }
}
"""
# ======================
# VALIDATION / DEDUPE
# ======================

BROKER_TICKERS = {
    # gerçekten aracı kurum / portföy / yatırım odaklı olanlar (küçük liste!)
    "ALNUS","ISMEN","ISYAT","IYFYO","PSP","DMD","BLS","GEDIK","INFO","TERA","A1CAP","GLBMD","OSMEN","UNLU"
    # istersen zamanla genişletirsin ama BIST'in yarısını koyma
}

BIST_TICKER_PATTERNS = [
    r"\bBIST[:\s]*([A-Z]{3,6})\b",
    r"\b\(([A-Z]{3,6})\)\b",
    r"\bhisse[:=\s]*([A-Z]{3,6})\b",
]

def extract_bist_tickers(text: str) -> list[str]:
    if not text:
        return []
    found = []
    for p in BIST_TICKER_PATTERNS:
        for m in re.findall(p, text, flags=re.IGNORECASE):
            t = (m or "").upper().strip()
            if 3 <= len(t) <= 6:
                found.append(t)
    # uniq, preserve order
    seen = set()
    out = []
    for t in found:
        if t not in seen:
            seen.add(t)
            out.append(t)
    return out

def resolve_primary_ticker(item: dict, publisher_guess: str, text: str) -> str:
    """
    LLM primary_ticker'i doğrula:
    - LLM primary varsa ve broker değilse: kabul
    - primary broker ise veya boşsa: metindeki BIST ticker'lardan publisher dışındaki ilkini seç
    - hiç yoksa: publisher
    """
    primary = (item.get("primary_ticker") or "").upper().strip()
    publisher = (item.get("publisher_ticker") or publisher_guess or "").upper().strip()

    # 1) LLM primary broker değilse güven
    if primary and primary not in BROKER_TICKERS:
        return primary

    # 2) metinden aday bul
    cands = extract_bist_tickers(text)
    for c in cands:
        if c != publisher and c not in BROKER_TICKERS:
            return c

    # 3) son çare
    if primary:
        return primary
    return publisher


def normalize_tickers(item: dict, publisher_guess: str, text: str) -> dict:
    """
    item içine primary/publisher/related'ı kesin oturtur.
    """
    publisher = (item.get("publisher_ticker") or publisher_guess or "").upper().strip()
    primary = resolve_primary_ticker(item, publisher_guess, text)

    item["publisher_ticker"] = publisher or primary
    item["primary_ticker"] = primary

    related = item.get("related_tickers")
    if not isinstance(related, list):
        related = []
    related = [str(x).upper().strip() for x in related if str(x).strip()]
    # metinden de ekle
    for t in extract_bist_tickers(text):
        if t not in related:
            related.append(t)
    # primary + publisher garanti
    for t in [primary, item["publisher_ticker"]]:
        if t and t not in related:
            related.append(t)
    item["related_tickers"] = related
    item["ticker"] = item.get("primary_ticker") or item.get("publisher_ticker") or "UNKNOWN"


    return item


def load_daily_flash_topics(news_items_path: str) -> dict:
    """
    Bugün ALL_CHANNELS olmuş topic sayacı (spam için).
    """
    counts = {}
    data = safe_read_json(news_items_path) or []
    today = datetime.now().strftime("%Y-%m-%d")
    for it in data:
        try:
            pub = (it.get("published_at") or {}).get("date")
            if pub != today:
                continue
            if it.get("publish_target") != "ALL_CHANNELS":
                continue
            topic = it.get("topic")
            if topic:
                counts[topic] = counts.get(topic, 0) + 1
        except Exception:
            continue
    return counts


def apply_spam_guardrails(item: dict, flash_topic_counts: dict) -> dict:
    """
    - subtype EK / ANALIST_RAPORU / GUNLUK_BULTEN ise ALL_CHANNELS'i WEB_ONLY yap
    - aynı topic için günde 1'den fazla ALL_CHANNELS varsa WEB_ONLY yap
    """
    subtype = (item.get("subtype") or "GENEL").upper().strip()
    topic = item.get("topic")

    # 1) subtype rule
    if subtype in {"EK", "ANALIST_RAPORU", "GUNLUK_BULTEN", "FON_DAGILIM"}:
        if item.get("publish_target") == "ALL_CHANNELS":
            item["publish_target"] = "WEB_ONLY"
            item.setdefault("notes", {})
            item["notes"]["is_downgraded"] = True
            item["notes"]["downgrade_reason"] = f"subtype={subtype}"

    # 2) topic quota
    if topic and item.get("publish_target") == "ALL_CHANNELS":
        if flash_topic_counts.get(topic, 0) >= 1:
            item["publish_target"] = "WEB_ONLY"
            item.setdefault("notes", {})
            item["notes"]["is_downgraded"] = True
            item["notes"]["downgrade_reason"] = f"topic_quota={topic}"

    return item




# ======================
# Utilities
# ======================
def abspath(p: str) -> str:
    return os.path.abspath(p)

def ensure_outdir():
    os.makedirs(OUT_DIR, exist_ok=True)
    # news_items.json yoksa boş array ile oluştur (gözle görülür olsun)
    if not os.path.exists(OUTPUT_FILE):
        with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
            json.dump([], f, ensure_ascii=False, indent=2)
    # jsonl yoksa dokunma (append file)

def setup_gemini():
    if not API_KEY:
        print("[ERROR] GEMINI_API_KEY env yok.")
        return None
    genai.configure(api_key=API_KEY)
    return True

def safe_read_json(path: str):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None

def safe_write_json_atomic(path: str, data):
    """
    Atomic write: önce tmp sonra replace.
    (Windows/mac/linux güvenli)
    """
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False, indent=2)
    os.replace(tmp, path)

def append_jsonl(path: str, item: dict):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "a", encoding="utf-8") as f:
        f.write(json.dumps(item, ensure_ascii=False) + "\n")

def extract_symbol_from_gemini_json(data: dict):
    for k in ("symbol", "ticker", "hisse", "stockCode", "stock_code"):
        v = data.get(k)
        if isinstance(v, str) and v.strip():
            return v.strip().upper()

    hay = " ".join([
        str(data.get("subject", "")),
        str(data.get("summary", "")),
        str(data.get("fullText", "")),
    ])

    patterns = [
        r"\bBIST[:\s]*([A-Z]{3,6})\b",
        r"\bhisse[:=\s]*([A-Z]{3,6})\b",
        r"\b\(([A-Z]{3,6})\)\b",
        r"\bhisse=([A-Z]{3,6})\b",
    ]
    for p in patterns:
        m = re.search(p, hay, flags=re.IGNORECASE)
        if m:
            return m.group(1).upper()
    return None

def load_financials_for_symbol(symbol: str):
    if not symbol:
        return None
    fn = f"{symbol.upper()}_financials.json"
    path = os.path.join(FIN_DIR, fn)
    if not os.path.exists(path):
        return None
    return safe_read_json(path)

def normalize_published_at(data: dict) -> str:
    pub_at = data.get("published_at")
    if pub_at:
        return str(pub_at)

    pdate = data.get("publishDate")
    if pdate:
        try:
            dt_obj = datetime.strptime(pdate, "%d.%m.%Y %H:%M:%S")
            return dt_obj.strftime("%Y-%m-%dT%H:%M:%S+03:00")
        except Exception:
            pass

    return datetime.now().strftime("%Y-%m-%dT%H:%M:%S+03:00")

def strip_code_fence(s: str) -> str:
    t = (s or "").strip()
    if t.startswith("```json"):
        t = t[7:]
    elif t.startswith("```"):
        t = t[3:]
    if t.endswith("```"):
        t = t[:-3]
    return t.strip()

def load_processed_set() -> set:
    if not os.path.exists(PROCESSED_TRACKER_FILE):
        return set()
    try:
        with open(PROCESSED_TRACKER_FILE, "r", encoding="utf-8") as f:
            return set(json.load(f))
    except Exception:
        return set()

def save_processed_set(s: set):
    os.makedirs(os.path.dirname(PROCESSED_TRACKER_FILE), exist_ok=True)
    with open(PROCESSED_TRACKER_FILE, "w", encoding="utf-8") as f:
        json.dump(list(s), f, ensure_ascii=False, indent=2)

def load_existing_news() -> list:
    if not os.path.exists(OUTPUT_FILE):
        return []
    try:
        return safe_read_json(OUTPUT_FILE) or []
    except Exception:
        return []

def get_mongo_collection():
    """MongoDB bağlantısı ve collection döndürür."""
    try:
        client = MongoClient(MONGO_URI, serverSelectionTimeoutMS=5000)
        client.admin.command('ping')  # Bağlantı testi
        db = client[MONGO_DB]
        return db[MONGO_COLLECTION]
    except ConnectionFailure as e:
        print(f"[WARN] MongoDB bağlantı hatası: {e}")
        return None

def persist_to_mongo(item: dict):
    """Haberi MongoDB'ye kaydeder (debug alanları filtrelenmiş)."""
    collection = get_mongo_collection()
    if collection is None:
        return False
    
    # Kaldırılacak debug/internal alanlar
    DEBUG_FIELDS = {
        "_source_file", "_cwd", "_output_file_abs", "_generated_at",
        "topic", "subtype", "notes"
    }
    
    try:
        # Duplicate kontrolü (headline + tarih)
        headline = item.get("headline", "")
        pub_date = None
        if isinstance(item.get("published_at"), dict):
            pub_date = item["published_at"].get("date")
        
        if headline and pub_date:
            existing = collection.find_one({
                "headline": headline,
                "published_at.date": pub_date
            })
            if existing:
                print(f"[MONGO] Haber zaten mevcut: {headline[:40]}...")
                return False
        
        # Debug alanlarını filtrele
        mongo_item = {k: v for k, v in item.items() if k not in DEBUG_FIELDS}
        mongo_item["_inserted_at"] = datetime.now().isoformat()
        
        # related_tickers alanını garantile
        if "related_tickers" not in mongo_item or not mongo_item["related_tickers"]:
            primary = mongo_item.get("primary_ticker") or mongo_item.get("ticker")
            mongo_item["related_tickers"] = [primary] if primary else []
        
        result = collection.insert_one(mongo_item)
        ticker = mongo_item.get("primary_ticker", "UNKNOWN")
        print(f"[MONGO] ✅ Kaydedildi: {ticker} -> {result.inserted_id}")
        return True
    except Exception as e:
        print(f"[MONGO] ❌ Kayıt hatası: {e}")
        return False

def persist_one_item(item: dict):
    """
    1) JSONL'ye append (kaybolmasın)
    2) JSON array'e atomic update
    3) MongoDB'ye kaydet
    """
    append_jsonl(OUTPUT_JSONL, item)

    existing = load_existing_news()
    existing.append(item)
    safe_write_json_atomic(OUTPUT_FILE, existing)

    print(f"[DEBUG] wrote -> {abspath(OUTPUT_FILE)} (total={len(existing)})")
    print(f"[DEBUG] jsonl -> {abspath(OUTPUT_JSONL)}")
    
    # MongoDB'ye de kaydet
    persist_to_mongo(item)


# ======================
# Core: process one file
# ======================
def process_one_file(client, file_path: str, embedder=None, memory=None):
    data = safe_read_json(file_path)
    if not data:
        return None

    symbol = extract_symbol_from_gemini_json(data) or ""
    fin = load_financials_for_symbol(symbol) if symbol else None
    pub_at = normalize_published_at(data)

    kap_json = {
        "ticker": symbol,
        "published_at": pub_at,
        "subject": data.get("subject") or "",
        "summary": data.get("summary") or "",
        "fullText": data.get("fullText") or "",
        "url": data.get("url") or f"https://www.kap.org.tr/tr/Bildirim/{data.get('disclosureIndex', '')}"
    }

    retrieval = None
    store_pack = None
    if USE_MEMORY and symbol and embedder and memory:
        retrieval, store_pack = handle_new_kap(
            embedder, memory, kap_json,
            financials_json=fin,
            topk=MEMORY_TOPK
        )

    parts = []
    parts.append(f"SYMBOL: {symbol}" if symbol else "SYMBOL: UNKNOWN")
    parts.append("FINANCIALS_JSON:\n" + (json.dumps(fin, ensure_ascii=False, indent=2) if fin else "null"))

    if retrieval and retrieval.get("TOPK_CONTEXT"):
        hx = []
        for i, h in enumerate(retrieval["TOPK_CONTEXT"], 1):
            sim = h.get("similarity")
            try:
                sim_str = f"{float(sim):.2f}"
            except Exception:
                sim_str = "NA"

            hx.append(
                f"[{i}] Date: {h.get('published_at')} | Sim: {sim_str}\n"
                f"Content: {(h.get('text') or '')[:800]}"
            )
        parts.append("HISTORY_CONTEXT_TOPK:\n" + "\n---\n".join(hx))
    else:
        parts.append("HISTORY_CONTEXT_TOPK: none")

    if kap_json["subject"]:
        parts.append(f"Subject: {kap_json['subject']}")
    if kap_json["summary"]:
        parts.append(f"Summary: {kap_json['summary']}")
    if kap_json["fullText"]:
        parts.append("Full Text:\n" + kap_json["fullText"])

    full_content = "\n\n".join(parts).strip()
    if not full_content:
        return None

    try:
        model = genai.GenerativeModel(
            model_name=MODEL_NAME,
            system_instruction=NEWS_SYSTEM_PROMPT
        )
        resp = model.generate_content(
            contents=full_content,
            generation_config=types.GenerationConfig(
                temperature=0.3,
                top_p=0.9,
                max_output_tokens=8192,
                response_mime_type="application/json",
            )
        )
    except Exception as e:
        print(f"[ERROR] Gemini API Error: {e}")
        return None

    if not resp.text:
        return None

    txt = strip_code_fence(resp.text)
    try:
        out = json.loads(txt)
    except Exception:
        print("[PARSE_FAIL]", os.path.basename(file_path), "resp_head=", txt[:300])
        return None

    # memory'yi besle (LLM başarısında)
    if store_pack and memory:
        try:
            store_kap(memory, store_pack)
        except Exception as e:
            print("[WARN] store_kap failed:", e)

    item = out[0] if isinstance(out, list) and out else out
    if not isinstance(item, dict):
        return None

    item["_source_file"] = file_path
    item["_generated_at"] = datetime.now().strftime("%Y-%m-%dT%H:%M:%S+03:00")
    item["_cwd"] = os.getcwd()
    item["_output_file_abs"] = abspath(OUTPUT_FILE)
    
    # URL'i gemini çıktısına ekle (Gemini üretmezse source'dan al)
    if not item.get("url") and kap_json.get("url"):
        item["url"] = kap_json["url"]

    return item


# ======================
# Main loop
# ======================
def main():
    print("Initializing KAP News Engine (Journalist Mode)...")
    print("[DEBUG] CWD:", os.getcwd())
    print("[DEBUG] OUT_DIR:", abspath(OUT_DIR))
    print("[DEBUG] OUTPUT_FILE:", abspath(OUTPUT_FILE))
    print("[DEBUG] TRACKER_FILE:", abspath(PROCESSED_TRACKER_FILE))

    ensure_outdir()

    client = setup_gemini()
    if not client:
        return

    embedder = None
    memory = None
    if USE_MEMORY:
        try:
            print("[INFO] Loading Embedder (LITE Mode)...")
            embedder = load_embedder()  # default (MiniLM)
            memory = KapMemory(persist_dir=MEMORY_DIR, collection_name=MEMORY_COLLECTION)
            print("[INFO] Memory ready.")
        except Exception as e:
            print(f"[WARN] Memory disabled due to error: {e}")
            embedder, memory = None, None

    processed = load_processed_set()
    flash_topic_counts = load_daily_flash_topics(OUTPUT_FILE)

    print(f"[INFO] Loaded {len(processed)} processed files.")

    while True:
        try:
            search_pattern = os.path.join(DATA_DIR, "*_gemini.json")
            files = glob.glob(search_pattern)
            new_files = [f for f in files if f not in processed]

            if not new_files:
                time.sleep(SLEEP_NO_NEW)
                continue

            print(f"\n[{datetime.now().strftime('%H:%M:%S')}] {len(new_files)} yeni analiz dosyası bulundu.")

            for i, fp in enumerate(new_files, 1):
                print(f"Processing [{i}/{len(new_files)}]: {os.path.basename(fp)}")

                item = process_one_file(client, fp, embedder=embedder, memory=memory)

                # Her halükarda processed listesine ekle ki tekrar okumasın
                processed.add(fp)
                save_processed_set(processed)

                if item:
                    # Publisher guess = dosyadan çıkan SYMBOL (şu an symbol çıkardığın şey)
                    raw = safe_read_json(fp) or {}
                    publisher_guess = extract_symbol_from_gemini_json(raw) or ""
                    raw_text = " ".join([
                        str(raw.get("subject","")),
                        str(raw.get("summary","")),
                        str(raw.get("fullText","")),
                    ])

                    # 1) primary/publisher/related düzelt
                    item = normalize_tickers(item, publisher_guess, raw_text)
                    if not isinstance(item.get("notes"), dict):
                        item["notes"] = {}

                    # 2) publish_target yoksa geçici olarak nw bandından set edeceğiz (aşağıda zaten yapıyorsun)
                    if "publish_target" not in item:
                        item["publish_target"] = "NONE"

                    try:
                        nw = float(item.get("newsworthiness", 0.0))
                    except Exception:
                        nw = 0.0

                    # --- FİLTRELEME VE KAYIT MANTIĞI ---

                    # SEVİYE 1: ÇÖP (Görmezden Gel)
                    if nw < 0.45: 
                        pt = item.get("primary_ticker") or item.get("publisher_ticker") or "UNKNOWN"
                        print(f"🗑️ [JUNK] {pt} (Score: {nw}) -> Elendi.")
                        continue 

                    # SEVİYE 2: SADECE WEB (Kaydet ama Tweet Atma)
                    elif 0.45 <= nw < 0.85:
                        item["publish_target"] = "WEB_ONLY"
                        item = apply_spam_guardrails(item, flash_topic_counts)
                        persist_one_item(item) # <--- DÜZELTME: Anında diske yaz
                        pt = item.get("primary_ticker") or item.get("publisher_ticker") or "UNKNOWN"
                        print(f"📰 [FEED] {pt} (Score: {nw}) -> {item.get('headline','')[:60]}...")

                    # SEVİYE 3: FLASH HABER (Her yere bas)
                    else:
                        item["publish_target"] = "ALL_CHANNELS"

                        # ✅ guardrail mutlaka burada da çalışmalı
                        item = apply_spam_guardrails(item, flash_topic_counts)

                        # log için primary
                        pt = item.get("primary_ticker") or item.get("publisher_ticker") or "UNKNOWN"

                        # ✅ yaz
                        if item.get("publish_target") != "NONE":
                            persist_one_item(item)

                        # ✅ sayaç sadece gerçekten ALL_CHANNELS kaldıysa artsın
                        if item.get("publish_target") == "ALL_CHANNELS":
                            t = item.get("topic")
                            if t:
                                flash_topic_counts[t] = flash_topic_counts.get(t, 0) + 1
                            print(f"🔥 [FLASH] {pt} (Score: {nw}) -> {item.get('headline','')[:60]}...")
                        elif item.get("publish_target") == "WEB_ONLY":
                            print(f"📰 [DOWNGRADED->WEB] {pt} (Score: {nw}) -> {item.get('headline','')[:60]}...")
                        else:
                            print(f"🗑️ [SKIP] {pt} (Score: {nw}) -> Spam/low-quality.")

                time.sleep(SLEEP_BETWEEN_FILES)

        except Exception as e:
            print(f"[ERROR] Main loop error: {e}")
            time.sleep(10)

if __name__ == "__main__":
    main()
