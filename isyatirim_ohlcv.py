"""
İş Yatırım OHLCV Downloader - Standalone Script
-----------------------------------------------
Bu script:
1. 'symbols.html' dosyasını okuyarak hisse sembollerini çıkarır.
2. İş Yatırım API'sini kullanarak bu semboller için OHLCV (Günlük) verilerini çeker.
3. 'ohlcv/' klasörüne CSV formatında kaydeder.
4. Incremental çalışır: Sadece eksik günleri indirir.

Kullanım:
    python3 isyatirim_ohlcv.py
"""

import os
import sys
import pandas as pd
import logging
import time
import random
from pathlib import Path
from datetime import datetime, timedelta
from bs4 import BeautifulSoup
from typing import List, Optional, Tuple

# Logging ayarları
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s',
    datefmt='%H:%M:%S'
)
logger = logging.getLogger("OHLCV_Downloader")

# Ayarlar
SYMBOLS_FILE = "symbols.html"
OUTPUT_DIR = "ohlcv"
START_DATE_DEFAULT = "01-01-2025"

# İş Yatırım Kütüphanesi Kontrolü
try:
    from isyatirimhisse import fetch_stock_data
except ImportError:
    logger.error("isyatirimhisse kütüphanesi yüklü değil. Lütfen 'pip install isyatirimhisse' komutunu çalıştırın.")
    sys.exit(1)

def get_symbols_from_html(html_file: str) -> List[str]:
    """HTML dosyasından sembolleri çıkarır."""
    if not os.path.exists(html_file):
        logger.error(f"{html_file} bulunamadı!")
        return []
    
    try:
        with open(html_file, "r", encoding="utf-8") as f:
            soup = BeautifulSoup(f, "html.parser")
            
        options = soup.find_all("option")
        symbols = []
        for opt in options:
            val = opt.get("value")
            if val and val != "Hisse Seçiniz...":
                symbols.append(val.strip())
        
        # Remove empty or invalid symbols (bazen IDler gelebilir)
        symbols = [s for s in symbols if s and len(s) < 10]
        
        # Unique and sorted
        return sorted(list(set(symbols)))
        
    except Exception as e:
        logger.error(f"HTML okuma hatası: {e}")
        return []

def standardize_ohlcv_dataframe(df: pd.DataFrame, symbol: str) -> pd.DataFrame:
    """Veriyi standart formata (date, open, high, low, close, volume) çevirir."""
    if df is None or df.empty:
        return pd.DataFrame()
    
    df = df.copy()
    
    # İş Yatırım kolon isimleri
    column_mapping = {
        'Tarih': 'date', 'Date': 'date', 'DATE': 'date', 'HGDG_TARIH': 'date',
        'Açılış': 'open', 'Open': 'open', 'OPEN': 'open', 'HGDG_AOF': 'open', # AOF bazen ortalama olabilir ama isyatirimda Acilis verisi yoksa kapanis kullanilabilir
        'Yüksek': 'high', 'High': 'high', 'HIGH': 'high', 'HGDG_MAX': 'high',
        'Düşük': 'low', 'Low': 'low', 'LOW': 'low', 'HGDG_MIN': 'low',
        'Kapanış': 'close', 'Close': 'close', 'CLOSE': 'close', 'HGDG_KAPANIS': 'close',
        'Hacim': 'volume', 'Volume': 'volume', 'VOLUME': 'volume', 'HGDG_HACIM': 'volume',
        'HGDG_HS_KODU': 'symbol'
    }
    # Not: isyatirimhisse kütüphanesi genelde 'Date', 'HGDG_HS_KODU', 'HGDG_KAPANIS' vs döndürür.
    # Kütüphane güncellemeleri ile 'Close' gibi de dönebilir.
    
    # Rename columns
    new_cols = {}
    for col in df.columns:
        if col in column_mapping:
            new_cols[col] = column_mapping[col]
    
    df = df.rename(columns=new_cols)
    
    # Check essential columns
    if 'date' not in df.columns:
        return pd.DataFrame()

    # Tarih formatı
    df['date'] = pd.to_datetime(df['date'], errors='coerce')
    df = df.dropna(subset=['date'])
    
    # Eksik kolonları tamamlama
    required_cols = ['open', 'high', 'low', 'close', 'volume']
    for col in required_cols:
        if col not in df.columns:
            # Eğer open yoksa close kullan
            if col == 'open' and 'close' in df.columns:
                df['open'] = df['close']
            # Eğer high/low yoksa close kullan
            elif col in ['high', 'low'] and 'close' in df.columns:
                 df[col] = df['close']
            else:
                df[col] = 0.0

    # Numeric conversion
    for col in required_cols:
         df[col] = pd.to_numeric(df[col], errors='coerce')
            
    df['symbol'] = symbol
    return df[['date', 'open', 'high', 'low', 'close', 'volume', 'symbol']].sort_values('date')

def get_last_date_from_csv(csv_path: str) -> Optional[datetime]:
    """CSV dosyasındaki son tarihi döndürür."""
    if not os.path.exists(csv_path):
        return None
    try:
        df = pd.read_csv(csv_path)
        if 'date' not in df.columns:
            return None
        
        df['date'] = pd.to_datetime(df['date'])
        if df.empty:
            return None
            
        return df['date'].max()
    except:
        return None

def main():
    logger.info("="*60)
    logger.info("İŞ YATIRIM OHLCV İNDİRİCİ BAŞLATILIYOR")
    logger.info("="*60)
    
    # 1. Sembolleri Oku
    logger.info(f"Semboller '{SYMBOLS_FILE}' dosyasından okunuyor...")
    symbols = get_symbols_from_html(SYMBOLS_FILE)
    
    if not symbols:
        logger.error("Hiç sembol bulunamadı! Program sonlandırılıyor.")
        return
        
    logger.info(f"Toplam {len(symbols)} sembol bulundu.")
    
    # 2. Klasör Hazırla
    if not os.path.exists(OUTPUT_DIR):
        os.makedirs(OUTPUT_DIR)
        logger.info(f"'{OUTPUT_DIR}' klasörü oluşturuldu.")
        
    # 3. İndirme Döngüsü
    success = 0
    skipped = 0
    errors = 0
    
    today = datetime.now().date()
    # İş Yatırım formatı: DD-MM-YYYY
    end_date_str = today.strftime("%d-%m-%Y")
    
    for idx, symbol in enumerate(symbols, 1):
        csv_path = os.path.join(OUTPUT_DIR, f"{symbol}_ohlcv.csv")
        
        # Başlangıç tarihi belirle (Incremental)
        last_date = get_last_date_from_csv(csv_path)
        mode = "TAM İNDİRME"
        start_date_str = START_DATE_DEFAULT

        if last_date:
            # Son tarihten bugüne kadar veri var mı?
            last_date_obj = last_date.date()
            if last_date_obj >= today:
                # Zaten güncel
                logger.debug(f"[{idx}/{len(symbols)}] {symbol} GÜNCEL")
                skipped += 1
                continue
                
            # 1 gün sonrasından başlama yerine çakışmalı (overlapping) alıp duplicate silme daha güvenli
            mode = "GÜNCELLEME"
            start_date_obj = last_date_obj # Aynı günden baslat (gün içi veri güncellenmiş olabilir)
            start_date_str = start_date_obj.strftime("%d-%m-%Y")
        
        # Hafta sonu kontrolü vs gerek yok, API boş dönerse boş döner.
        
        logger.info(f"[{idx}/{len(symbols)}] {symbol} - {mode} ({start_date_str} -> {end_date_str})")
        
        try:
            # API İsteği
            data = fetch_stock_data(
                symbols=symbol,
                start_date=start_date_str,
                end_date=end_date_str
            )
            
            std_df = standardize_ohlcv_dataframe(data, symbol)
            
            if not std_df.empty:
                # Kaydetme Mantığı
                if os.path.exists(csv_path) and mode == "GÜNCELLEME":
                    old_df = pd.read_csv(csv_path)
                    old_df['date'] = pd.to_datetime(old_df['date'])
                    
                    combined = pd.concat([old_df, std_df])
                    # Date'e göre duplicate sil, son geleni tut
                    combined = combined.drop_duplicates(subset=['date'], keep='last')
                    combined = combined.sort_values('date')
                    
                    combined.to_csv(csv_path, index=False)
                    logger.info(f"   -> Veri birleştirildi. Toplam: {len(combined)}")
                    
                else:
                    std_df.to_csv(csv_path, index=False)
                    logger.info(f"   -> Dosya oluşturuldu. {len(std_df)} satır.")
                
                success += 1
            else:
                logger.warning(f"   -> Veri boş döndü.")
            
            # Rate limit için kısa bekleme
            time.sleep(0.3)
            
        except Exception as e:
            logger.error(f"   -> HATA: {e}")
            errors += 1
            
    logger.info("="*60)
    logger.info(f"TAMAMLANDI. Başarılı: {success} | Atlanan: {skipped} | Hatalı: {errors}")
    logger.info(f"Veriler '{OUTPUT_DIR}' klasöründe.")

if __name__ == "__main__":
    main()
