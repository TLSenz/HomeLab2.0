#!/bin/bash
# =============================================================================
# NAS SMB Share Mounting
# Run on VM1 (movies, music, downloads) and VM3 (nextcloud, backups)
# =============================================================================
set -e

# === EDIT THESE VALUES ===
NAS_IP="192.168.1.78"
NAS_USER="smbuser"
NAS_PASS="CHANGE_ME"

# Share names on NAS (edit these to match your NAS)
SHARE_MOVIES="Movies"
SHARE_MUSIC="Music"
SHARE_DOWNLOADS="Downloads"
SHARE_BACKUPS="Backups"
SHARE_NEXTCLOUD="Nextcloud"
# ==========================

if [ "$EUID" -ne 0 ]; then
    echo "[!] Please run as root: sudo bash setup-smb-mounts.sh"
    exit 1
fi

# Create credentials file
CRED_FILE="/etc/samba/.nas_credentials"
echo "username=${NAS_USER}" > $CRED_FILE
echo "password=${NAS_PASS}" >> $CRED_FILE
chmod 600 $CRED_FILE
echo "[+] Created credentials file: ${CRED_FILE}"

# Function to add fstab entry (idempotent)
add_fstab_entry() {
    local share=$1
    local mount=$2
    local line="//${NAS_IP}/${share} ${mount} cifs credentials=${CRED_FILE},uid=1000,gid=1000,file_mode=0775,dir_mode=0775,_netdev,nofail,noserverino 0 0"

    # Create mount point
    mkdir -p "$mount"

    # Add to fstab if not already there
    if ! grep -qF "$mount" /etc/fstab; then
        echo "$line" >> /etc/fstab
        echo "[+] Added fstab: ${share} -> ${mount}"
    else
        echo "[=] fstab entry exists: ${mount}"
    fi
}

echo ""
echo "[*] Configuring SMB mounts..."
echo ""

# Add entries based on what exists
add_fstab_entry "$SHARE_MOVIES"    "/mnt/nas/movies"
add_fstab_entry "$SHARE_MUSIC"     "/mnt/nas/music"
add_fstab_entry "$SHARE_DOWNLOADS" "/mnt/nas/downloads"
add_fstab_entry "$SHARE_BACKUPS"   "/mnt/nas/backups"
add_fstab_entry "$SHARE_NEXTCLOUD" "/mnt/nas/nextcloud"

echo ""
echo "[*] Mounting all shares..."
mount -a 2>&1 || echo "[!] Some mounts failed - check NAS connectivity and credentials"

echo ""
echo "[*] Current SMB mounts:"
df -h | grep cifs || echo "  No CIFS mounts found - check network/credentials"

echo ""
echo "[+] Done! Verify mounts are working, then start your Docker services."
echo "    To test: ls -la /mnt/nas/movies"
