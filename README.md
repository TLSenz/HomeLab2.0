# Homelab - Docker Compose Stack

## Architecture

```
Cloudflare Tunnel (thethalium.ch)
        │
        ▼
┌───────────────────────────────────────────────────────────┐
│ VM1: 192.168.1.70 - Core & Media                         │
│                                                           │
│  Pi-hole ── Nginx Proxy Manager ── Cloudflared            │
│  Portainer  Uptime Kuma                                   │
│  Sonarr  Radarr  Lidarr  Prowlarr  qBittorrent            │
│  Navidrome                                                │
│  Node Exporter  cAdvisor                                  │
└───────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────┐
│ VM2: 192.168.1.71 - Monitoring & Dev                     │
│                                                           │
│  Grafana ── Prometheus ── Loki + Promtail                 │
│  HashiCorp Vault                                          │
│  MinIO (S3)                                               │
│  Node Exporter  cAdvisor                                  │
└───────────────────────────────────────────────────────────┘

┌───────────────────────────────────────────────────────────┐
│ VM3: 192.168.1.73 - Productivity                         │
│                                                           │
│  Nextcloud (+ MariaDB + Redis)                            │
│  Wiki.js (+ Postgres)                                     │
│  Linkding (+ Postgres)                                    │
│  Node Exporter  cAdvisor                                  │
└───────────────────────────────────────────────────────────┘

NAS: 192.168.1.78 (SMB) ── Movies, Music, Downloads, Backups, Nextcloud
```

## Subdomains

| Subdomain | Service | VM | Internal Port |
|-----------|---------|-----|---------------|
| `pihole` | Pi-hole | VM1 | 80 |
| `portainer` | Portainer | VM1 | 9443 |
| `uptime` | Uptime Kuma | VM1 | 3001 |
| `sonarr` | Sonarr | VM1 | 8989 |
| `radarr` | Radarr | VM1 | 7878 |
| `lidarr` | Lidarr | VM1 | 8686 |
| `prowlarr` | Prowlarr | VM1 | 9696 |
| `qbittorrent` | qBittorrent | VM1 | 8090 |
| `music` | Navidrome | VM1 | 4533 |
| `grafana` | Grafana | VM2 | 3000 |
| `prometheus` | Prometheus | VM2 | 9090 |
| `vault` | Vault | VM2 | 8200 |
| `minio` | MinIO | VM2 | 9001 |
| `cloud` | Nextcloud | VM3 | 8080 |
| `wiki` | Wiki.js | VM3 | 3100 |
| `bookmarks` | Linkding | VM3 | 9090 |

## Directory Structure

```
Homelab/
├── vm1-core-media/
│   ├── .env                          # EDIT: fill in passwords & tokens
│   ├── docker-compose.yml
│   ├── pihole/                       # auto-created
│   ├── npm/                          # auto-created
│   ├── portainer/                    # auto-created
│   ├── uptime-kuma/                  # auto-created
│   ├── arr/                          # auto-created (prowlarr, sonarr, radarr, lidarr, qbittorrent)
│   └── navidrome/                    # auto-created
├── vm2-monitoring/
│   ├── .env                          # EDIT: fill in passwords
│   ├── docker-compose.yml
│   ├── prometheus/
│   │   └── prometheus.yml            # ready, edit IPs if needed
│   ├── grafana/
│   │   └── provisioning/datasources/
│   │       └── datasources.yml       # ready
│   ├── loki/
│   │   ├── loki-config.yml           # ready
│   │   └── data/                     # auto-created
│   ├── promtail/
│   │   └── config.yml                # ready
│   ├── vault/
│   │   ├── config/vault.json         # ready
│   │   ├── data/                     # auto-created
│   │   └── logs/                     # auto-created
│   └── minio/                        # auto-created
├── vm3-productivity/
│   ├── .env                          # EDIT: fill in passwords
│   ├── docker-compose.yml
│   ├── nextcloud/                    # auto-created
│   ├── wikijs/                       # auto-created
│   └── linkding/                     # auto-created
├── scripts/
│   ├── setup-prereqs.sh              # run on each VM first
│   ├── setup-smb-mounts.sh           # mount NAS shares
│   ├── backup-to-nas.sh              # nightly backup
│   └── npm-setup.py                  # auto-configure NPM proxy hosts
└── README.md
```

## Deployment Steps

### Step 1: Proxmox VMs

Create 3 VMs with:
- **VM1**: 4 CPU, 6GB RAM, 50GB disk - install Ubuntu 24.04 LTS
- **VM2**: 4 CPU, 6GB RAM, 50GB disk - install Ubuntu 24.04 LTS
- **VM3**: 4 CPU, 6GB RAM, 80GB disk (Nextcloud needs space) - install Ubuntu 24.04 LTS

Set static IPs: 192.168.1.70, .71, .73

### Step 2: Copy Files to Each VM

```bash
# From your workstation, copy the whole directory
scp -r Homelab/ user@192.168.1.70:/opt/homelab
scp -r Homelab/ user@192.168.1.71:/opt/homelab
scp -r Homelab/ user@192.168.1.73:/opt/homelab
```

### Step 3: Run Prerequisites on Each VM

```bash
sudo bash /opt/homelab/scripts/setup-prereqs.sh
```

### Step 4: Edit .env Files

**Replace ALL `CHANGE_ME_*` values** in each `.env` file with strong passwords.

Key values to set:
- `CLOUDFLARE_TUNNEL_TOKEN` (VM1) - from Cloudflare dashboard
- `NAS_USERNAME` / `NAS_PASSWORD` - your NAS SMB credentials
- All admin passwords

### Step 5: Mount NAS Shares

```bash
# Edit the script first with real NAS credentials
sudo bash /opt/homelab/scripts/setup-smb-mounts.sh
```

### Step 6: Start Services

```bash
# VM1 (start this FIRST - NPM must be running)
cd /opt/homelab/vm1-core-media
docker compose up -d

# VM2
cd /opt/homelab/vm2-monitoring
docker compose up -d

# VM3
cd /opt/homelab/vm3-productivity
docker compose up -d
```

### Step 7: Configure Nginx Proxy Manager

1. Access NPM at `http://192.168.1.70:81`
2. Login with default credentials:
   - Email: `admin@example.com`
   - Password: `changeme`
3. **Change the password immediately**
4. Create a wildcard SSL certificate:
   - Go to SSL Certificates > Add SSL Certificate
   - Domain: `*.thethalium.ch`
   - Use Let's Encrypt with DNS Challenge (Cloudflare)
   - Enter your Cloudflare API token
5. Run the auto-setup script:
   ```bash
   pip3 install requests
   python3 /opt/homelab/scripts/npm-setup.py
   ```
   (Edit the script first with your NPM email/password)

### Step 8: Initialize Vault

```bash
docker exec vault vault operator init -key-shares=5 -key-threshold=3
```
**Save the 5 unseal keys and the root token somewhere safe!**

To unseal after restart:
```bash
docker exec vault vault operator unseal <key1>
docker exec vault vault operator unseal <key2>
docker exec vault vault operator unseal <key3>
```

### Step 9: Configure Cloudflare Tunnel

1. Go to Cloudflare Dashboard > Zero Trust > Networks > Tunnels
2. Create a tunnel (or use existing)
3. Set the token in VM1 `.env` as `CLOUDFLARE_TUNNEL_TOKEN`
4. Add public hostnames:
   - `*.thethalium.ch` -> `http://nginx-proxy-manager:80`
5. Restart cloudflared: `docker compose restart cloudflared`

### Step 10: Configure Arr Stack

1. Access Prowlarr at `https://prowlarr.thethalium.ch`
2. Add your indexers (NZB and/or torrent)
3. Go to Settings > Apps, add Sonarr, Radarr, Lidarr:
   - Sonarr: `http://sonarr:8989` + API key from Sonarr settings
   - Radarr: `http://radarr:7878` + API key
   - Lidarr: `http://lidarr:8686` + API key
4. In Sonarr/Radarr/Lidarr, add qBittorrent as download client:
   - Host: `qbittorrent`, Port: `8090`
   - Username: `admin`, Password: `adminadmin` (default, change it)
5. Set root folders:
   - Radarr: `/media/movies`
   - Sonarr: `/media/tv`
   - Lidarr: `/media/music`
6. Download path: `/downloads`

### Step 11: Set Up Backups

```bash
# Edit the script with correct paths
crontab -e
# Add this line:
0 3 * * * /opt/homelab/scripts/backup-to-nas.sh >> /var/log/homelab-backup.log 2>&1
```

### Step 12: DNS for Pi-hole

Set Pi-hole as your DNS server on your router or devices:
- Primary DNS: `192.168.1.70`
- Pi-hole admin: `https://pihole.thethalium.ch`

## What You Still Need To Do

| # | Task | Where |
|---|------|-------|
| 1 | Replace all `CHANGE_ME_*` in `.env` files | All 3 `.env` files |
| 2 | Create NAS SMB shares: `Movies`, `Music`, `Downloads`, `Backups`, `Nextcloud` | Your NAS |
| 3 | Set real NAS credentials in `setup-smb-mounts.sh` | `scripts/setup-smb-mounts.sh` |
| 4 | Set static IPs on all 3 VMs | Proxmox networking |
| 5 | Create Cloudflare Tunnel and get token | Cloudflare Dashboard |
| 6 | Create wildcard CNAME in Cloudflare DNS: `*.thethalium.ch` -> tunnel | Cloudflare DNS |
| 7 | Create wildcard SSL cert in NPM (Cloudflare DNS challenge) | NPM web UI |
| 8 | Edit `npm-setup.py` with your NPM email/password | `scripts/npm-setup.py` |
| 9 | Initialize and unseal Vault (save keys!) | After VM2 is up |
| 10 | Configure Pi-hole upstream DNS (1.1.1.1) | Pi-hole web UI |
| 11 | Configure Prowlarr indexers + link to Sonarr/Radarr/Lidarr | Prowlarr web UI |
| 12 | Set download client in Sonarr/Radarr/Lidarr | *arr web UIs |
| 13 | Create first user in Nextcloud | Nextcloud web UI |
| 14 | Run through Wiki.js setup wizard | Wiki.js web UI |
| 15 | Create first Linkding user account | Linkding web UI |
| 16 | Check port 25 is open if you add email later | Your ISP/router |
| 17 | Install Node Exporter on host (or use the container one) | Each VM |

## Useful Commands

```bash
# Check all services on a VM
docker compose ps

# View logs for a specific service
docker compose logs -f sonarr

# Restart a single service
docker compose restart radarr

# Update all services
docker compose pull && docker compose up -d

# Update a single service
docker compose pull sonarr && docker compose up -d sonarr

# Check disk usage
docker system df

# Clean up unused images
docker image prune -a

# Check NAS mounts
df -h | grep cifs

# Remount NAS if dropped
sudo mount -a
```

## Resource Usage (Approximate)

| VM | Service | ~RAM |
|----|---------|------|
| VM1 | Pi-hole | 100MB |
| VM1 | Nginx Proxy Manager | 150MB |
| VM1 | Portainer | 50MB |
| VM1 | Cloudflared | 30MB |
| VM1 | Uptime Kuma | 100MB |
| VM1 | Prowlarr | 200MB |
| VM1 | Sonarr | 250MB |
| VM1 | Radarr | 250MB |
| VM1 | Lidarr | 250MB |
| VM1 | qBittorrent | 200MB |
| VM1 | Navidrome | 100MB |
| VM1 | **VM1 Total** | **~1.7GB** |
| VM2 | Grafana | 200MB |
| VM2 | Prometheus | 500MB |
| VM2 | Loki | 300MB |
| VM2 | Promtail | 50MB |
| VM2 | Vault | 100MB |
| VM2 | MinIO | 200MB |
| VM2 | **VM2 Total** | **~1.4GB** |
| VM3 | Nextcloud + DB + Redis | 800MB |
| VM3 | Wiki.js + DB | 200MB |
| VM3 | Linkding + DB | 150MB |
| VM3 | **VM3 Total** | **~1.2GB** |
| | **Grand Total** | **~4.3GB** |

All comfortably fit within 6GB per VM.
