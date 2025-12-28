#!/usr/bin/env bash
# Copyright (c) 2021-2025 community-scripts ORG
# Fixed by: gedas07 + ChatGPT
# License: MIT
# Source: https://linkwarden.app/

# --------------------------------------------------
# Load Proxmox helper functions
# --------------------------------------------------
source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

# --------------------------------------------------
# Base dependencies (FIX para LXC minimal)
# --------------------------------------------------
msg_info "Installing base dependencies"
$STD apt-get install -y \
  curl \
  sudo \
  git \
  lsb-release \
  build-essential \
  make \
  unzip \
  openssl
msg_ok "Base dependencies installed"

# --------------------------------------------------
# Node.js + Corepack + Yarn 4 (FIX CRÍTICO)
# --------------------------------------------------
msg_info "Installing Node.js 22 + Corepack/Yarn"
NODE_VERSION="22"
setup_nodejs

corepack enable
corepack prepare yarn@4.12.0 --activate
msg_ok "Node $(node -v) | Yarn $(yarn -v)"

# --------------------------------------------------
# PostgreSQL
# --------------------------------------------------
PG_VERSION="16"
setup_postgresql

# --------------------------------------------------
# Rust (para monolith)
# --------------------------------------------------
RUST_CRATES="monolith"
setup_rust

# --------------------------------------------------
# PostgreSQL DB setup
# --------------------------------------------------
msg_info "Setting up PostgreSQL DB"
DB_NAME="linkwardendb"
DB_USER="linkwarden"
DB_PASS="$(openssl rand -base64 18 | tr -d '/' | cut -c1-13)"
SECRET_KEY="$(tr -dc A-Za-z0-9 </dev/urandom | head -c 32)"

$STD sudo -u postgres psql -c "CREATE ROLE $DB_USER WITH LOGIN PASSWORD '$DB_PASS';"
$STD sudo -u postgres psql -c "CREATE DATABASE $DB_NAME WITH OWNER $DB_USER ENCODING 'UTF8' TEMPLATE template0;"
$STD sudo -u postgres psql -c "ALTER ROLE $DB_USER SET client_encoding TO 'utf8';"
$STD sudo -u postgres psql -c "ALTER ROLE $DB_USER SET default_transaction_isolation TO 'read committed';"
$STD sudo -u postgres psql -c "ALTER ROLE $DB_USER SET timezone TO 'UTC';"

cat <<EOF >~/linkwarden.creds
Linkwarden Credentials
---------------------
DB User:     $DB_USER
DB Password: $DB_PASS
DB Name:     $DB_NAME
Secret:      $SECRET_KEY
EOF

msg_ok "PostgreSQL DB configured"

# --------------------------------------------------
# Optional Adminer
# --------------------------------------------------
read -r -p "${TAB3}Would you like to install Adminer? <y/N> " prompt
if [[ "${prompt,,}" =~ ^(y|yes)$ ]]; then
  setup_adminer
fi

# --------------------------------------------------
# Install Linkwarden
# --------------------------------------------------
msg_info "Installing Linkwarden (this takes a while)"
fetch_and_deploy_gh_release "linkwarden" "linkwarden/linkwarden"

cd /opt/linkwarden

# 🔧 FIX: usar Yarn moderno correctamente
$STD yarn install --immutable
$STD npx playwright install-deps
$STD yarn playwright install

IP=$(hostname -I | awk '{print $1}')

cat <<EOF >/opt/linkwarden/.env
NEXTAUTH_SECRET=${SECRET_KEY}
NEXTAUTH_URL=http://${IP}:3000
DATABASE_URL=postgresql://${DB_USER}:${DB_PASS}@localhost:5432/${DB_NAME}
EOF

$STD yarn prisma:generate
$STD yarn web:build
$STD yarn prisma:deploy

# Cleanup
rm -rf ~/.cargo
rm -rf /root/.cache/yarn
rm -rf /opt/linkwarden/.next/cache

msg_ok "Linkwarden installed"

# --------------------------------------------------
# systemd service
# --------------------------------------------------
msg_info "Creating Linkwarden service"
cat <<EOF >/etc/systemd/system/linkwarden.service
[Unit]
Description=Linkwarden Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/linkwarden
ExecStart=/usr/bin/yarn concurrently:start
Restart=always
Environment=NODE_ENV=production

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable -q --now linkwarden
msg_ok "Service enabled and started"

# --------------------------------------------------
# Final steps
# --------------------------------------------------
motd_ssh
customize
cleanup_lxc
