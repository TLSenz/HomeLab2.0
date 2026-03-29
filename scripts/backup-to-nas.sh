#!/bin/bash
# =============================================================================
# Homelab Backup to NAS
# Run via cron: 0 3 * * * /opt/homelab/scripts/backup-to-nas.sh
# =============================================================================
set -e

# === CONFIGURATION ===
HOMELAB_BASE="/opt/homelab"          # Where compose files live
NAS_BACKUP="/mnt/nas/backups/homelab" # NAS backup destination
RETENTION_DAYS=7                      # Keep backups for N days
LOG_FILE="/var/log/homelab-backup.log"
# ======================

TIMESTAMP=$(date +%Y-%m-%d_%H%M)
BACKUP_DIR="${NAS_BACKUP}/${TIMESTAMP}"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Starting Homelab Backup ==="

# Check NAS is mounted
if ! mountpoint -q /mnt/nas/backups 2>/dev/null; then
    log "[!] /mnt/nas/backups is not mounted. Attempting mount..."
    mount /mnt/nas/backups 2>/dev/null || {
        log "[!] Failed to mount NAS backup share. Aborting."
        exit 1
    }
fi

mkdir -p "$BACKUP_DIR"

# --- Backup VM compose data ---
backup_vm() {
    local vm_dir=$1
    local vm_name=$2

    if [ -d "$vm_dir" ]; then
        log "[*] Backing up ${vm_name}..."
        tar czf "${BACKUP_DIR}/${vm_name}.tar.gz" \
            --exclude='*/cache/*' \
            --exclude='*/logs/*.log' \
            --exclude='*/tmp/*' \
            --exclude='prometheus/data' \
            --exclude='loki/data/chunks' \
            --exclude='minio/data/.minio.sys' \
            -C "$vm_dir" . 2>> "$LOG_FILE" || true
        local size=$(du -sh "${BACKUP_DIR}/${vm_name}.tar.gz" 2>/dev/null | cut -f1)
        log "  [+] ${vm_name}: ${size}"
    else
        log "  [=] ${vm_name}: directory not found, skipping"
    fi
}

backup_vm "${HOMELAB_BASE}/vm1-core-media" "vm1-core-media"
backup_vm "${HOMELAB_BASE}/vm2-monitoring" "vm2-monitoring"
backup_vm "${HOMELAB_BASE}/vm3-productivity" "vm3-productivity"

# --- Backup Vault data (critical!) ---
VAULT_DATA="${HOMELAB_BASE}/vm2-monitoring/vault/data"
if [ -d "$VAULT_DATA" ]; then
    log "[*] Backing up Vault data (critical)..."
    tar czf "${BACKUP_DIR}/vault-data.tar.gz" -C "$VAULT_DATA" . 2>> "$LOG_FILE"
    log "  [+] Vault data backed up"
fi

# --- Backup .env files ---
log "[*] Backing up .env files..."
mkdir -p "${BACKUP_DIR}/env"
for env_file in "${HOMELAB_BASE}"/vm*/.env; do
    if [ -f "$env_file" ]; then
        cp "$env_file" "${BACKUP_DIR}/env/"
    fi
done

# --- Backup Docker volumes list ---
log "[*] Saving Docker volume list..."
docker volume ls > "${BACKUP_DIR}/docker-volumes.txt" 2>/dev/null || true

# --- Backup crontab ---
crontab -l > "${BACKUP_DIR}/crontab.txt" 2>/dev/null || true

# --- Cleanup old backups ---
log "[*] Cleaning up backups older than ${RETENTION_DAYS} days..."
find "$NAS_BACKUP" -maxdepth 1 -type d -mtime +${RETENTION_DAYS} -exec rm -rf {} \; 2>/dev/null || true

# --- Summary ---
TOTAL_SIZE=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)
log "=== Backup Complete ==="
log "    Location: ${BACKUP_DIR}"
log "    Size: ${TOTAL_SIZE}"
log ""
