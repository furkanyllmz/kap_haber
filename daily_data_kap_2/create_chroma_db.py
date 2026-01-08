# create_chroma_db.py
import os, json, glob
from datetime import datetime

from chroma_kap_memory import load_embedder, KapMemory, handle_new_kap, store_kap

DEC_DIR = "./embedding/gemini"  # <- Root embeddings folder
PERSIST_DIR = "./chroma_kap_memory"
COLLECTION = "kap_memory"

def safe_load_json(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return json.load(f)
    except:
        return None

def guess_published_at(obj, fallback_dt):
    # Eğer json’da published_at yoksa fallback
    v = obj.get("published_at") or obj.get("publishedAt") or obj.get("date")
    
    # 1. published_at varsa kullan
    if isinstance(v, str) and v.strip():
        return v.strip()
    
    # 2. publishDate (DD.MM.YYYY HH:MM:SS) varsa parse et
    pdate = obj.get("publishDate")
    if isinstance(pdate, str) and pdate.strip():
        try:
             # Parse "30.12.2025 19:10:53"
            dt_obj = datetime.strptime(pdate.strip(), "%d.%m.%Y %H:%M:%S")
            return dt_obj.strftime("%Y-%m-%dT%H:%M:%S+03:00")
        except:
            pass

    # 3. Hiçbiri yoksa fallback (dosya tarihi)
    return fallback_dt.strftime("%Y-%m-%dT%H:%M:%S+03:00")

def get_symbols_from_json(obj):
    # symbol, ticker, stockCode vb. alanlardan çek
    # Öncelik sırası: symbol > ticker > stockCode
    raw_symbol = None
    for k in ["symbol", "ticker", "stockCode", "hisse"]:
        if k in obj and isinstance(obj[k], str) and obj[k].strip():
            raw_symbol = obj[k].strip()
            break
    
    if not raw_symbol:
        return []

    # Virgülle ayrılmış olabilir: "A1CAP, AKDFA, AKTIF"
    # Hepsini ayır, boşlukları temizle, upper yap
    parts = [s.strip().upper() for s in raw_symbol.split(',') if s.strip()]
    return list(set(parts)) # unique

def main():
    embedder = load_embedder("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")
    memory = KapMemory(persist_dir=PERSIST_DIR, collection_name=COLLECTION)

    # --- CHECKPOINT LOGIC ---
    CHECKPOINT_FILE = "processed_files.txt"
    processed_set = set()
    if os.path.exists(CHECKPOINT_FILE):
        with open(CHECKPOINT_FILE, "r", encoding="utf-8") as f:
            for line in f:
                processed_set.add(line.strip())
    
    # Ayrıca veritabanındaki mevcut ID'leri de çekelim (Crash öncesi işlenenleri atlamak için)
    try:
        existing_ids = set(memory.col.get()["ids"])
        print(f"[RESUME] Found {len(existing_ids)} IDs already in ChromaDB.")
    except Exception as e:
        print(f"[WARN] Could not fetch existing IDs: {e}")
        existing_ids = set()

    print(f"[RESUME] Found {len(processed_set)} completed files in log. They will be skipped.")
    # ------------------------

    print(f"[BOOT] Scanning {DEC_DIR} recursively for JSON files...")
    
    # Recursive glob
    files = glob.glob(os.path.join(DEC_DIR, "**/*.json"), recursive=True)
    
    print(f"[BOOT] Found {len(files)} JSON files.")

    total_files = 0
    total_embeddings = 0
    skipped_existing = 0

    from chroma_kap_memory import stable_id # ID hesabı için import

    for fp in files:
        # 1. Text dosya kontrolü (Hızlı)
        if fp in processed_set:
            continue
        
        total_files += 1
        obj = safe_load_json(fp)
        if not obj:
            continue

        fallback_dt = datetime.fromtimestamp(os.path.getmtime(fp))
        
        # JSON içinden sembolleri çek
        tickers = get_symbols_from_json(obj)
        
        # Ortak veriler
        subject = obj.get("subject") or obj.get("title") or ""
        summary = obj.get("summary") or obj.get("disclosure_summary") or ""
        full_text = obj.get("fullText") or obj.get("disclosure_text") or ""
        published_at = guess_published_at(obj, fallback_dt)

        if not tickers or not (subject or summary or full_text):
            continue
        
        success_any = False
        all_skipped = True

        for ticker in tickers:
            # 2. ID kontrolü (Daha güvenli, crash durumları için)
            # stable_id hesapla
            did = stable_id(ticker, published_at, subject)
            if did in existing_ids:
                skipped_existing += 1
                success_any = True # Zaten var, dosya işlendi sayabiliriz
                continue

            all_skipped = False
            kap_json = {
                "ticker": ticker,
                "published_at": published_at,
                "subject": subject,
                "summary": summary,
                "fullText": full_text,
            }

            try:
                retrieval, store_pack = handle_new_kap(
                    embedder, memory, kap_json,
                    financials_json=None,
                    topk=3
                )
                store_kap(memory, store_pack)
                total_embeddings += 1
                success_any = True
                # İşlendikten sonra kümeye ekle ki tekrar sormayalım
                existing_ids.add(did) 
            except Exception as e:
                print(f"[WARN] Failed to process {ticker} in {os.path.basename(fp)}: {e}")

        # Başarıyla işlendiyse (veya zaten varsa) checkpoint'e ekle
        if success_any:
            with open(CHECKPOINT_FILE, "a", encoding="utf-8") as f:
                f.write(fp + "\n")

        # Daha sık progress
        if total_files % 10 == 0:
            print(f"[PROGRESS] Files checked: {total_files}, New Embeddings: {total_embeddings}, Skipped Existing: {skipped_existing} (Last: {os.path.basename(fp)})")

    print(f"[DONE] Total Files Processed: {total_files}")
    print(f"[DONE] Total Embeddings Inserted: {total_embeddings}")
    print(f"[DB] Persisted at {PERSIST_DIR} / collection={COLLECTION}")

if __name__ == "__main__":
    main()
