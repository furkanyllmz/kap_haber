# KAP Haber & Analiz Platformu (KAP Projesi)

Bu proje, KAP (Kamuyu Aydınlatma Platformu) bildirimlerini anlık olarak takip eden, analiz eden ve modern bir web arayüzünde sunan kapsamlı bir finansal veri platformudur. Ayrıca Midas API entegrasyonu ile BIST hisselerinin canlı fiyat verilerini sunar.

## Proje Mimarisi

Sistem 3 ana bileşenden oluşur:

### 1. Python Data & Analysis Service (`main_api.py`, `midas.py`)
- **Görevi**:
    - Midas API üzerinden her dakika canlı hisse fiyatlarını çeker.
    - MongoDB veritabanına (`kap_news` veritabanı, `prices` koleksiyonu) fiyat verilerini yazar.
    - KAP haberlerini analiz eder ve işler (Gemini AI entegrasyonu ile).
    - Arka planda çalışarak veri sürekliliğini sağlar.
- **Teknolojiler**: Python, FastAPI, Requests, PyMongo.

### 2. .NET Backend API (`dotnet-backend/KapProjeBackend`)
- **Görevi**:
    - Frontend için RESTful API sağlar.
    - MongoDB'den verileri okuyarak frontend'e sunar.
    - Endpointler:
        - `/api/news`: Haberleri listeler.
        - `/api/prices`: Tüm hisse fiyatlarını getirir.
        - `/api/prices/ticker/{ticker}`: Belirli bir hissenin fiyatını getirir.
- **Teknolojiler**: .NET 9.0, ASP.NET Core, MongoDB Driver.

### 3. Frontend Web Uygulaması (`kap-frontend`)
- **Görevi**:
    - Kullanıcıya modern ve responsive bir arayüz sunar.
    - Haber akışı (`FeedView`), Şirketler listesi (`CompaniesView`) ve Detay sayfalarını içerir.
    - Canlı "Yükselenler" ticker'ı ve şirket logolarını görüntüler.
- **Teknolojiler**: React, TypeScript, Tailwind CSS, Vite.

## Kurulum ve Çalıştırma

Projeyi çalıştırmak için aşağıdaki adımları takip edin.

### Gereksinimler
- Python 3.10+
- .NET 9.0 SDK
- Node.js & npm
- MongoDB (Yerel veya Remote)

### 1. Python Servisini Başlatma
Kök dizinde:
```bash
# Sanal ortamı aktif et
source .venv/bin/activate  # veya virtualenv nerede kuruluysa

# Bağımlılıkları yükle (eğer yüklü değilse)
pip install -r requirements.txt

# API'yi başlat
python3 main_api.py
```
*Not: Bu servis arka planda Midas verilerini çekmeye başlayacaktır.*

### 2. .NET Backend'i Başlatma
```bash
cd dotnet-backend/KapProjeBackend

# Bağımlılıkları yükle ve derle
dotnet restore
dotnet build

# Uygulamayı başlat
dotnet run
```
*Backend varsayılan olarak `http://localhost:5296` adresinde çalışacaktır.*

### 3. Frontend'i Başlatma
```bash
cd kap-frontend

# Bağımlılıkları yükle
npm install

# Geliştirme sunucusunu başlat
npm run dev
```
*Frontend varsayılan olarak `http://localhost:5173` (veya benzeri) adresinde açılacaktır.*

## Özellikler
- **Canlı Veri**: Midas entegrasyonu ile anlık fiyat takibi.
- **Akıllı Haberler**: Şirket bazlı haber filtreleme ve AI destekli özetler.
- **Modern Arayüz**: Dark mode destekli, mobil uyumlu React arayüzü.
- **Dinamik Grafikler**: TradingView altyapısı ile teknik analiz grafikleri (Harici HTML dosyaları ile).

## Notlar
- `.env` dosyasında gerekli API anahtarları (MongoURI, Gemini Key vb.) tanımlanmalıdır.
- `chroma_kap_memory` klasörü yerel vektör veritabanını tutar ve git'e dahil edilmez.
