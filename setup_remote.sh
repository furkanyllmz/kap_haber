#!/bin/bash
set -e

echo ">>> Server Setup Başlıyor..."

# 1. Update and Install Python3/Pip
apt-get update -y
apt-get install -y python3-pip python3-venv mongodb

# Start MongoDB Service
systemctl enable mongodb
systemctl start mongodb

# 2. Create Virtual Environment
echo ">>> Virtual Environment oluşturuluyor..."
python3 -m venv /root/daily_data_kap_2/venv


# 3. Install Dependencies
echo ">>> Kütüphaneler kuruluyor..."
/root/daily_data_kap_2/venv/bin/pip install -r /root/daily_data_kap_2/requirements.txt

# 4. Create Service Files
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

# Analyzer Service
cat > /etc/systemd/system/kap-analyzer.service <<EOF
[Unit]
Description=KAP Gemini Analyzer
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/daily_data_kap_2
ExecStart=/root/daily_data_kap_2/venv/bin/python3 /root/daily_data_kap_2/analyze_kap.py
Environment="PYTHONUNBUFFERED=1"
# Environment variables from .env will be loaded by python-dotenv within the script, 
# assuming .env is in the WorkingDirectory.
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Bot Service
cat > /etc/systemd/system/kap-bot.service <<EOF
[Unit]
Description=KAP Telegram Subscription Bot
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/daily_data_kap_2
ExecStart=/root/daily_data_kap_2/venv/bin/python3 /root/daily_data_kap_2/telegram_bot.py
Environment="PYTHONUNBUFFERED=1"
Restart=always
RestartSec=10

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

# Twitter Bot Service
cat > /etc/systemd/system/kap-twitterbot.service <<EOF
[Unit]
Description=KAP Twitter Bot (Poster)
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/root/daily_data_kap_2
ExecStart=/root/daily_data_kap_2/venv/bin/python3 /root/daily_data_kap_2/twitterbot.py
Environment="PYTHONUNBUFFERED=1"
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# API Manager Service
cat > /etc/systemd/system/kap-api.service <<EOF
[Unit]
Description=KAP Bot Manager API
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

# 5. Start Services
echo ">>> Servisler başlatılıyor..."
systemctl daemon-reload

# Sadece API servisini başlat, diğerlerini API yönetecek
systemctl enable kap-api
systemctl restart kap-api

# Diğer servisleri stop et ve disable et (manuel yönetim için)
# systemctl stop kap-pipeline kap-news-analyze kap-twitterbot
# systemctl disable kap-pipeline kap-news-analyze kap-twitterbot

echo ">>> KURULUM TAMAMLANDI! Servisler çalışıyor."
systemctl status kap-analyzer --no-pager
