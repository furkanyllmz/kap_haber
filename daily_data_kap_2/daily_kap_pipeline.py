"""
KAP Günlük Veri Toplama Pipeline
=================================
Bu script belirli bir tarih için tüm KAP bildirimlerini çeker ve organize eder:
1. KAP API'den bildirimleri çek
2. Bildirimleri sınıflandır (FR/ODA/DKB)
3. HTML, PDF ve ek dosyaları indir
4. daily_data_kap/{symbol}/{disclosureIndex}/ yapısında kaydet
"""

import json
import random
import re
import shutil
import time
from pathlib import Path
from datetime import datetime
import toml

import pandas as pd
import requests
from bs4 import BeautifulSoup

# ==========================
# AYARLAR
# ==========================
PROJECT_ROOT = Path(__file__).parent
DAILY_DATA_DIR = PROJECT_ROOT / "daily_data_kap"
MAPPING_FILE = PROJECT_ROOT / "kap_symbols_oids_mapping.json"
SETTINGS_FILE = PROJECT_ROOT / "settings.toml"

# Hangi tarihteki bildirimleri işleyeceğiz?
# TARGET_DATE will be set dynamically in the loop


# HTML'den ek PDF linklerini bulmak için regex
ATTACHMENT_RE = re.compile(
    r'<a[^>]+href="(?P<href>/tr/api/file/download/[^"]+)"[^>]*>(?P<label>[^<]+)</a>',
    re.IGNORECASE | re.UNICODE,
)

# ==========================
# SINIFLANDIRMA KURALLARI
# ==========================

# FR için metadata kod ipuçları
FR_CODE_HINTS = ["FR", "MALI_TABLO", "MALİ_TABLO", "OZKAYNAK_DEGISIM", "ÖZKAYNAK_DEĞİŞİM", "NAKIT_AKIS", "NAKİT_AKIŞ"]
FR_TEXT_HINTS = ["finansal rapor", "mali tablo", "mali rapor", "faaliyet raporu", "finansal tablo"]

# DKB için regex
PATTERN_DKB = re.compile(
    r"(?i)(devre\s*kesici|volatilite\s*bazl[ıi]|işlem\s*sırası.*durdurul|VBTS)",
    re.UNICODE,
)

def safe_lower(val: object) -> str:
    """None/NaN güvenli lower."""
    if pd.isna(val):
        return ""
    return str(val).lower()

def is_fr(row: dict) -> bool:
    """FR tespiti"""
    disc_class = str(row.get("disclosureClass", "")).upper()
    rule_type = str(row.get("ruleType", "")).upper()
    combined_codes = f"{disc_class} {rule_type}"

    # 1) Kod ipuçları
    for hint in FR_CODE_HINTS:
        if hint in combined_codes:
            return True

    # 2) subject / summary üzerinden text ipuçları
    subject = safe_lower(row.get("subject", ""))
    summary = safe_lower(row.get("summary", ""))
    text = subject + " " + summary

    for hint in FR_TEXT_HINTS:
        if hint in text:
            return True

    return False

def is_dkb(row: dict) -> bool:
    """DKB tespiti"""
    disc_class = str(row.get("disclosureClass", "")).upper()
    rule_type = str(row.get("ruleType", "")).upper()
    combined_codes = f"{disc_class} {rule_type}"

    # Kod ipuçları
    dkb_code_hints = ["VBTS", "DEVRE KESICI", "DEVRE KESİCİ", "VOLATILITE", "VOLATİLİTE"]
    for hint in dkb_code_hints:
        if hint in combined_codes:
            return True

    # subject / summary regex
    subject = safe_lower(row.get("subject", ""))
    summary = safe_lower(row.get("summary", ""))
    text = subject + " " + summary

    if PATTERN_DKB.search(text):
        return True

    return False

def classify_disclosure(row: dict) -> str:
    """Üst seviye sınıf: FR, DKB, veya ODA"""
    if is_fr(row):
        return "FR"
    if is_dkb(row):
        return "DKB"
    return "ODA"

# ==========================
# HTTP SESSION
# ==========================

def create_browser_session() -> requests.Session:
    s = requests.Session()
    s.headers.update({
        "User-Agent": (
            "Mozilla/5.0 (Windows NT 10.0; Win64; x64) "
            "AppleWebKit/537.36 (KHTML, like Gecko) "
            "Chrome/120.0.0.0 Safari/537.36"
        ),
        "Accept": "application/json, text/plain, /",
        "Accept-Language": "tr-TR,tr;q=0.9,en-US;q=0.8,en;q=0.7",
        "Content-Type": "application/json",
        "Origin": "https://www.kap.org.tr",
        "Referer": "https://www.kap.org.tr/tr/bildirim-sorgu",
    })
    return s

session = create_browser_session()

def robust_get(url: str, expect_binary: bool = False, max_retries: int = 3):
    """429/403 durumlarında bekleyip tekrar deneyecek GET wrapper."""
    global session

    for attempt in range(1, max_retries + 1):
        try:
            time.sleep(random.uniform(1.0, 3.0))
            resp = session.get(url, timeout=60)
            status = resp.status_code

            if status == 200:
                return resp.content if expect_binary else resp.text

            if status in (403, 429):
                print(f"[WARN] {status} geldi ({url}), cooldown 60s + session yenile (attempt {attempt})")
                time.sleep(60)
                session = create_browser_session()
                continue

            print(f"[WARN] {url} -> status {status} (attempt {attempt})")
            time.sleep(5)

        except Exception as e:
            print(f"[ERROR] GET hata: {url} -> {e} (attempt {attempt})")
            time.sleep(5)

    print(f"[FAIL] {url} -> max retry aşıldı.")
    return None

# ==========================
# KAP API - BİLDİRİM ÇEKME
# ==========================

def load_symbol_oid_mapping():
    """settings.toml'dan sembolleri okur ve mapping'den OID'leri bulur."""
    with open(SETTINGS_FILE, "r", encoding="utf-8") as f:
        settings = toml.load(f)
    
    target_symbols = [s.upper() for s in settings.get("symbols", [])]
    
    if not target_symbols:
        raise ValueError("settings.toml'da 'symbols' listesi bulunamadı veya boş!")
    
    with open(MAPPING_FILE, "r", encoding="utf-8") as f:
        mapping_data = json.load(f)
    
    companies = mapping_data.get("companies", {})
    symbol_oid_map = {}
    
    for symbol in target_symbols:
        if symbol in companies:
            symbol_oid_map[symbol] = companies[symbol].get("oid")
    
    return symbol_oid_map

def fetch_disclosures_for_symbol(symbol: str, oid: str, target_date: str) -> list[dict]:
    """Bir sembol için belirli tarihteki bildirimleri çeker."""
    global session
    
    url = "https://www.kap.org.tr/tr/api/disclosure/members/byCriteria"
    
    payload = {
        "fromDate": target_date,
        "toDate": target_date,
        "memberType": "IGS",
        "disclosureClass": "",  # Tüm sınıflar
        "mkkMemberOidList": [],
        "bdkMemberOidList": [],
        "inactiveMkkMemberOidList": [],
        "disclosureIndexList": [],
        "subjectList": [],
        "ruleType": "",
        "period": "",
        "year": "",
        "sector": "",
        "mainSector": "",
        "subSector": "",
        "marketOid": "",
        "isLate": "",
        "term": "",
        "fromSrc": False,
        "index": "",
        "srcCategory": "",
        "bdkReview": ""
    }
    
    max_retries = 3
    for attempt in range(max_retries):
        try:
            time.sleep(random.uniform(2.0, 4.0))
            r = session.post(url, data=json.dumps(payload), timeout=30)
            
            if r.status_code == 429:
                print(f"[WARN] {symbol}: Hız sınırı (429), 60s bekleniyor...")
                time.sleep(60)
                session = create_browser_session()
                continue
            
            if r.status_code != 200:
                print(f"[WARN] {symbol}: API hatası {r.status_code}")
                continue
            
            data = r.json()
            
            if not isinstance(data, list):
                return []
            
            results = []
            for item in data:
                if not isinstance(item, dict):
                    continue
                
                disclosure_index = item.get("disclosureIndex")
                
                # Symbol'ü API'den al - birden fazla kaynağı dene
                item_symbol = "UNKNOWN"
                
                # 1. stockCodes kontrol et (liste veya string olabilir)
                stock_codes = item.get("stockCodes", [])
                if isinstance(stock_codes, list) and stock_codes:
                    item_symbol = stock_codes[0]
                elif isinstance(stock_codes, str) and stock_codes.strip():
                    # stockCodes bazen string olarak geliyor
                    item_symbol = stock_codes.strip()
                
                # 2. relatedStocks alanını kontrol et (liste veya string olabilir)
                elif "relatedStocks" in item:
                    related = item.get("relatedStocks", [])
                    if isinstance(related, list) and related:
                        item_symbol = related[0]
                    elif isinstance(related, str) and related.strip():
                        item_symbol = related.strip()
                
                # 3. basicInfo içindeki stockCode'u kontrol et
                elif "basicInfo" in item:
                    basic = item.get("basicInfo", {})
                    if isinstance(basic, dict) and "stockCode" in basic:
                        item_symbol = basic.get("stockCode")
                
                # 4. memberCode'u kontrol et
                elif "memberCode" in item:
                    member_code = item.get("memberCode", "")
                    if member_code and member_code != "":
                        item_symbol = member_code
                
                # 5. Hala UNKNOWN ise, raw JSON'u debug için kaydet
                if item_symbol == "UNKNOWN":
                    print(f"[DEBUG] Symbol bulunamadı - disclosureIndex: {disclosure_index}")
                    print(f"[DEBUG] Mevcut alanlar: {list(item.keys())}")
                
                result = {
                    "symbol": item_symbol,
                    "disclosureIndex": disclosure_index,
                    "publishDate": item.get("publishDate"),
                    "disclosureClass": item.get("disclosureClass"),
                    "ruleType": item.get("ruleType"),
                    "subject": item.get("subject"),
                    "summary": item.get("summary"),
                    "isLate": item.get("isLate"),
                    "period": item.get("period"),
                    "year": item.get("year"),
                    "term": item.get("term"),
                    "index": item.get("index"),
                    "srcCategory": item.get("srcCategory"),
                    "url": f"https://www.kap.org.tr/tr/Bildirim/{disclosure_index}",
                    "raw_json": json.dumps(item, ensure_ascii=False),
                }
                
                # Sınıflandır
                result["top_level_class"] = classify_disclosure(result)
                
                results.append(result)
            
            return results
            
        except Exception as e:
            print(f"[ERROR] {symbol}: {e}")
            time.sleep(10)
            session = create_browser_session()
    
    return []

# ==========================
# DOSYA İNDİRME
# ==========================

def ensure_disclosure_dir(symbol: str, disclosure_index: int) -> Path:
    """daily_data_kap/{symbol}/{disclosureIndex}/ klasörünü oluşturur"""
    disclosure_dir = DAILY_DATA_DIR / symbol / str(disclosure_index)
    disclosure_dir.mkdir(parents=True, exist_ok=True)
    return disclosure_dir

def download_html(symbol: str, disclosure_index: int) -> Path | None:
    disclosure_dir = ensure_disclosure_dir(symbol, disclosure_index)
    html_path = disclosure_dir / f"{disclosure_index}.html"

    if html_path.exists():
        return html_path

    url = f"https://www.kap.org.tr/tr/Bildirim/{disclosure_index}"
    html = robust_get(url, expect_binary=False)
    if html is None:
        return None

    html_path.write_text(html, encoding="utf-8")
    return html_path

def download_form_pdf(symbol: str, disclosure_index: int) -> Path | None:
    disclosure_dir = ensure_disclosure_dir(symbol, disclosure_index)
    pdf_path = disclosure_dir / f"{disclosure_index}_form.pdf"

    if pdf_path.exists():
        return pdf_path

    pdf_url = f"https://www.kap.org.tr/tr/api/BildirimPdf/{disclosure_index}"
    content = robust_get(pdf_url, expect_binary=True)
    if content is None:
        return None

    pdf_path.write_bytes(content)
    return pdf_path

def parse_attachments_from_html(html_text: str):
    """HTML içinden /tr/api/file/download/.. linkleri ve label'larını listeler."""
    attachments = []
    for m in ATTACHMENT_RE.finditer(html_text):
        href = m.group("href")
        label = (m.group("label") or "").strip()
        full_url = "https://www.kap.org.tr" + href
        attachments.append({"url": full_url, "label": label})
    return attachments

def download_attachments(symbol: str, disclosure_index: int, attachments_meta: list[dict]) -> list[dict]:
    """Ek PDF'leri indir"""
    disclosure_dir = ensure_disclosure_dir(symbol, disclosure_index)
    downloaded = []

    for i, att in enumerate(attachments_meta, start=1):
        url = att["url"]
        label = att.get("label", "")
        local_path = disclosure_dir / f"{disclosure_index}_ek{i}.pdf"

        if not local_path.exists():
            content = robust_get(url, expect_binary=True)
            if content is None:
                print(f"[WARN] Ek PDF indirilemedi: {symbol} {disclosure_index} -> {url}")
                continue
            local_path.write_bytes(content)

        downloaded.append({
            "url": url,
            "label": label,
            "local_path": str(local_path),
        })

    return downloaded

def extract_text_from_html(html_path: Path) -> str:
    """HTML'den temiz metin çıkarır"""
    try:
        html_content = html_path.read_text(encoding="utf-8", errors="ignore")
        soup = BeautifulSoup(html_content, 'html.parser')
        
        # Script ve style taglerini kaldır
        for script in soup(["script", "style"]):
            script.decompose()
        
        # Metni al ve temizle
        text = soup.get_text()
        
        # Fazla boşlukları temizle
        lines = (line.strip() for line in text.splitlines())
        chunks = (phrase.strip() for line in lines for phrase in line.split("  "))
        text = ' '.join(chunk for chunk in chunks if chunk)
        
        return text
    except Exception as e:
        print(f"[WARN] HTML metin çıkarma hatası: {e}")
        return ""

def extract_symbol_from_html(html_path: Path) -> str | None:
    """HTML sayfasından sembol bilgisini çıkarır"""
    try:
        html_content = html_path.read_text(encoding="utf-8", errors="ignore")
        soup = BeautifulSoup(html_content, 'html.parser')
        
        # 1. Meta tag'lerden sembol ara
        meta_tags = soup.find_all('meta')
        for meta in meta_tags:
            if meta.get('name') == 'stockCode' or meta.get('property') == 'stockCode':
                symbol = meta.get('content', '').strip()
                if symbol:
                    return symbol
        
        # 2. Başlıktan sembol ara (örn: "AEFES - Bildirim")
        title = soup.find('title')
        if title:
            title_text = title.get_text().strip()
            # Başlıkta genellikle "SYMBOL - ..." formatı var
            if ' - ' in title_text:
                potential_symbol = title_text.split(' - ')[0].strip()
                # Sembol genellikle 4-6 karakter, büyük harf
                if 3 <= len(potential_symbol) <= 6 and potential_symbol.isupper():
                    return potential_symbol
        
        # 3. Sayfadaki "Şirket Kodu" veya benzeri etiketleri ara
        for label in soup.find_all(['span', 'div', 'td', 'th']):
            text = label.get_text().strip().lower()
            if 'şirket kodu' in text or 'hisse kodu' in text or 'stock code' in text:
                # Bir sonraki element'i kontrol et
                next_elem = label.find_next(['span', 'div', 'td'])
                if next_elem:
                    symbol = next_elem.get_text().strip()
                    if 3 <= len(symbol) <= 6 and symbol.isupper():
                        return symbol
        
        return None
    except Exception as e:
        print(f"[WARN] HTML'den sembol çıkarma hatası: {e}")
        return None


def create_gemini_format(disclosure: dict, html_path: Path = None) -> dict:
    """Gemini API için uygun formatta JSON oluşturur"""
    
    # HTML'den metin çıkar
    full_text = ""
    if html_path and html_path.exists():
        full_text = extract_text_from_html(html_path)
    
    # Gemini formatı
    gemini_data = {
        "disclosureIndex": disclosure.get("disclosureIndex"),
        "symbol": disclosure.get("symbol"),
        "publishDate": disclosure.get("publishDate"),
        "disclosureClass": disclosure.get("disclosureClass"),
        "top_level_class": disclosure.get("top_level_class"),
        "subject": disclosure.get("subject"),
        "summary": disclosure.get("summary"),
        "fullText": full_text,
        "url": disclosure.get("url"),
    }
    
    return gemini_data

def save_gemini_format(disclosure: dict, html_path: Path = None):
    """Gemini formatında JSON'u daily_data_kap/gemini/ altına kaydeder"""
    disclosure_index = disclosure.get("disclosureIndex")
    symbol = disclosure.get("symbol", "UNKNOWN")
    
    # Gemini klasörü oluştur (alt klasör yok, direkt gemini/)
    gemini_dir = DAILY_DATA_DIR / "gemini"
    gemini_dir.mkdir(parents=True, exist_ok=True)
    
    # Gemini formatında JSON oluştur
    gemini_data = create_gemini_format(disclosure, html_path)
    
    # Kaydet - dosya adı: {symbol}_{disclosureIndex}_gemini.json
    gemini_path = gemini_dir / f"{symbol}_{disclosure_index}_gemini.json"
    gemini_path.write_text(json.dumps(gemini_data, ensure_ascii=False, indent=2), encoding="utf-8")
    
    return gemini_path

def process_single_disclosure(disclosure: dict):
    """Bir bildirim için tüm dosyaları indir ve JSON kaydet"""
    symbol = disclosure["symbol"]
    disclosure_index = int(disclosure["disclosureIndex"])
    
    # İlk klasör oluşturma (geçici, sembol değişebilir)
    disclosure_dir = ensure_disclosure_dir(symbol, disclosure_index)
    json_path = disclosure_dir / f"{disclosure_index}_detail.json"
    
    if json_path.exists():
        print(f"[SKIP] {symbol} {disclosure_index} -> zaten var")
        return

    print(f"[INFO] İşleniyor: {symbol} {disclosure_index} ({disclosure.get('top_level_class')})")

    # 1) HTML
    html_path = download_html(symbol, disclosure_index)
    html_text = None
    attachments_meta = []
    
    # Eğer sembol UNKNOWN ise, HTML'den çıkarmayı dene
    if symbol == "UNKNOWN" and html_path is not None:
        extracted_symbol = extract_symbol_from_html(html_path)
        if extracted_symbol:
            print(f"[INFO] HTML'den sembol bulundu: {extracted_symbol}")
            old_symbol = symbol
            symbol = extracted_symbol
            disclosure["symbol"] = symbol
            
            # Klasör yapısını güncelle
            old_dir = DAILY_DATA_DIR / old_symbol / str(disclosure_index)
            new_dir = DAILY_DATA_DIR / symbol / str(disclosure_index)
            
            # Yeni klasörü oluştur
            new_dir.mkdir(parents=True, exist_ok=True)
            
            # Eski klasördeki dosyaları taşı
            if old_dir.exists() and old_dir != new_dir:
                for item in old_dir.iterdir():
                    shutil.move(str(item), str(new_dir / item.name))
                # Eski klasörü sil
                old_dir.rmdir()
                # Eğer UNKNOWN klasörü boşsa onu da sil
                unknown_parent = DAILY_DATA_DIR / old_symbol
                if unknown_parent.exists() and not any(unknown_parent.iterdir()):
                    unknown_parent.rmdir()
            
            # Güncellenmiş yolları kullan
            disclosure_dir = new_dir
            json_path = disclosure_dir / f"{disclosure_index}_detail.json"
            html_path = disclosure_dir / f"{disclosure_index}.html"
    
    if html_path is not None:
        try:
            html_text = html_path.read_text(encoding="utf-8", errors="ignore")
            attachments_meta = parse_attachments_from_html(html_text)
        except Exception as e:
            print(f"[WARN] HTML parse hata: {symbol} {disclosure_index} -> {e}")

    # 2) Form PDF
    form_pdf_path = download_form_pdf(symbol, disclosure_index)

    # 3) Ek PDF'ler
    attachments_downloaded = []
    if attachments_meta:
        attachments_downloaded = download_attachments(symbol, disclosure_index, attachments_meta)

    # 4) JSON gövde
    detail_obj = {
        **disclosure,
        "html_path": str(html_path) if html_path is not None else None,
        "form_pdf_path": str(form_pdf_path) if form_pdf_path is not None else None,
        "attachments": attachments_downloaded,
    }

    json_path.write_text(json.dumps(detail_obj, ensure_ascii=False, indent=2), encoding="utf-8")
    
    # 5) Gemini formatında da kaydet
    gemini_path = save_gemini_format(disclosure, html_path)
    
    print(f"[OK] Kaydedildi: {json_path}")
    print(f"[OK] Gemini format: {gemini_path}")

    time.sleep(random.uniform(0.5, 1.5))

# ==========================
# DEDUPLICATION
# ==========================

def get_existing_disclosure_indices() -> set[int]:
    """Yerel olarak zaten indirilmiş bildirimlerin disclosureIndex'lerini döndürür"""
    existing_indices = set()
    
    if not DAILY_DATA_DIR.exists():
        return existing_indices
    
    # Tüm sembol klasörlerini tara
    for symbol_dir in DAILY_DATA_DIR.iterdir():
        if not symbol_dir.is_dir() or symbol_dir.name == "gemini":
            continue
        
        # Her sembol altındaki disclosure klasörlerini tara
        for disclosure_dir in symbol_dir.iterdir():
            if not disclosure_dir.is_dir():
                continue
            
            try:
                disclosure_index = int(disclosure_dir.name)
                # JSON dosyası varsa bu bildirim zaten indirilmiş demektir
                json_path = disclosure_dir / f"{disclosure_index}_detail.json"
                if json_path.exists():
                    existing_indices.add(disclosure_index)
            except ValueError:
                # Klasör adı sayı değilse atla
                continue
    
    return existing_indices

# ==========================
# MAIN
# ==========================

def main():
    print("=" * 80)
    print("KAP SÜREKLİ VERİ TOPLAMA PİPELİNE (10 DK ARAYLA)")
    print("=" * 80)
    print(f"Çıktı klasörü: daily_data_kap/{{symbol}}/{{disclosureIndex}}/")
    print("=" * 80)

    while True:
        try:
            target_date = datetime.now().strftime("%Y-%m-%d")
            print(f"\n[{datetime.now().strftime('%H:%M:%S')}] Döngü başlıyor. Hedef tarih: {target_date}")
            
            # Run the daily fetch logic
            run_daily_cycle(target_date)
            
            print(f"\n[{datetime.now().strftime('%H:%M:%S')}] Döngü tamamlandı. 10 dakika bekleniyor...")
        except Exception as e:
            print(f"\n[CRITICAL ERROR] Döngüde hata oluştu: {e}")
            print("10 dakika sonra tekrar denenecek...")
            
        time.sleep(300)  # 5 dakika bekle

def run_daily_cycle(target_date):
    # Önce yerel olarak zaten indirilmiş bildirimleri tespit et
    print("\n[INFO] Yerel olarak mevcut bildirimler kontrol ediliyor...")
    existing_indices = get_existing_disclosure_indices()
    print(f"[INFO] {len(existing_indices)} bildirim zaten mevcut")
    
    # Bildirimleri bir kez çek (tüm semboller için)
    print(f"\n[INFO] {target_date} tarihindeki TÜM bildirimler çekiliyor...")
    
    all_disclosures = fetch_disclosures_for_symbol("ALL", "", target_date)
    
    if not all_disclosures:
        print(f"\n[WARN] {target_date} tarihinde hiç bildirim bulunamadı!")
        return
    
    print(f"\n[INFO] API'den toplam {len(all_disclosures)} bildirim bulundu")
    
    # Zaten indirilmiş olanları filtrele
    new_disclosures = [
        disc for disc in all_disclosures 
        if int(disc.get("disclosureIndex", 0)) not in existing_indices
    ]
    
    skipped_count = len(all_disclosures) - len(new_disclosures)
    print(f"[INFO] {skipped_count} bildirim zaten mevcut (atlandı)")
    print(f"[INFO] {len(new_disclosures)} yeni bildirim işlenecek")
    
    if not new_disclosures:
        print("\n[INFO] İşlenecek yeni bildirim yok!")
        return
    
    # Sınıf bazında özet (sadece yeni bildirimler için)
    class_counts = {}
    for disc in new_disclosures:
        cls = disc.get("top_level_class", "UNKNOWN")
        class_counts[cls] = class_counts.get(cls, 0) + 1
    
    print("\n[INFO] Yeni bildirimlerin sınıf dağılımı:")
    for cls, count in sorted(class_counts.items()):
        print(f"       {cls}: {count} bildirim")
    
    # Her bildirim için dosyaları indir
    print("\n" + "=" * 80)
    print("YENİ BİLDİRİMLER İNDİRİLİYOR")
    print("=" * 80)
    
    for i, disclosure in enumerate(new_disclosures, 1):
        print(f"\n[{i}/{len(new_disclosures)}]", end=" ")
        try:
            process_single_disclosure(disclosure)
        except Exception as e:
            symbol = disclosure.get("symbol", "?")
            disc_idx = disclosure.get("disclosureIndex", "?")
            print(f"[ERROR] {symbol} {disc_idx} işlenirken hata: {e}")
    
    print("\n" + "=" * 80)
    print("TAMAMLANDI!")
    print("=" * 80)
    print(f"Toplam {len(new_disclosures)} yeni bildirim işlendi")
    print(f"Klasör: {DAILY_DATA_DIR}")
    print("=" * 80)

if __name__ == "__main__":
    main()
