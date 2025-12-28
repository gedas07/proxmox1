#!/bin/bash
# ------------------------------------------------------------------
# Linkwarden Installer Helper - Corregido para LXC minimal
# Autor: [Tu Nombre]
# GitHub: https://github.com/gedas07/proxmox1
# ------------------------------------------------------------------

set -e

echo "🚀 Iniciando instalación de Linkwarden en LXC/Servidor Ubuntu..."

# -----------------------------
# Detectar OS de manera robusta
# -----------------------------
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    VER=$VERSION_ID
else
    OS="Unknown"
    VER="Unknown"
fi
echo "✅ OS detectado: $OS $VER"

# -----------------------------
# Actualizar sistema e instalar herramientas básicas
# -----------------------------
apt-get update && apt-get upgrade -y
apt-get install -y curl sudo git build-essential unzip lsb-release software-properties-common

# -----------------------------
# Instalar Node.js 20 si no existe
# -----------------------------
if ! command -v node >/dev/null 2>&1; then
    echo "🔹 Node.js no encontrado. Instalando Node.js 20 LTS..."
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
else
    echo "✅ Node.js ya instalado: $(node -v)"
fi

# -----------------------------
# Habilitar Corepack y Yarn 4.12.0
# -----------------------------
echo "🔹 Configurando Corepack y Yarn 4.12.0..."
corepack enable
corepack prepare yarn@4.12.0 --activate
echo "✅ Yarn activo: $(yarn -v)"

# -----------------------------
# Crear carpeta de instalación
# -----------------------------
INSTALL_DIR="$HOME/linkwarden"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# -----------------------------
# Descargar Linkwarden si no existe
# -----------------------------
if [ ! -f package.json ]; then
    echo "🔹 Descargando Linkwarden..."
    curl -fsSL https://github.com/dani-garcia/bitwarden_rs/archive/refs/heads/master.tar.gz | tar -xz --strip-components=1
fi

# -----------------------------
# Instalar dependencias y construir
# -----------------------------
echo "🔹 Instalando dependencias de Linkwarden..."
yarn install --immutable

echo "🔹 Construyendo Linkwarden..."
yarn build

echo "🎉 Instalación completa. Linkwarden listo en $INSTALL_DIR"

