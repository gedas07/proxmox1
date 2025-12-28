#!/usr/bin/env bash
set -e

### CONFIGURACIÓN ###
CTID=120
HOSTNAME=linkwarden
MEMORY=2048
CORES=2
DISK=12
BRIDGE=vmbr0
OS=ubuntu-22.04
IP=dhcp

### COMPROBACIONES ###
if ! command -v pct >/dev/null; then
  echo "❌ Esto debe ejecutarse en un nodo Proxmox"
  exit 1
fi

if pct status $CTID &>/dev/null; then
  echo "❌ El CTID $CTID ya existe"
  exit 1
fi

echo "🚀 Creando LXC $HOSTNAME (CTID $CTID)"

### CREAR LXC ###
pveam update
TEMPLATE=$(pveam available --section system | grep $OS | tail -n1 | awk '{print $2}')
pveam download local "$TEMPLATE"

pct create $CTID local:vztmpl/$TEMPLATE \
  --hostname $HOSTNAME \
  --cores $CORES \
  --memory $MEMORY \
  --rootfs local-lvm:$DISK \
  --net0 name=eth0,bridge=$BRIDGE,ip=$IP \
  --unprivileged 1 \
  --features nesting=1,keyctl=1 \
  --ostype ubuntu

pct start $CTID
sleep 10

### INSTALACIÓN DENTRO DEL LXC ###
pct exec $CTID -- bash <<'EOF'
set -e

echo "📦 Actualizando sistema"
apt update && apt upgrade -y

echo "📦 Instalando dependencias base"
apt install -y curl git build-essential ca-certificates gnupg lsb-release unzip openssl sudo

echo "🟢 Instalando Node.js 22"
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt install -y nodejs
corepack enable
corepack prepare yarn@4.12.0 --activate

echo "🟢 Instalando PostgreSQL"
apt install -y postgresql
systemctl enable --now postgresql

echo "🟢 Instalando Playwright deps"
apt install -y libnss3 libatk1.0-0 libatk-bridge2.0-0 libcups2 libxkbcommon0 libxcomposite1 libxrandr2 libgbm1 libgtk-3-0

echo "🟢 Creando base de datos"
DB_PASS=$(openssl rand -base64 18 | tr -dc A-Za-z0-9 | head -c 16)
SECRET=$(openssl rand -base64 32 | tr -dc A-Za-z0-9 | head -c 32)

sudo -u postgres psql <<SQL
CREATE USER linkwarden WITH PASSWORD '$DB_PASS';
CREATE DATABASE linkwardendb OWNER linkwarden;
SQL

echo "🟢 Instalando Linkwarden"
cd /opt
git clone https://github.com/linkwarden/linkwarden.git
cd linkwarden

cat <<ENV > .env
NEXTAUTH_SECRET=$SECRET
NEXTAUTH_URL=http://localhost:3000
DATABASE_URL=postgresql://linkwarden:$DB_PASS@localhost:5432/linkwardendb
ENV

yarn install
yarn prisma:generate
yarn prisma:deploy
yarn web:build

echo "🟢 Instalando Playwright"
npx playwright install --with-deps

echo "🟢 Creando servicio systemd"
cat <<SERVICE > /etc/systemd/system/linkwarden.service
[Unit]
Description=Linkwarden
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/linkwarden
ExecStart=/usr/bin/yarn start
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

systemctl daemon-reload
systemctl enable --now linkwarden

echo "📄 Credenciales guardadas en /root/linkwarden.creds"
cat <<CREDS > /root/linkwarden.creds
DB_USER=linkwarden
DB_PASS=$DB_PASS
DB_NAME=linkwardendb
NEXTAUTH_SECRET=$SECRET
CREDS

echo "✅ Linkwarden instalado correctamente"
EOF

echo "🎉 Instalación completa"
echo "👉 Accede por http://IP_DEL_LXC:3000"
