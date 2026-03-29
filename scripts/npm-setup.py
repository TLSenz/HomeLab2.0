#!/usr/bin/env python3
"""
Nginx Proxy Manager - Auto-configure proxy hosts for all homelab services.
Run AFTER NPM is up and you've changed the default admin password.

Usage:
  1. Edit NPM_URL, NPM_EMAIL, NPM_PASSWORD below
  2. python3 npm-setup.py

Requires: pip install requests
"""

import requests
import sys
import time

# === CONFIGURATION ===
NPM_URL = "http://192.168.1.70:81"   # NPM admin panel on VM1
NPM_EMAIL = "admin@example.com"       # Change to your NPM login email
NPM_PASSWORD = "changeme"             # Change to your NPM admin password
DOMAIN = "thethalium.ch"

# (subdomain, upstream_host, upstream_port, upstream_scheme, websocket)
# upstream_host is either a container name (VM1 services) or a VM IP (VM2/VM3 services)
SERVICES = [
    # VM1 services (use container name via Docker network)
    ("pihole",       "pihole",          80,   "http", False),
    ("portainer",    "portainer",       9443, "https", False),
    ("uptime",       "uptime-kuma",     3001, "http", True),
    ("sonarr",       "sonarr",          8989, "http", False),
    ("radarr",       "radarr",          7878, "http", False),
    ("lidarr",       "lidarr",          8686, "http", False),
    ("prowlarr",     "prowlarr",        9696, "http", False),
    ("qbittorrent",  "qbittorrent",     8090, "http", False),
    ("music",        "navidrome",       4533, "http", False),

    # VM2 services (use host IP since NPM is on VM1)
    ("grafana",      "192.168.1.71",    3000, "http", False),
    ("prometheus",   "192.168.1.71",    9090, "http", False),
    ("vault",        "192.168.1.71",    8200, "http", False),
    ("minio",        "192.168.1.71",    9001, "http", False),

    # VM3 services (use host IP since NPM is on VM1)
    ("cloud",        "192.168.1.73",    8080, "http", False),
    ("wiki",         "192.168.1.73",    3100, "http", False),
    ("bookmarks",    "192.168.1.73",    9090, "http", False),
]


def npm_login(session):
    """Login to NPM and get JWT token."""
    for attempt in range(3):
        try:
            resp = session.post(f"{NPM_URL}/api/tokens", json={
                "identity": NPM_EMAIL,
                "secret": NPM_PASSWORD,
            }, timeout=10)
            resp.raise_for_status()
            token = resp.json().get("token")
            session.headers.update({"Authorization": f"Bearer {token}"})
            print(f"[+] Logged in to NPM at {NPM_URL}")
            return token
        except Exception as e:
            print(f"[!] Login attempt {attempt+1} failed: {e}")
            time.sleep(2)
    return None


def get_cert_id(session):
    """Get wildcard SSL certificate ID."""
    try:
        resp = session.get(f"{NPM_URL}/api/nginx/ssl")
        resp.raise_for_status()
        for cert in resp.json().get("data", []):
            name = cert.get("nice_name", "")
            if DOMAIN in name and ("*" in name or "wildcard" in name.lower()):
                print(f"[+] Found SSL cert: {name} (ID: {cert['id']})")
                return cert["id"]
    except Exception:
        pass
    print(f"[!] No wildcard SSL cert found for *.{DOMAIN}")
    print(f"    Create one in NPM > SSL Certificates > Add SSL Certificate")
    print(f"    Use 'Let's Encrypt' with DNS challenge (Cloudflare API token)")
    return None


def proxy_host_exists(session, domain):
    """Check if proxy host already exists."""
    try:
        resp = session.get(f"{NPM_URL}/api/nginx/proxy-hosts")
        resp.raise_for_status()
        for host in resp.json().get("data", []):
            if domain in host.get("domain_names", []):
                return host["id"]
    except Exception:
        pass
    return None


def delete_proxy_host(session, host_id):
    """Delete a proxy host."""
    try:
        session.delete(f"{NPM_URL}/api/nginx/proxy-hosts/{host_id}")
    except Exception:
        pass


def create_proxy_host(session, subdomain, upstream_host, upstream_port,
                      upstream_scheme, websocket, cert_id):
    """Create a proxy host in NPM."""
    full_domain = f"{subdomain}.{DOMAIN}"

    existing_id = proxy_host_exists(session, full_domain)
    if existing_id:
        print(f"  [=] {full_domain} already exists (ID: {existing_id}), deleting and recreating...")
        delete_proxy_host(session, existing_id)
        time.sleep(1)

    data = {
        "domain_names": [full_domain],
        "forward_scheme": upstream_scheme,
        "forward_host": upstream_host,
        "forward_port": upstream_port,
        "block_exploits": True,
        "caching_enabled": False,
        "allow_websocket_upgrade": websocket,
        "access_list_id": None,
        "certificate_id": cert_id if cert_id else 0,
        "ssl_forced": bool(cert_id),
        "hsts_enabled": bool(cert_id),
        "hsts_subdomains": bool(cert_id),
        "http2_support": bool(cert_id),
        "advanced_config": "",
        "locations": [],
    }

    try:
        resp = session.post(f"{NPM_URL}/api/nginx/proxy-hosts", json=data, timeout=10)
        if resp.status_code == 201:
            ssl = " (SSL)" if cert_id else ""
            print(f"  [+] {full_domain} -> {upstream_scheme}://{upstream_host}:{upstream_port}{ssl}")
        else:
            print(f"  [!] Failed {full_domain}: {resp.status_code} - {resp.text[:200]}")
    except Exception as e:
        print(f"  [!] Error creating {full_domain}: {e}")


def main():
    print("=" * 60)
    print("  NPM Auto-Setup for thethalium.ch")
    print("=" * 60)
    print()

    session = requests.Session()

    token = npm_login(session)
    if not token:
        print("\n[!] Cannot login. Check NPM_EMAIL and NPM_PASSWORD.")
        print("    Also make sure NPM is running at", NPM_URL)
        sys.exit(1)

    cert_id = get_cert_id(session)

    print(f"\n[*] Configuring {len(SERVICES)} proxy hosts...\n")
    for subdomain, host, port, scheme, ws in SERVICES:
        create_proxy_host(session, subdomain, host, port, scheme, ws, cert_id)
        time.sleep(0.5)

    print(f"\n[+] Done! All proxy hosts configured.")
    print(f"\n    In Cloudflare DNS, create a wildcard CNAME:")
    print(f"    *.{DOMAIN} -> <your-tunnel-id>.cfargotunnel.com")
    print(f"\n    Or create individual CNAME records for each subdomain.")


if __name__ == "__main__":
    main()
