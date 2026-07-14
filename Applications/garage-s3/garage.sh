#!/bin/bash
# Đang chạy trong môi trường Install của Pterodactyl
echo "Starting Garage S3 Installation..."

# Di chuyển vào thư mục gốc của server
cd /mnt/server

# Tải Garage Binary
echo "Downloading Garage binary..."
ARCH=$([[ "$(uname -m)" == "x86_64" ]] && echo "x86_64-unknown-linux-musl" || echo "aarch64-unknown-linux-musl")
GARAGE_VERSION="v0.9.1"
wget -qO garage "https://garagehq.deuxfleurs.fr/_releases/${GARAGE_VERSION}/garage-${GARAGE_VERSION}-${ARCH}"
chmod +x garage

# Tạo thư mục dữ liệu
echo "Creating meta and data directories..."
mkdir -p meta data

# Tạo file cấu hình garage.toml dựa trên các Port người dùng nhập lúc cài đặt
if [ ! -f "garage.toml" ]; then
    echo "Generating default garage.toml..."
    RPC_SECRET=$(cat /dev/urandom | tr -dc 'a-f0-9' | fold -w 64 | head -n 1)
    
    # Lấy biến từ Pterodactyl Panel (Panel sẽ tự động truyền các biến này vào khi install)
    S3=${S3_API_PORT:-3900}
    RPC=${RPC_PORT:-3901}
    ADMIN=${ADMIN_PORT:-3903}
    
    cat <<EOF > garage.toml
metadata_dir = "/mnt/server/meta"
data_dir = "/mnt/server/data"
db_engine = "lmdb"

replication_factor = 1

rpc_bind_addr = "[::]:${RPC}"
rpc_public_addr = "127.0.0.1:${RPC}"
rpc_secret = "${RPC_SECRET}"

[s3_api]
s3_region = "garage"
api_bind_addr = "[::]:${S3}"
root_domain = ".s3.garage.localhost"

[s3_web]
bind_addr = "[::]:3904"
root_domain = ".web.garage.localhost"
index = "index.html"

[admin]
api_bind_addr = "[::]:${ADMIN}"
EOF
fi

echo "Installation complete!"