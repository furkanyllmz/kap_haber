import os
import json
import glob
import time
from datetime import datetime
import requests
from bs4 import BeautifulSoup
from google import genai
from google.genai import types
from google.api_core import retry
from dotenv import load_dotenv
import re
# EMBEDDER will be loaded in main
from chroma_kap_memory import load_embedder, KapMemory, handle_new_kap, store_kap, get_ticker_frequency


# Load environment variables from .env file
load_dotenv()

# Configuration
# You must set this environment variable before running the script
API_KEY = os.environ.get("GEMINI_API_KEY") 
TELEGRAM_BOT_TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN")
TELEGRAM_CHAT_ID = os.environ.get("TELEGRAM_CHAT_ID")
DATA_DIR = "./daily_data_kap/gemini"  # Directory containing the JSON files
OUTPUT_FILE = "kap_alarms.json"
PROCESSED_TRACKER_FILE = "processed_files.json"
FIN_DIR = "./daily_data_kap/financials"  # burada SYMBOL_financials.json duruyor
EMBEDDER = None # Will be initialized in main
MEMORY = None   # Will be initialized in main


# The System Prompt defined by the user
SYSTEM_PROMPT = """
Sen "KAP Scalping Alarm Filtreleyici" (KAP-SAF) v4.0 - Hybrid Sniper.
Görevin: Geçmiş hafızayı (HISTORY_CONTEXT) ve Finansal Verileri (FINANCIALS_JSON) kullanarak SADECE "Piyasa Bozucu" (Market Moving) ve "TAZE" haberleri bulmaktır.

⚠️ TEMEL FELSEFE: "AZ AMA ÖZ."
- Günde 50 tane alarm üretme. Günde 3-5 tane "TAVAN" adayı üret.
- Yanlış pozitif göndermek, kullanıcının para kaybetmesi demektir.
- Emin değilsen, tutar küçükse, konu rutinsa: SESSİZ KAL ([]).

====================================================================

GİRDİ ANALİZİ & RAG KULLANIMI (GEÇMİŞ KONTROLÜ)

Sana NEW_KAP ve HISTORY_CONTEXT (Geçmiş) verilecek.
Adım adım şu mantığı uygula:

1.  **BAYAT KONTROLÜ (DUPLICATE CHECK):**
    - Girdide "TARİH FARKI" bilgisine bak.
    - Eğer "0 Gün Önce" veya "1 Gün Önce" yazan ve metni %90 benzeyen bir haber varsa:
    -> DERHAL REDDET ([]). (Bu bir tekrardır).

2.  **SÜREÇ KONTROLÜ VE YAŞAM DÖNGÜSÜ (LIFECYCLE CHECK):**
    - Geçmişte (HISTORY_CONTEXT) aynı işle ilgili "ana haber" geldiyse, sonraki "prosedürel" adımları REDDET.
    
    ÖZEL DURUM: BEDELSİZ / SERMAYE ARTIRIMI (CAPITAL_ACTION):
    - Zirve Noktası: "SPK ONAYI" veya "BAŞVURU SONUCU: ONAY". (ALARM BURADA ÇALMALI).
    - Çöp Noktalar (REDDET): 
      - "İhraç Belgesinin Alınması / Onaylanması"
      - "Esas Sözleşme Tadil Metni Tescili"
      - "Kurul Kaydına Alınma"
      - "Hak Kullanım Tarihinin Belirlenmesi" (Sadece bedelli ise önemlidir, bedelsizde nötrdür).
      - Eğer metin "İhraç Belgesi", "Tadil Metni", "Tescil İşlemi" içeriyorsa VE HISTORY_CONTEXT'te son 15 gün içinde "SPK Onayı" varsa -> REDDET.
    MANTIK:
    - Eğer HISTORY_CONTEXT içinde "SPK Onayı" varsa ve NEW_KAP "İhraç Belgesi / Tescil" diyorsa:
    -> DERHAL REDDET ([]). (Gazı alınmış haber).

3.  **TEKRAR KONTROLÜ (REPETITION CHECK):**
    - Eğer şirket son 7 günde 3'ten fazla benzer "Yeni İş" haberi attıysa (HISTORY_CONTEXT'ten anlarsın):
    - Bu şirket "Haber Sağanağı" (Spam) yapıyor demektir.
    -> ÇOK DAHA SERT FİLTRE UYGULA (Ciro oranı en az %15 olmalı, yoksa REDDET).

====================================================================

AŞAMA 1: KATEGORİK RET LİSTESİ (BU KELİMELERİ GÖRÜNCE KAÇ)
Aşağıdaki konular SCALPING (Hızlı Al-Sat) için değersizdir. ASLA alarm üretme:

1.  **BORÇLANMA:** "Kira Sertifikası", "Tahvil", "Bono", "Borçlanma Aracı", "Sukuk" (İhraç, Satış, Tamamlanma farketmez).
2.  **İDARİ/RUTİN:** "Tescil", "İmza Sirküleri", "Denetçi Seçimi", "Genel Kurul Sonucu", "Adres Değişikliği", "Komite".
3.  **SATIŞ/DEVİR:** "Pay Satış Bilgi Formu", "Fiyat İstikrarı Kapsamında Satış", "Ortak Satışı".
4.  **FON/RAPOR:** "Portföy Değer Raporu", "Net Aktif Değer", "Günlük Rapor".
5.  **PİYASA İŞLEMLERİ:** "Devre Kesici", "VBTS", "Kredili İşlem", "Brüt Takas".

====================================================================

AŞAMA 2: MADDİYAT VE BÜYÜKLÜK FİLTRESİ (OLD LITE+ RULES)

Bir haberi "BIG_CONTRACT" (Yeni İş) olarak işaretlemek için şu EŞİKLERİ aşmak ZORUNDADIR:

Durum A: FINANCIALS_JSON VERİSİ VARSA
- (İş Tutarı / Yıllık Ciro [revenue]) > %5 OLMALI.
- VEYA (İş Tutarı / Piyasa Değeri [market_cap]) > %3 OLMALI.
- Altındaysa -> [] (Alarm Yok).

Durum B: FINANCIALS_JSON VERİSİ YOKSA (KÖR UÇUŞ)
- Tutar **EN AZ 30.000.000 TL** (veya döviz karşılığı) OLMALI.
- 300 Bin TL, 1 Milyon TL, 5 Milyon TL gibi rakamlar REDDET.
- Tutar YOKSA -> REDDET.
- SADECE "Yurt Dışı", "NATO", "Savunma Sanayi" gibi stratejik kelimeler varsa 15 Milyon TL'ye inebilirsin.

- FINANCIALS_JSON null İSE:

- Ciro / ölçek / büyüklük hesabı YAPMA

- Tahmin ETME

- Sadece metin sinyallerine göre ve ÇOK SEÇİCİ davran



- Eğer metindeki parasal tutar ile FINANCIALS_JSON birlikteyse:

- Oran hesaplayabilirsin:

contract_amount / revenue

contract_amount / market_cap

- Bu oranı key_numbers.ratio alanına yazabilirsin.


====================================================================

AŞAMA 3: GEÇERLİ ALARM TİPLERİ (POZİTİF LİSTE)

Sadece aşağıdaki 4 durumdan biri varsa ve AŞAMA 2'yi geçtiyse JSON üret:

1.  **BIG_CONTRACT (Dev İş Anlaşması):**
    - "İmzalandı", "Kazanıldı" (Kesin Dil).
    - "Görüşülüyor", "Niyet", "Beklenmektedir" -> REDDET.

2.  **CAPITAL_ACTION (Sermaye/Temettü):**
    - **Bedelsiz:** Oran > %100 VE (YK Kararı veya SPK Onayı).
    - **Temettü:** Nakit dağıtım kararı.

3.  **CORPORATE_ACTION (Birleşme/Satın Alma):**
    - Şirket SATIN ALIYORSA (Büyüme odaklı).

4.  **BUYBACK (Geri Alım):**
    - SADECE "Geri Alım Programı BAŞLATILMASI".
    - Günlük alım işlemleri -> REDDET.

====================================================================


DİNAMİK FREKANS FİLTRESİ (ADAPTİF EŞİK)

Sana "NEWS_FREQUENCY_7D" (Son 7 Günlük Haber Sayısı) verilecek.
Bu sayıya göre "BIG_CONTRACT" eşiklerini sertleştir:

1.  **DÜŞÜK FREKANS (0-1 Haber):**
    - Şirket sessizdi, bu haber SÜRPRİZ olabilir.
    - Standart kuralları uygula (25 Milyon TL veya %5 Ciro).

2.  **ORTA FREKANS (2-4 Haber):**
    - Şirket aktif. Haber yorgunluğu başlıyor.
    - EŞİĞİ YÜKSELT: Tutar en az 50 Milyon TL (veya %10 Ciro) olmalı.

3.  **YÜKSEK FREKANS (5+ Haber):**
    - Şirket "SPAM" yapıyor. Piyasa tepkisizleşmiş olabilir.
    - ACIMASIZ OL: Tutar en az 150 Milyon TL (veya %20 Ciro) olmalı.
    - Altındaysa -> REDDET ([]).

====================================================================


ÇIKTI FORMATI (STRICT JSON)
Emin değilsen, tutar küçükse, borçlanmaysa -> [] döndür.

[
  
"ticker": "XXXX",

"published_at": {

"date": "YYYY-MM-DD",

"time": "HH:MM",

"timezone": "Europe/Istanbul"

},

"key_numbers": {

"amount": "string veya null",

"ratio": "string veya null",

"dates": ["string", "..."]

},

"event_type": "CAPITAL_ACTION | BIG_CONTRACT | CORPORATE_ACTION | BUYBACK",

"urgency": "HIGH | VERY_HIGH",

"confidence": 0.95,

"watch_reason": [

"Tutar: 45 Milyon USD",

"Ciroya oran: %18 (ölçek büyük)",

"Bağlayıcılık: Kesin sözleşme"

],

"notification_text": "Şirket X, ciroya anlamlı oranlı ve kesinleşmiş yurt dışı sözleşme açıkladı."

}

]
"""



def setup_gemini():
    if not API_KEY:
        print("Please set the GEMINI_API_KEY environment variable.")
        print("Example: export GEMINI_API_KEY='your_api_key'")
        return None
    
    client = genai.Client(api_key=API_KEY)
    return client

SUBSCRIBERS_FILE = "subscribers.json"

def get_subscribers():
    if not os.path.exists(SUBSCRIBERS_FILE):
        return []
    try:
        with open(SUBSCRIBERS_FILE, 'r') as f:
            return json.load(f)
    except:
        return []

def send_telegram_notification(item, file_name):
    """Sends a detailed notification to all subscribers."""
    if not TELEGRAM_BOT_TOKEN:
        print("[WARN] Telegram Bot Token not set.")
        return

    subscribers = get_subscribers()
    if not subscribers:
        # Fallback to env chat ID if no subscribers file content
        if TELEGRAM_CHAT_ID:
            subscribers = [TELEGRAM_CHAT_ID]
        else:
            print("[WARN] No subscribers found.")
            return

    # Extract fields safely
    ticker = item.get("ticker", "UNKNOWN")
    event_type = item.get("event_type", "UNKNOWN")
    confidence = item.get("confidence", 0.0)
    notif_text = item.get("notification_text", "No text provided.")
    
    # Published At
    pub_at = item.get("published_at", {})
    if isinstance(pub_at, dict):
        date_str = pub_at.get("date", "")
        time_str = pub_at.get("time", "")
    else:
        date_str, time_str = "", ""
    
    # Key Numbers
    key_nums = item.get("key_numbers", {})
    if not isinstance(key_nums, dict): key_nums = {}
    amount = key_nums.get("amount") or "-"
    ratio = key_nums.get("ratio") or "-"
    
    # Watch Reason
    reasons = item.get("watch_reason", [])
    if isinstance(reasons, list):
        reasons_str = "\n".join([f"• {r}" for r in reasons])
    else:
        reasons_str = str(reasons)

    # Construct HTML Message
    msg = f"""🚨 <b>KAP ALARM</b> ({confidence})

<b>Hisse:</b> {ticker}
<b>Tip:</b> {event_type}
<b>Tarih:</b> {date_str} {time_str}

💰 <b>Rakamlar:</b>
• Tutar: {amount}
• Oran: {ratio}

📝 <b>Özet:</b>
{notif_text}

🔍 <b>Tespit Nedeni:</b>
{reasons_str}

📂 <i>Dosya: {file_name}</i>"""

    url = f"https://api.telegram.org/bot{TELEGRAM_BOT_TOKEN}/sendMessage"
    
    for chat_id in subscribers:
        try:
            payload = {
                "chat_id": chat_id,
                "text": msg,
                "parse_mode": "HTML" # HTML is safer for underscores in filenames
            }
            resp = requests.post(url, json=payload, timeout=5)
            
            if resp.status_code != 200:
                print(f"[ERROR] Failed to send to {chat_id}: {resp.status_code} - {resp.text}")
                
        except Exception as e:
            print(f"[ERROR] Connection failed to {chat_id}: {e}")
    
    print(f"[INFO] Notification process completed for {len(subscribers)} subscribers.")


def extract_symbol_from_gemini_json(data: dict) -> str | None:
    """
    Öncelik sırası:
    1) data['symbol'] / data['ticker']
    2) subject içinde BIST:XXXX / (XXXX) / hisse=XXXX gibi desenler
    3) summary/fullText içinde BIST:XXXX vb.
    """
    # 1) doğrudan alan
    for k in ("symbol", "ticker", "hisse", "stockCode", "stock_code"):
        v = data.get(k)
        if isinstance(v, str) and v.strip():
            return v.strip().upper()

    # 2) subject/summary/fullText içinden regex
    hay = " ".join([
        str(data.get("subject", "")),
        str(data.get("summary", "")),
        str(data.get("fullText", "")),
    ])

    # yaygın desenler
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

def load_financials_for_symbol(symbol: str) -> dict | None:
    """
    ./daily_data_kap/financials/{SYMBOL}_financials.json dosyasını okur.
    Yoksa None döndürür.
    """
    if not symbol:
        return None
    fn = f"{symbol.upper()}_financials.json"
    path = os.path.join(FIN_DIR, fn)
    if not os.path.exists(path):
        return None
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception:
        return None

def process_file(client, file_path, embedder, memory):  
    try:
        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)

        symbol = extract_symbol_from_gemini_json(data)
        fin = load_financials_for_symbol(symbol) if symbol else None

        # published_at vs publishDate (DD.MM.YYYY HH:MM:SS) handling
        pub_at = data.get("published_at")
        
        if not pub_at:
            pdate = data.get("publishDate")
            if pdate:
                try:
                    # Parse "30.12.2025 19:10:53"
                    dt_obj = datetime.strptime(pdate, "%d.%m.%Y %H:%M:%S")
                    # Manually add +03:00 timezone suffix since we assume TR time
                    pub_at = dt_obj.strftime("%Y-%m-%dT%H:%M:%S+03:00")
                except Exception:
                    # Parse hatası olursa sessizce geç
                    pass

        # Hala yoksa fallback üret
        if not pub_at:
            now = datetime.now()
            pub_at = now.strftime("%Y-%m-%dT%H:%M:%S+03:00")

        # ✅ handle_new_kap kap_json.ticker bekliyor -> ekle
        kap_json = {
            "ticker": symbol or "",
            "published_at": pub_at,
            "subject": data.get("subject") or "",
            "summary": data.get("summary") or "",
            "fullText": data.get("fullText") or "",
        }

        # ✅ Retrieval (topK3 + duplicate gate)
        # ✅ Retrieval (topK3 + duplicate gate)
        if symbol and embedder and memory:
            # Import explicitly inside function if simpler, or assume passed objects are valid
            from chroma_kap_memory import handle_new_kap, store_kap # Ensure these are available
            retrieval, store_pack = handle_new_kap(
                embedder, memory, kap_json,
                financials_json=fin,
                topk=3
            )
        else:
            retrieval, store_pack = None, None

      
        

        # ✅ LLM content
        content_parts = []
        content_parts.append(f"SYMBOL: {symbol}" if symbol else "SYMBOL: UNKNOWN")

        if fin:
            content_parts.append("FINANCIALS_JSON:\n" + json.dumps(fin, ensure_ascii=False, indent=2))
        else:
            content_parts.append("FINANCIALS_JSON: null")

        # ✅ HISTORY_CONTEXT_TOPK3
        if retrieval and retrieval.get("TOPK_CONTEXT"):
            hx = []
            for i, h in enumerate(retrieval["TOPK_CONTEXT"], 1):
                hx.append(
                    f"[{i}] published_at={h.get('published_at')} sim={h.get('similarity')}\n"
                    f"{(h.get('text') or '')[:900]}"
                )
            content_parts.append("HISTORY_CONTEXT_TOPK3:\n" + "\n\n".join(hx))
        else:
            content_parts.append("HISTORY_CONTEXT_TOPK3: none")
        # ... (TopK hazırlandıktan sonra) ...

        # ✅ FREKANS ANALİZİ
        freq_7d = 0
        if symbol and MEMORY:
            # Memory global veya parametre olarak gelmeli
            freq_7d = get_ticker_frequency(MEMORY, symbol, days=7)

        # Prompta ekle
        content_parts.append(f"NEWS_FREQUENCY_7D: {freq_7d} (Son 7 günde bu şirketten gelen haber sayısı)")
        # KAP metni
        if kap_json["subject"]:
            content_parts.append(f"Subject: {kap_json['subject']}")
        if kap_json["summary"]:
            content_parts.append(f"Summary: {kap_json['summary']}")
        if kap_json["fullText"]:
            content_parts.append(f"Full Text:\n{kap_json['fullText']}")

        full_content = "\n\n".join(content_parts).strip()
        if not full_content:
            return None

        response = client.models.generate_content(
            model='gemini-3-flash-preview', 
            contents=full_content,
            config=types.GenerateContentConfig(
                system_instruction=SYSTEM_PROMPT,
                temperature=0.0,
                top_p=0.95,
                top_k=40,
                max_output_tokens=8192,
                response_mime_type="application/json",
            )
        )

        # ✅ parse
        if response.text and response.text.strip():
            text = response.text.strip()
            if text.startswith("```json"):
                text = text[7:]
            elif text.startswith("```"):
                text = text[3:]
            if text.endswith("```"):
                text = text[:-3]
            text = text.strip()

            # ✅ Alarm çıksın/çıkmasın hafızaya yaz (önerdiğin strateji)
            if store_pack and memory:
                from chroma_kap_memory import store_kap
                store_kap(memory, store_pack)

            return text

        # response boşsa da hafızaya yaz
        if store_pack and memory:
            from chroma_kap_memory import store_kap
            store_kap(memory, store_pack)

        return None

    except Exception as e:
        print(f"Error processing {file_path}: {e}")
        return None


def main():
    print("Initializing Gemini KAP Analyzer...")
    
    # 1. Setup Client
    client = setup_gemini()
    if not client:
        return

    # 2. Lazy Load Embedder & Memory
    print("[INFO] Importing chroma_kap_memory persistence module...")
    from chroma_kap_memory import load_embedder, KapMemory

    print("[INFO] Loading embedding model (BGE-M3)... This may take a moment.")
    start_t = time.time()
    EMBEDDER = load_embedder("BAAI/bge-m3")
    print(f"[INFO] Model loaded in {time.time() - start_t:.2f}s")

    print("[INFO] Connecting to Vector Memory...")
    MEMORY = KapMemory(persist_dir="./chroma_kap_memory", collection_name="kap_memory")

    print("=" * 80)
    print("GEMINI KAP ANALYZER - SÜREKLİ İZLEME MODU")
    print("=" * 80)
    
    # Load existing alarms to persist history and fix NameError
    alarms = []
    if os.path.exists(OUTPUT_FILE):
        try:
            with open(OUTPUT_FILE, 'r', encoding='utf-8') as f:
                alarms = json.load(f)
            print(f"[INFO] Geçmiş {len(alarms)} alarm yüklendi.")
        except Exception as e:
            print(f"[WARN] Geçmiş alarmlar yüklenemedi: {e}")
            alarms = []

    # Track processed files to avoid re-analysis
    processed_files = set()
    
    # Load processed files from persistent storage
    if os.path.exists(PROCESSED_TRACKER_FILE):
        try:
            with open(PROCESSED_TRACKER_FILE, 'r') as f:
                processed_files = set(json.load(f))
            print(f"[INFO] {len(processed_files)} işlenmiş dosya geçmişten yüklendi.")
        except Exception as e:
            print(f"[WARN] İşlenmiş dosya listesi yüklenemedi: {e}")
            processed_files = set()
    
    # Also ignore files that generated alarms previously (just in case they are not in tracker)
    for alarm in alarms:
        if "_source_file" in alarm:
            processed_files.add(alarm["_source_file"])
    
    
    while True:
        try:
            # Find files
            # Walking through the gemini directory structure: gemini/*_gemini.json
            search_pattern = os.path.join(DATA_DIR, "*_gemini.json")
            files = glob.glob(search_pattern)
            
            new_files = [f for f in files if f not in processed_files]
            
            if new_files:
                print(f"\n[{datetime.now().strftime('%H:%M:%S')}] {len(new_files)} analiz edilmemiş dosya bulundu.")
                
                for i, file_path in enumerate(new_files):
                    print(f"Processing [{i+1}/{len(new_files)}]: {os.path.basename(file_path)}")
                    
                    result_json_str = process_file(client, file_path, EMBEDDER, MEMORY)
                    
                    # Mark as processed immediately (even if failed/empty response) to avoid death loops
                    processed_files.add(file_path)
                    
                    # Save tracker periodically (every file is safer for crashes)
                    try:
                        with open(PROCESSED_TRACKER_FILE, 'w') as f:
                            json.dump(list(processed_files), f)
                    except:
                        pass
                    
                    if result_json_str:
                        try:
                            result_data = json.loads(result_json_str)
                            
                            # Normalize to a list of items
                            items_to_process = []
                            if isinstance(result_data, list):
                                items_to_process = result_data
                            elif isinstance(result_data, dict):
                                items_to_process = [result_data]
                            
                            for item in items_to_process:
                                confidence = item.get("confidence", 0.0) if isinstance(item, dict) else 0.0
                                
                                if isinstance(item, dict) and confidence >= 0.95:
                                    print(f"ALARM DETECTED in {os.path.basename(file_path)}! (Confidence: {confidence})")
                                    item["_source_file"] = file_path 
                                    alarms.append(item)
                                    
                                    # Save immediately
                                    try:
                                        with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
                                            json.dump(alarms, f, ensure_ascii=False, indent=2)
                                    except Exception as e:
                                        print(f"Error saving alarms file: {e}")
                                    
                                    # Send Telegram Notification
                                    send_telegram_notification(item, os.path.basename(file_path))

                                elif isinstance(item, dict):
                                     print(f"Low confidence ({confidence}) in {os.path.basename(file_path)}. Skipped.")

                        except json.JSONDecodeError:
                            print(f"Failed to decode JSON in {os.path.basename(file_path)}")
                            # print(f"Raw response: {result_json_str[:200]}...") # Optional debug
                            pass
                    
                    # Mark as processed handled above
                    # processed_files.add(file_path)
                    
                    # Sleep to respect rate limits
                    time.sleep(4) 
            
            else:
                # No new files
                # print(".", end="", flush=True) 
                time.sleep(10) # Wait 10 seconds before next scan

        except Exception as e:
            print(f"\n[ERROR] Watch loop error: {e}")
            time.sleep(10)

if __name__ == "__main__":
    main()
