#!/bin/bash
set -e

echo ">>> Server Setup Başlıyor..."

# 1. Update and Install Dependencies
apt-get update -y
apt-get install -y python3-pip python3-venv curl wget nginx certbot python3-certbot-nginx gnupg

# Install MongoDB 7.0 from official repo
echo ">>> MongoDB kuruluyor..."
if ! command -v mongod &> /dev/null; then
    curl -fsSL https://www.mongodb.org/static/pgp/server-7.0.asc | gpg -o /usr/share/keyrings/mongodb-server-7.0.gpg --dearmor
    echo "deb [ arch=amd64,arm64 signed-by=/usr/share/keyrings/mongodb-server-7.0.gpg ] https://repo.mongodb.org/apt/ubuntu $(lsb_release -cs)/mongodb-org/7.0 multiverse" | tee /etc/apt/sources.list.d/mongodb-org-7.0.list
    apt-get update
    apt-get install -y mongodb-org
fi

# Start MongoDB Service
systemctl enable mongod
systemctl start mongod

# Install .NET 9 SDK
echo ">>> .NET 9 SDK kuruluyor..."
if ! command -v dotnet &> /dev/null; then
    wget https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb -O packages-microsoft-prod.deb
    dpkg -i packages-microsoft-prod.deb
    rm packages-microsoft-prod.deb
    apt-get update
    apt-get install -y dotnet-sdk-9.0
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
python3 -m venv /root/kap_haber/venv

# 3. Install Dependencies
echo ">>> Kütüphaneler kuruluyor..."
/root/kap_haber/venv/bin/pip install -r /root/kap_haber/requirements.txt

# 4. Build Frontend
echo ">>> Frontend build ediliyor..."
cd /root/kap_haber/kap-frontend
npm install
npm run build
cd /root/kap_haber

# 5. Create Service Files
echo ">>> Servis dosyaları oluşturuluyor..."

# Twitter Bot Service (Twikit version)
cat > /etc/systemd/system/kap-twitterbot.service <<EOF
[Unit]
Description=KAP Twitter Bot (Twikit - API'siz)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/kap_haber
ExecStart=/root/kap_haber/venv/bin/python3 /root/kap_haber/twitterbot_twikit.py
Environment="PYTHONUNBUFFERED=1"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# KAP Analyzer Service
cat > /etc/systemd/system/kap-analyzer.service <<EOF
[Unit]
Description=KAP Gemini Analyzer
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/kap_haber
ExecStart=/root/kap_haber/venv/bin/python3 /root/kap_haber/analyze_kap.py
Environment="PYTHONUNBUFFERED=1"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Telegram Bot Service
cat > /etc/systemd/system/kap-telegram.service <<EOF
[Unit]
Description=KAP Telegram Subscription Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/kap_haber
ExecStart=/root/kap_haber/venv/bin/python3 /root/kap_haber/telegram_bot.py
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
WorkingDirectory=/root/kap_haber
ExecStart=/root/kap_haber/venv/bin/uvicorn main_api:app --host 0.0.0.0 --port 8000
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
WorkingDirectory=/root/kap_haber/dotnet-backend/KapProjeBackend
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
WorkingDirectory=/root/kap_haber/kap-frontend
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
systemctl enable kap-analyzer
systemctl enable kap-telegram

systemctl restart kap-api
systemctl restart kap-backend
systemctl restart kap-frontend
systemctl restart kap-analyzer
systemctl restart kap-telegram

# Opsiyonel servisler - Manuel başlatılır
# systemctl restart kap-twitterbot

# 7. Nginx Configuration for kaphaber.com
echo ">>> Nginx konfigürasyonu yapılıyor..."

# Nginx site config oluştur
cat > /etc/nginx/sites-available/kaphaber <<EOF
server {
    listen 80;
    server_name kaphaber.com www.kaphaber.com;

    # Logging
    access_log /var/log/nginx/kaphaber.access.log;
    error_log /var/log/nginx/kaphaber.error.log;

    # Frontend - Ana site
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }

    # .NET Backend API
    location /api {
        proxy_pass http://localhost:5296/api;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }

    # Dinamik Sitemap (.NET Backend)
    location /sitemap.xml {
        proxy_pass http://localhost:5296/sitemap.xml;
    }

    # Static files (banners, logos, news-images)
    location /banners {
        proxy_pass http://localhost:5296/banners;
    }
    location /logos {
        proxy_pass http://localhost:5296/logos;
    }
    location /news-images {
        proxy_pass http://localhost:5296/news-images;
    }

    # Python API (Admin Panel için)
    location /python-api/ {
        proxy_pass http://localhost:8000/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
EOF

# Symlink oluştur (varsa sil)
rm -f /etc/nginx/sites-enabled/kaphaber
ln -s /etc/nginx/sites-available/kaphaber /etc/nginx/sites-enabled/

# Default site'ı kaldır
rm -f /etc/nginx/sites-enabled/default

# Nginx test ve restart
nginx -t
systemctl restart nginx
systemctl enable nginx

echo ""
echo "╔══════════════════════════════════════════════╗"
echo "║       ✅ KURULUM TAMAMLANDI!                 ║"
echo "╚══════════════════════════════════════════════╝"
echo ""
echo "📌 Çalışan Servisler:"
echo "   • Python API:   http://localhost:8000"
echo "   • .NET Backend: http://localhost:5296"
echo "   • Frontend:     http://localhost:3000"
echo "   • KAP Analyzer: Arka planda çalışıyor"
echo "   • Telegram Bot: Arka planda çalışıyor"
echo "   • Nginx:        http://kaphaber.com"
echo ""
echo "📋 Servis Durumlarını Kontrol Et:"
echo "   systemctl status kap-api kap-backend kap-frontend kap-analyzer kap-telegram nginx"
echo ""
echo "🔒 SSL Sertifikası Almak İçin (ÖNEMLI!):"
echo "   certbot --nginx -d kaphaber.com -d www.kaphaber.com"
echo ""
echo "🔄 Twitter Bot'u Başlatmak İçin:"
echo "   systemctl start kap-twitterbot"
echo ""
