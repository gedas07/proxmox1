#!/bin/bash
# ------------------------------------------------------------------
# Proxmox LXC Linkwarden Installer (Corregido para Yarn 4 / Corepack)
# Autor: [Tu nombre]
# GitHub: https://github.com/TU_USUARIO/proxmox-linkwarden
# ------------------------------------------------------------------

set -e

echo "🚀 Iniciando instalación de Linkwarden en LXC Proxmox..."

# Detectar OS
OS=$(lsb_release -si)
VER=$(lsb_release -sr)

if [[ "$OS" != "Ubuntu" ]]; then
  echo "❌ Solo soportado en Ubuntu 22.04 / 24.04"
  exit 1
fi

echo "✅ OS detectado: $OS $VER"

# Actualizar paquetes
apt-get update && apt-get upgrade -y

# Instalar dependencias básicas
apt-get install -y curl sudo gnupg2 lsb-release build-essential

# Instalar Node.js LTS (20.x)
if ! command -v node >/dev/null 2>&1; then
  echo "🔹 Instalando Node.js LTS..."
  curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
  apt-get install -y nodejs
else
  echo "✅ Node.js ya instalado: $(node -v)"
fi

# Habilitar Corepack y Yarn 4
echo "🔹 Configurando Corepack y Yarn 4.12.0..."
corepack enable
corepack prepare yarn@4.12.0 --activate
echo "✅ Yarn activo: $(yarn -v)"

# Crear usuario para Linkwarden (opcional)
if ! id "linkwarden" >/dev/null 2>&1; then
  useradd -m -s /bin/bash linkwarden
fi

# Cambiar a usuario linkwarden
sudo -u linkwarden bash <<'EOF'

# Carpeta de instalación
INSTALL_DIR="$HOME/linkwarden"
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Descargar Linkwarden
if [ ! -f package.json ]; then
  echo "🔹 Descargando Linkwarden..."
  curl -fsSL https://github.com/your/linkwarden/archive/refs/heads/main.tar.gz | tar -xz --strip-components=1
fi

# Instalar dependencias
echo "🔹 Instalando dependencias de Linkwarden..."
yarn install --immutable

# Construir proyecto
echo "🔹 Construyendo Linkwarden..."
yarn build

EOF

echo "🎉 Instalación completada. Puedes iniciar Linkwarden desde el directorio del usuario linkwarden."
