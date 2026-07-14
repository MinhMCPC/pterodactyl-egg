#!/bin/bash
echo "Starting Garage WebUI (Integrated) Installation..."

# Di chuyển vào thư mục gốc của server
cd /mnt/server

echo "Fetching latest version tag from GitHub..."
# Lấy phiên bản mới nhất tự động từ API GitHub
LATEST_VERSION=$(curl -s https://api.github.com/repos/khairul169/garage-webui/releases/latest | grep "tag_name" | cut -d '"' -f 4)

if [ -z "$LATEST_VERSION" ]; then
    echo "Failed to fetch latest version. Fallback to v1.1.0..."
    LATEST_VERSION="v1.1.0"
fi

echo "Latest version found: ${LATEST_VERSION}"

# Xác định kiến trúc theo định dạng mới (amd64 / arm64)
ARCH=$([[ "$(uname -m)" == "x86_64" ]] && echo "amd64" || echo "arm64")

# Ghép URL và tải file
DOWNLOAD_URL="https://github.com/khairul169/garage-webui/releases/download/${LATEST_VERSION}/garage-webui-${LATEST_VERSION}-linux-${ARCH}"
echo "Downloading from: ${DOWNLOAD_URL}"

wget -qO garage "${DOWNLOAD_URL}"
chmod +x garage

# Tạo thư mục dữ liệu
echo "Creating meta and data directories..."
mkdir -p meta data

# Tạo file cấu hình garage.toml
if [ ! -f "garage.toml" ]; then
    echo "Generating default garage.toml..."
    RPC_SECRET=$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 64 | head -n 1)
    
    # Lấy các biến Port từ Pterodactyl Panel
    S3=${S3_API_PORT:-3900}
    RPC=${RPC_PORT:-3901}
    ADMIN=${ADMIN_PORT:-3903}
    WEB=${WEB_PORT:-$SERVER_PORT}
    
    cat <<EOF > garage.toml
metadata_dir = "meta"
data_dir = "data"
db_engine = "lmdb"

replication_mode = "none"

rpc_bind_addr = "[::]:${RPC}"
rpc_public_addr = "127.0.0.1:${RPC}"
rpc_secret = "${RPC_SECRET}"

[s3_api]
s3_region = "garage"
api_bind_addr = "[::]:${S3}"
root_domain = ".s3.garage.localhost"

[s3_web]
bind_addr = "[::]:${WEB}"
root_domain = ".web.garage.localhost"
index = "index.html"

[admin]
api_bind_addr = "[::]:${ADMIN}"
EOF
fi

echo "Installation complete!"