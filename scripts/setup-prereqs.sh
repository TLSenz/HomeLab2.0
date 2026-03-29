#!/bin/bash
# =============================================================================
# Homelab Prerequisites Setup
# Run this on EACH VM before deploying docker-compose
# =============================================================================
set -e

echo "========================================"
echo "  Homelab Prerequisites Setup"
echo "========================================"
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "[!] Please run as root: sudo bash setup-prereqs.sh"
    exit 1
fi

# --- Docker ---
if ! command -v docker &>/dev/null; then
    echo "[*] Installing Docker..."
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
    echo "[+] Docker installed"
else
    echo "[=] Docker already installed"
fi

# --- Docker Compose Plugin ---
if ! docker compose version &>/dev/null; then
    echo "[*] Installing Docker Compose plugin..."
    apt-get update -qq
    apt-get install -y -qq docker-compose-plugin
    echo "[+] Docker Compose plugin installed"
else
    echo "[=] Docker Compose plugin already installed"
fi

# --- cifs-utils (SMB mounting) ---
if ! command -v mount.cifs &>/dev/null; then
    echo "[*] Installing cifs-utils..."
    apt-get install -y -qq cifs-utils
    echo "[+] cifs-utils installed"
else
    echo "[=] cifs-utils already installed"
fi

# --- dnsutils (for Pi-hole healthcheck) ---
if ! command -v dig &>/dev/null; then
    echo "[*] Installing dnsutils..."
    apt-get install -y -qq dnsutils
    echo "[+] dnsutils installed"
fi

# --- Python3 + requests (for npm-setup.py) ---
if ! python3 -c "import requests" &>/dev/null; then
    echo "[*] Installing python3-requests..."
    apt-get install -y -qq python3-requests
    echo "[+] python3-requests installed"
fi

# --- Create mount points ---
echo "[*] Creating NAS mount points..."
mkdir -p /mnt/nas/{movies,music,downloads,backups,nextcloud}
echo "[+] Mount points created at /mnt/nas/"

# --- Create docker user group if needed ---
if ! getent group docker &>/dev/null; then
    groupadd docker
fi

# --- Sysctl tuning ---
echo "[*] Applying sysctl tuning..."
cat > /etc/sysctl.d/99-homelab.conf <<EOF
# Increase inotify watches (for Prometheus, Loki, etc.)
fs.inotify.max_user_instances = 512
fs.inotify.max_user_watches = 524288

# Network tuning
net.core.somaxconn = 4096
net.ipv4.tcp_max_syn_backlog = 4096
EOF
sysctl --system > /dev/null 2>&1
echo "[+] Sysctl tuning applied"

# --- Firewall (optional, UFW) ---
if command -v ufw &>/dev/null; then
    echo "[*] Configuring firewall..."
    ufw allow 22/tcp comment "SSH" 2>/dev/null || true
    ufw allow 53/tcp comment "DNS TCP" 2>/dev/null || true
    ufw allow 53/udp comment "DNS UDP" 2>/dev/null || true
    ufw allow 80/tcp comment "HTTP" 2>/dev/null || true
    ufw allow 443/tcp comment "HTTPS" 2>/dev/null || true
    ufw allow 81/tcp comment "NPM Admin" 2>/dev/null || true
    ufw allow 9100/tcp comment "Node Exporter" 2>/dev/null || true
    ufw allow 8081/tcp comment "cAdvisor" 2>/dev/null || true
    echo "[+] Firewall rules added (ufw not enabled by default - run 'ufw enable' when ready)"
fi

echo ""
echo "========================================"
echo "  Prerequisites installed!"
echo "========================================"
echo ""
echo "Next steps:"
echo "  1. Run setup-smb-mounts.sh to mount NAS shares"
echo "  2. Edit .env file with your settings"
echo "  3. Run: docker compose up -d"
echo ""
echo "You may want to reboot after installing Docker."
