#!/usr/bin/env bash
mkdir -p /srv
cd /srv
wget https://github.com/shadowsocks/go-shadowsocks2/releases/download/v0.1.0/shadowsocks2-linux.gz
gunzip shadowsocks2-linux.gz
chmod +x shadowsocks2-linux

sudo bash -c 'cat >/lib/systemd/system/ssocks.service <<EOL
[Unit]
Description=ssocks daemon
[Service]
ExecStart=/srv/shadowsocks2-linux -s ':443' -cipher AEAD_CHACHA20_POLY1305 -password ${password}
Restart=always
User=root
Group=root
[Install]
WantedBy=multi-user.target
EOL'

sudo systemctl daemon-reload
sudo systemctl enable ssocks.service
sudo systemctl start ssocks

