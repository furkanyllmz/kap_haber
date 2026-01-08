#!/bin/bash
set -e

echo ">>> Server Setup Başlıyor..."

# 1. Update and Install Dependencies
apt-get update -y
apt-get install -y python3-pip python3-venv mongodb curl wget

# Start MongoDB Service
systemctl enable mongodb
systemctl start mongodb

# Install .NET 8 SDK
echo ">>> .NET 8 SDK kuruluyor..."
if ! command -v dotnet &> /dev/null; then
    wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb
    apt-get update
    apt-get install -y dotnet-sdk-8.0
fi

# Install Node.js 20
echo ">>> Node.js 20 kuruluyor..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
fi

# Install serve globally for frontend
npm install -g serve

# 2. Create Virtual Environment
echo ">>> Virtual Environment oluşturuluyor..."
python3 -m venv /root/daily_data_kap_2/venv


# 3. Install Dependencies
echo ">>> Kütüphaneler kuruluyor..."
/root/daily_data_kap_2/venv/bin/pip install -r /root/daily_data_kap_2/requirements.txt

# 4. Build Frontend
echo ">>> Frontend build ediliyor..."
cd /root/daily_data_kap_2/kap-frontend
npm install
npm run build
cd /root/daily_data_kap_2

# 5. Create Service Files
echo ">>> Servis dosyaları oluşturuluyor..."

# Pipeline Service
cat > /etc/systemd/system/kap-pipeline.service <<EOF
[Unit]
Description=KAP Daily Data Pipeline
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/daily_data_kap_2
ExecStart=/root/daily_data_kap_2/venv/bin/python3 /root/daily_data_kap_2/daily_kap_pipeline.py
Environment="PYTHONUNBUFFERED=1"
Restart=always
RestartSec=60

[Install]
WantedBy=multi-user.target
EOF

# News Analyze Service
cat > /etc/systemd/system/kap-news-analyze.service <<EOF
[Unit]
Description=KAP News Analyzer (Web & Twitter)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/daily_data_kap_2
ExecStart=/root/daily_data_kap_2/venv/bin/python3 /root/daily_data_kap_2/news_analyze.py
Environment="PYTHONUNBUFFERED=1"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Twitter Bot Service (Twikit version)
cat > /etc/systemd/system/kap-twitterbot.service <<EOF
[Unit]
Description=KAP Twitter Bot (Twikit - API'siz)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/daily_data_kap_2
ExecStart=/root/daily_data_kap_2/venv/bin/python3 /root/daily_data_kap_2/twitterbot_twikit.py
Environment="PYTHONUNBUFFERED=1"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Python API Manager Service
cat > /etc/systemd/system/kap-api.service <<EOF
[Unit]
Description=KAP Bot Manager API (Python)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/daily_data_kap_2
ExecStart=/root/daily_data_kap_2/venv/bin/uvicorn main_api:app --host 0.0.0.0 --port 8000
Environment="PYTHONUNBUFFERED=1"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# .NET Backend Service
cat > /etc/systemd/system/kap-backend.service <<EOF
[Unit]
Description=KAP .NET Backend API
After=network.target mongodb.service

[Service]
Type=simple
User=root
WorkingDirectory=/root/daily_data_kap_2/dotnet-backend/KapProjeBackend
ExecStart=/usr/bin/dotnet run --urls "http://0.0.0.0:5296"
Environment="ASPNETCORE_ENVIRONMENT=Production"
Environment="DOTNET_CLI_TELEMETRY_OPTOUT=1"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Frontend Service
cat > /etc/systemd/system/kap-frontend.service <<EOF
[Unit]
Description=KAP Frontend (Vite Build)
After=network.target kap-backend.service

[Service]
Type=simple
User=root
WorkingDirectory=/root/daily_data_kap_2/kap-frontend
ExecStart=/usr/bin/serve -s dist -l 3000
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# 6. Start Services
echo ">>> Servisler başlatılıyor..."
systemctl daemon-reload

# Core servisler - Otomatik başlat
systemctl enable kap-api
systemctl enable kap-backend
systemctl enable kap-frontend
systemctl enable kap-news-analyze

systemctl restart kap-api
systemctl restart kap-backend
systemctl restart kap-frontend
systemctl restart kap-news-analyze

# Opsiyonel servisler - Manuel başlatılır
# systemctl restart kap-pipeline
# systemctl restart kap-twitterbot

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║       ✅ KURULUM TAMAMLANDI!                 ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "📌 Çalışan Servisler:"
echo "   • Python API:   http://localhost:8000"
echo "   • .NET Backend: http://localhost:5296"
echo "   • Frontend:     http://localhost:3000"
echo "   • News Analyze: Arka planda çalışıyor"
echo ""
echo "📋 Servis Durumlarını Kontrol Et:"
echo "   systemctl status kap-api kap-backend kap-frontend"
echo ""
echo "🔄 Diğer Servisleri Başlatmak İçin:"
echo "   systemctl start kap-twitterbot"
echo "   systemctl start kap-pipeline"
echo ""

