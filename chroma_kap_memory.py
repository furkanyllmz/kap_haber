import os
import re
import json
import hashlib
from datetime import datetime
from typing import Dict, Any, List, Optional, Tuple

# ✅ BGE-M3 (SentenceTransformers) - Load FIRST to avoid gRPC/Torch lock on Mac
from sentence_transformers import SentenceTransformer

import chromadb
from chromadb.config import Settings


# -----------------------------
# 1) Model (BGE-M3) + normalize
# -----------------------------
def load_embedder(model_name: str = "BAAI/bge-m3") -> SentenceTransformer:    # BGE-M3 multilingual, retrieval için güçlü.
    # sentence-transformers otomatik indirir.
    return SentenceTransformer(model_name)


def embed_text(embedder: SentenceTransformer, text: str) -> List[float]:
    # normalize_embeddings=True => cosine için stabil
    vec = embedder.encode(
        text,
        normalize_embeddings=True,
        show_progress_bar=False
    )
    return vec.tolist()


# -----------------------------
# 2) "Signal text" (gürültüyü azalt)
# -----------------------------
def build_signal_text(kap_json: Dict[str, Any], max_chars: int = 1600) -> str:
    """
    Embedding'e TAM metni basmak yerine "signal" üret:
    subject + summary + fullText'in ilk kısmı + içindeki para/tutar/currency satırları.
    """
    subject = (kap_json.get("subject") or "").strip()
    summary = (kap_json.get("summary") or "").strip()
    full_text = (kap_json.get("fullText") or "").strip()

    # Full text'i kırp
    full_head = full_text[:max_chars]

    # Parasal satırları çek (KAP'ta tutar cümleleri kritik)
    money_lines = []
    for line in full_text.splitlines():
        if re.search(r"\b(USD|EUR|TL|TRY)\b", line, re.IGNORECASE) or re.search(r"\b[\d\.\,]{3,}\b", line):
            if len(line.strip()) >= 12:
                money_lines.append(line.strip())
        if len(money_lines) >= 10:
            break

    money_block = "\n".join(money_lines[:10])

    # Birleştir
    parts = []
    if subject:
        parts.append(f"SUBJECT: {subject}")
    if summary:
        parts.append(f"SUMMARY: {summary}")
    if full_head:
        parts.append(f"TEXT_HEAD: {full_head}")
    if money_block:
        parts.append(f"KEY_NUMBERS_LINES:\n{money_block}")

    return "\n\n".join(parts).strip()


# -----------------------------
# 3) Fingerprint (bayat/şablon tespiti)
# -----------------------------
def extract_fingerprint(text: str) -> str:
    """
    Basit ama etkili: event_type, currency, amount bucket, önemli anahtar kelimeler.
    """
    t = text.lower()

    # event_type kaba
    if "bedelsiz" in t or "sermaye artırımı" in t or "rüçhan" in t:
        event_type = "CAPITAL_ACTION"
    elif "bölünme" in t or "birleşme" in t or "devral" in t or "spin" in t:
        event_type = "CORPORATE_ACTION"
    elif "geri al" in t or "pay geri al" in t:
        event_type = "BUYBACK"
    elif "sözleşme" in t or "ihale" in t:
        event_type = "BIG_CONTRACT"
    else:
        event_type = "OTHER"

    # currency
    cur = "NONE"
    if "usd" in t:
        cur = "USD"
    elif "eur" in t:
        cur = "EUR"
    elif "try" in t or " tl" in t:
        cur = "TRY"

    # amount bucket (çok kaba)
    # 82,112,500.00 gibi sayıları yakalayıp en büyüğünü al
    nums = []
    for m in re.finditer(r"(\d[\d\.\,]{2,})(?:\s?)(usd|eur|try|tl)?", t):
        raw = m.group(1)
        # normalize: "82,112,500.00" -> 82112500
        cleaned = raw.replace(".", "").replace(",", "")
        if cleaned.isdigit():
            nums.append(int(cleaned))
    amt = max(nums) if nums else 0

    # bucket
    if amt <= 0:
        bucket = "NA"
    elif amt < 10_000_000:
        bucket = "LT10M"
    elif amt < 50_000_000:
        bucket = "10-50M"
    elif amt < 100_000_000:
        bucket = "50-100M"
    else:
        bucket = "GT100M"

    # quality hints
    hints = []
    for kw in ["nato", "savunma", "ssb", "yurt dışı", "abd", "avrupa", "spk onayı", "tescil", "tamamlandı"]:
        if kw in t:
            hints.append(kw.replace(" ", "_"))
    hint_str = "+".join(hints[:4]) if hints else "none"

    return f"{event_type}|{cur}|{bucket}|{hint_str}"


def stable_id(ticker: str, published_at: str, subject: str) -> str:
    s = f"{ticker}|{published_at}|{subject}".encode("utf-8")
    return hashlib.sha1(s).hexdigest()


# -----------------------------
# 4) Chroma tek koleksiyon
# -----------------------------
class KapMemory:
    def __init__(self, persist_dir: str = "./chroma_kap_memory", collection_name: str = "kap_memory"):
        self.client = chromadb.PersistentClient(
            path=persist_dir,
            settings=Settings(anonymized_telemetry=False)
        )
        self.col = self.client.get_or_create_collection(
            name=collection_name,
            metadata={"hnsw:space": "cosine"}  # cosine için
        )

    def add_kap(
        self,
        doc_id: str,
        text_for_embedding: str,
        raw_text_for_store: str,
        metadata: Dict[str, Any],
        embedding: List[float],
    ) -> None:
        try:
            self.col.add(
                ids=[doc_id],
                documents=[raw_text_for_store],    # LLM'e bağlam olacak metin
                embeddings=[embedding],            # vector
                metadatas=[metadata],              # ticker, date, fingerprint...
            )
        except Exception as e:
            print(f"[WARN] Memory add_kap error (ignored): {e}")

    def query_topk(
        self,
        query_embedding: List[float],
        ticker: str,
        k: int = 3
    ) -> Dict[str, Any]:
        # ✅ ticker filtresi burada
        try:
            return self.col.query(
                query_embeddings=[query_embedding],
                n_results=k,
                where={"ticker": ticker}
            )
        except Exception as e:
            print(f"[WARN] Memory query_topk error (return empty): {e}")
            return {}


# -----------------------------
# 5) Duplicate gate (LLM'e gitmeden ele)
# -----------------------------
PROCESS_WORDS = [
    "güncelleme", "tescil", "tamamlan", "duyuru metni", "ek açıklama",
    "bildiril", "işbu açıklama", "süreç", "sonucu", "onaylan"
]
BINDING_WORDS = ["imzaland", "kesinleş", "ihale kazan"]


def looks_like_process_update(text: str) -> bool:
    t = text.lower()
    return any(w in t for w in PROCESS_WORDS)


def has_binding_language(text: str) -> bool:
    t = text.lower()
    return any(w in t for w in BINDING_WORDS)


def duplicate_gate(top1_sim: float, new_text: str, top1_text: str) -> bool:
    """
    True => bayat/tekrar => direkt ele
    """
    # 1) aşırı benzerlik
    if top1_sim < 0.92:
        return False

    # 2) süreç/güncelleme dili varsa
    if not looks_like_process_update(new_text):
        return False

    # 3) yeni bağlayıcılık yoksa (çok kaba)
    # (İstersen burada tutar/currency karşılaştırması da ekleriz)
    if has_binding_language(new_text) and not has_binding_language(top1_text):
        # eski "başvuru" yeni "imzalandı" gibi ise bayat sayma
        return False

    return True


# -----------------------------
# 6) Örnek kullanım: yeni KAP geldiğinde
# -----------------------------
def handle_new_kap(
    embedder: SentenceTransformer,
    memory: KapMemory,
    kap_json: Dict[str, Any],
    financials_json: Optional[Dict[str, Any]] = None,
    topk: int = 3
) -> Tuple[Dict[str, Any], Dict[str, Any]]:
    """
    Döndürür:
      - retrieval_pack: LLM'e gönderilecek topk context + similarity + fingerprint
      - store_pack: DB'ye yazmak için metadata vs.
    """
    ticker = (kap_json.get("ticker") or "").strip().upper()
    if not ticker:
        raise ValueError("kap_json.ticker boş. (Senin pipeline'da ticker'ı zaten çıkarıyorsun.)")

    published_at = (kap_json.get("published_at") or "").strip()  # ISO beklenir
    subject = (kap_json.get("subject") or "").strip()
    full_text = (kap_json.get("fullText") or "").strip()

    # Embedding için signal text
    signal_text = build_signal_text(kap_json)

    # Embedding
    q_emb = embed_text(embedder, signal_text)

    # TopK (aynı ticker filtresiyle)
    res = memory.query_topk(q_emb, ticker=ticker, k=topk)

    # Chroma distances: cosine distance (0 daha yakın), similarity = 1 - distance
    ctx_items = []
    if res and res.get("documents") and res["documents"][0]:
        docs = res["documents"][0]
        metas = res["metadatas"][0]
        dists = res["distances"][0] if "distances" in res else [None] * len(docs)

        for doc, meta, dist in zip(docs, metas, dists):
            sim = None
            if dist is not None:
                sim = 1.0 - float(dist)
            ctx_items.append({
                "published_at": meta.get("published_at"),
                "subject": meta.get("subject"),
                "similarity": sim,
                "fingerprint": meta.get("fingerprint"),
                "text": doc[:1200]  # LLM context için kırp
            })

    # Duplicate gate: top1 ile ele
    if ctx_items:
        top1 = ctx_items[0]
        top1_sim = float(top1["similarity"] or 0.0)
        top1_text = top1["text"] or ""
        is_dup = duplicate_gate(top1_sim, full_text, top1_text)
    else:
        is_dup = False

    fp = extract_fingerprint(signal_text)
    doc_id = stable_id(ticker, published_at, subject)

    retrieval_pack = {
        "ticker": ticker,
        "NEW_KAP": {
            "published_at": published_at,
            "subject": subject,
            "text": full_text[:4000],
            "fingerprint": fp,
            "financials_json": financials_json
        },
        "TOPK_CONTEXT": ctx_items,       # top3
        "DUPLICATE_GATE": is_dup         # True ise direkt [] diyebilirsin
    }

    store_pack = {
        "doc_id": doc_id,
        "ticker": ticker,
        "published_at": published_at,
        "subject": subject,
        "fingerprint": fp,
        "signal_text": signal_text,
        "raw_store_text": f"{published_at}\n{subject}\n\n{full_text}"[:8000],
        "embedding": q_emb
    }

    return retrieval_pack, store_pack


# -----------------------------
# 7) DB'ye ekleme (her durumda)
# -----------------------------
def store_kap(memory: KapMemory, store_pack: Dict[str, Any]) -> None:
    meta = {
        "ticker": store_pack["ticker"],
        "published_at": store_pack["published_at"],
        "subject": store_pack["subject"],
        "fingerprint": store_pack["fingerprint"],
    }
    memory.add_kap(
        doc_id=store_pack["doc_id"],
        text_for_embedding=store_pack["signal_text"],
        raw_text_for_store=store_pack["raw_store_text"],
        metadata=meta,
        embedding=store_pack["embedding"],
    )
    from datetime import datetime, timedelta

def get_ticker_frequency(memory, ticker, days=7):
    if not memory or not ticker:
        return 0
    
    try:
        cutoff_date = datetime.now() - timedelta(days=days)
        
        # Metadataları VE döküman içeriklerini (text) getir
        results = memory.collection.get(
            where={"ticker": ticker},
            include=["metadatas", "documents"] 
        )
        
        count = 0
        
        # Ticari Anahtar Kelimeler (Bunlar varsa SAY)
        business_keywords = [
            "yeni iş", "sözleşme", "ihale", "sipariş", 
            "satış", "proje", "anlaşma", "kabul"
        ]
        
        # Yasaklı Kelimeler (Bunlar varsa SAYMA)
        ignore_keywords = [
            "genel kurul", "devre kesici", "vbts", 
            "kayıtlı sermaye", "adres", "tahvil", "bono",
            "kira sertifikası", "derecelendirme", "atama"
        ]

        if results and results['metadatas']:
            # results['metadatas'] ve results['documents'] aynı sıradadır
            for i, meta in enumerate(results['metadatas']):
                pub_str = meta.get('published_at', '')
                
                # 1. Tarih Kontrolü
                if pub_str:
                    try:
                        pub_dt = datetime.fromisoformat(pub_str[:10]) 
                        if pub_dt < cutoff_date:
                            continue # Tarih eskiyse geç
                    except:
                        continue
                
                # 2. İçerik Analizi (Smart Filter)
                # Chroma'dan gelen metni al ve küçült
                doc_text = results['documents'][i].lower()
                
                # Önce yasaklı kelime var mı diye bak (Varsa sayma)
                if any(bad_word in doc_text for bad_word in ignore_keywords):
                    continue
                
                # Sonra ticari kelime var mı diye bak (Varsa say)
                if any(good_word in doc_text for good_word in business_keywords):
                    count += 1
                    
        return count

    except Exception as e:
        print(f"[WARN] Frekans hesabı hatası: {e}")
        return 0

# -----------------------------
# Minimal demo
# -----------------------------
if __name__ == "__main__":
    embedder = load_embedder("sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2")
    memory = KapMemory(persist_dir="./chroma_kap_memory", collection_name="kap_memory")

    # Örnek: gemini json formatın (seninkiyle uyumlu alanlar)
    kap_json = {
        "ticker": "ASELS",
        "published_at": "2025-12-26T10:15:00+03:00",
        "subject": "Yeni İş İlişkisi",
        "summary": "ABD merkezli şirket ile sözleşme imzalandı.",
        "fullText": "Şirketimiz ile ... 82,112,500.00 USD bedel ile sözleşme imzalanmıştır..."
    }

    retrieval, store_pack = handle_new_kap(embedder, memory, kap_json, financials_json=None, topk=3)

    print(json.dumps(retrieval, ensure_ascii=False, indent=2))

    # Alarm çıksın/çıkmasın hafızaya yaz (önerilen)
    store_kap(memory, store_pack)