#!/bin/bash
# Garage S3 Installation Script for Pterodactyl
# Docker Container: ghcr.io/ptero-eggs/installers:debian

apt update
apt install -y wget curl tar jq openssl

# 1. Xác định kiến trúc CPU hệ thống
ARCH=$([[ "$(uname -m)" == "x86_64" ]] && echo "x86_64" || echo "aarch64")
echo "Detected architecture: ${ARCH}"

# 2. Di chuyển vào thư mục server
cd /mnt/server
mkdir -p data meta keys

# 3. Cào API GitHub lấy link tải bản phát hành mới nhất (latest)
echo "Fetching latest Garage S3 binary from GitHub..."
DOWNLOAD_URL=$(curl -s https://api.github.com/repos/Deuxfleurs/garage/releases/latest | grep "browser_download_url" | grep -i "$ARCH" | grep -i "linux" | head -n 1 | cut -d '"' -f 4)

if [ -z "$DOWNLOAD_URL" ]; then
    echo "Error: Cannot retrieve download URL from GitHub API. Falling back..."
    # Fallback dự phòng link cấu trúc tĩnh nếu API rate limit
    DOWNLOAD_URL="https://garagehq.deuxfleurs.fr/binaries/latest/${ARCH}-unknown-linux-musl/garage"
fi

echo "Downloading from: ${DOWNLOAD_URL}"
wget -O garage.tar.gz "$DOWNLOAD_URL"

# Giải nén nếu file tải về là định dạng tar.gz, hoặc đổi tên nếu là file binary trực tiếp
if [[ "$DOWNLOAD_URL" == *.tar.gz ]]; then
    tar -xzf garage.tar.gz
    rm -f garage.tar.gz
else
    mv garage.tar.gz garage
fi

chmod +x garage
echo "Garage binary setup successfully."

# 4. TỰ ĐỘNG SINH FILE RUNTIME STARTUP (garage.sh)
# File này sẽ quản lý logic Update khi bật tắt server và sinh file cấu hình garage.toml tự động
echo "Creating runtime startup script (garage.sh)..."
cat << 'EOF' > garage.sh
#!/bin/bash
# Runtime wrapper script for Garage S3 inside Pterodactyl

# --- CHỨC NĂNG 1: TỰ ĐỘNG CẬP NHẬT KHI KHỞI ĐỘNG (LATEST) ---
if [ "$UPDATE_BINARY" = "true" ]; then
    echo "[Garage] Checking for updates because UPDATE_BINARY is set to true..."
    ARCH=$([[ "$(uname -m)" == "x86_64" ]] && echo "x86_64" || echo "aarch64")
    NEW_URL=$(curl -s https://api.github.com/repos/Deuxfleurs/garage/releases/latest | grep "browser_download_url" | grep -i "$ARCH" | grep -i "linux" | head -n 1 | cut -d '"' -f 4)
    
    if [ ! -z "$NEW_URL" ]; then
        echo "[Garage] Updating to latest release..."
        rm -f garage
        wget -O garage.tar.gz "$NEW_URL"
        if [[ "$NEW_URL" == *.tar.gz ]]; then
            tar -xzf garage.tar.gz && rm -f garage.tar.gz
        else
            mv garage.tar.gz garage
        fi
        chmod +x garage
        echo "[Garage] Update finished successfully."
    else
        echo "[Garage] Warning: Failed to fetch update URL. Launching current binary..."
    fi
fi

# --- CHỨC NĂNG 2: TỰ SINH CHUỖI KHÓA RPC BẢO MẬT GIỮA CÁC NODE ---
if [ ! -f "keys/rpc_secret.txt" ]; then
    echo "[Garage] No RPC secret detected. Generating a strong random hex token..."
    openssl rand -hex 32 > keys/rpc_secret.txt
fi
RPC_SECRET=$(cat keys/rpc_secret.txt)

# --- CHỨC NĂNG 3: DYNAMIC CONFIGURATION OVERWRITE ---
# Ghi đè cấu hình garage.toml dựa trên các Port được gán trực tiếp từ giao diện Panel
echo "[Garage] Re-building garage.toml config with latest panel allocations..."
cat << EOL > garage.toml
metadata_dir = "/mnt/server/meta"
data_dir = "/mnt/server/data"
rpc_secret = "${RPC_SECRET}"

[rpc_bind]
bind_addr = "0.0.0.0:${RPC_PORT}"

[s3_api]
bind_addr = "0.0.0.0:${S3_API_PORT}"
api_region = "garage"

[admin]
bind_addr = "0.0.0.0:${ADMIN_PORT}"
EOL

# --- CHỨC NĂNG 4: KÍCH HOẠT TIẾN TRÌNH SERVER ---
echo "[Garage] Booting up system cluster..."
./garage server
EOF

chmod +x garage.sh
echo "Installation complete!"