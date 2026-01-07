import yfinance as yf
import pandas as pd

# Not: Google Finance API'si yıllar önce kapatıldığı için 
# Python dünyasında standart olarak Yahoo Finance (yfinance) kullanılır.
# Google Finance sitesindeki verilerin aynısına erişim sağlar.

def fetch_asels_prices():
    # BIST hisseleri için sonuna .IS eklenir (ASELS.IS)
    ticker = "ASELS.IS"
    print(f"{ticker} için son 1 aylık veriler çekiliyor (Kaynak: Yahoo Finance)...")
    
    # 1 aylık veri çek
    stock = yf.Ticker(ticker)
    
    # interval='1d' (günlük), period='1mo' (1 aylık)
    # Alternatifler: period='1y', 'ytd', 'max'
    hist = stock.history(period="1mo", interval="1d")
    
    if hist.empty:
        print("Veri çekilemedi. İnternet bağlantınızı kontrol edin.")
        return

    # Veriyi düzenle ve yazdır
    pd.set_option('display.max_rows', None)
    pd.set_option('display.max_columns', None)
    pd.set_option('display.width', 1000)
    
    # Sadece temel sütunları alalım
    clean_data = hist[['Open', 'High', 'Low', 'Close', 'Volume']].copy()
    
    # Sütun isimlerini Türkçeleştir
    clean_data.columns = ['Açılış', 'Yüksek', 'Düşük', 'Kapanış', 'Hacim']
    
    print("\n--- ASELSAN (Son 1 Ay) ---")
    print(clean_data)
    print("\n")
    
    # Anlık (Son) Fiyat
    last_price = clean_data.iloc[-1]['Kapanış']
    print(f"Son Kapanış Fiyatı: {last_price:.2f} TL")

if __name__ == "__main__":
    try:
        fetch_asels_prices()
    except Exception as e:
        print(f"Hata oluştu: {e}")
        print("Lütfen 'pip install yfinance pandas' komutu ile kütüphanelerin yüklü olduğundan emin olun.")
