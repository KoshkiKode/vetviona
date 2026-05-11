# KoshkiKode — Vetviona Server Setup Guide

> **Goal:** Run the Vetviona license backend on your own hardware from scratch.
> Debian headless, Node.js + systemd, MinIO for durable storage, Caddy for
> automatic HTTPS, and GoDaddy DNS for dynamic IP management.
> No cloud hosting fees. No AWS. No external managed services required.
>
> **Hardware target:** The same Debian tower running Unshelvd works perfectly.
> The license backend is extremely lightweight — it adds ~50 MB RAM at rest.

---

## Table of Contents

1. [What Runs Where](#1-what-runs-where)
2. [What You Need Before Starting](#2-what-you-need-before-starting)
3. [Install Debian Headless](#3-install-debian-headless)
4. [First Boot: Essential Setup](#4-first-boot-essential-setup)
5. [Install Docker](#5-install-docker)
6. [Install Caddy](#6-install-caddy)
7. [Router: Port Forwarding](#7-router-port-forwarding)
8. [GoDaddy: Dynamic DNS](#8-godaddy-dynamic-dns)
9. [Install Node.js](#9-install-nodejs)
10. [Deploy MinIO (Object Storage)](#10-deploy-minio-object-storage)
11. [Deploy the License Backend](#11-deploy-the-license-backend)
12. [Caddy Config: Full Example](#12-caddy-config-full-example)
13. [Flutter: Build Against Your Server](#13-flutter-build-against-your-server)
14. [Backups](#14-backups)
15. [Maintenance Cheat Sheet](#15-maintenance-cheat-sheet)
16. [Quick Reference Links](#16-quick-reference-links)

---

## 1. What Runs Where

| Service | How it runs | Port | RAM (approx) |
|---|---|---|---|
| Debian OS (headless) | bare metal | — | ~150 MB |
| Caddy (reverse proxy + SSL) | systemd | 80, 443 | ~20 MB |
| MinIO (object storage) | Docker | 9000, 9001 | ~100 MB |
| Vetviona license backend | systemd (Node.js) | 8090 | ~50 MB |
| **Total** | | | **~320 MB** |

MinIO runs in Docker for easy upgrades and volume management. The license
backend runs as a bare systemd service — it has no build step and no container
overhead. Caddy handles all TLS automatically.

> **Sharing the tower with Unshelvd?** No problem. These services use
> completely different ports and don't interfere. Add the Caddy block from
> [Section 12](#12-caddy-config-full-example) to your existing Caddyfile.

---

## 2. What You Need Before Starting

### Hardware
- Any x86-64 machine (desktop tower, mini PC, old laptop) with Ethernet
- At least 2 GB RAM, 20 GB free disk
- A separate machine to SSH from

### Accounts & Services
- **GoDaddy** — domain registrar and DNS provider
  [GoDaddy DNS Manager →](https://dcc.godaddy.com/manage/dns)
- **Your domain** — nameservers pointed at GoDaddy
- **Email / SMTP** — the license backend sends verification codes and vouchers
  via email. Any standard SMTP provider works: Mailgun, Brevo, Fastmail,
  Proton Mail Bridge, Zoho Mail, or Postfix on the same server.

### Software to download on your main machine
- [Debian 12 "Bookworm" netinst ISO](https://www.debian.org/distrib/netinst) —
  ~400 MB small installer
- [Rufus (Windows)](https://rufus.ie) or
  [Balena Etcher (Mac/Linux)](https://etcher.balena.io) — to flash ISO to USB
- SSH client — Windows 11 has one built in (`ssh` in PowerShell), or
  [PuTTY](https://www.putty.org)

> **Already have a Debian server?** Jump straight to
> [Section 5 (Docker)](#5-install-docker).

---

## 3. Install Debian Headless

1. Flash the Debian 12 netinst ISO to a USB drive
2. Boot your machine from USB (F12 or DEL at POST to pick boot device)
3. Choose **Install** (not graphical install)
4. Walk through the installer:
   - Language: English / Location: United States
   - Hostname: e.g. `koshki-server`
   - Set a strong root password; create a regular user (e.g. `dylan`)
   - Partitioning: **Guided — use entire disk**, single partition
   - **Software selection:** Uncheck everything **except**:
     - `SSH server`
     - `standard system utilities`
5. Let it install and reboot. Remove the USB when it reboots.

You'll see a plain text login prompt. That's correct.

Find your server's local IP after logging in at the screen:
```bash
ip addr show
```
Look for something like `192.168.1.XX` on your ethernet interface
(`eth0` or `enp3s0`).

> From this point on, do everything over SSH from your main machine.
> The monitor can sit dark forever.

---

## 4. First Boot: Essential Setup

SSH in from your main machine:
```bash
ssh dylan@192.168.1.XX
```

Then:
```bash
# Switch to root
su -

# Update everything
apt update && apt upgrade -y

# Install essentials
apt install -y curl git ufw unzip htop nano jq

# Firewall — allow SSH, HTTP, HTTPS only
ufw allow 22
ufw allow 80
ufw allow 443
ufw enable
ufw status
```

### Give your server a static local IP

Log into your router admin panel (usually `192.168.1.1`). Find
**DHCP Reservations** or **Static Leases**. Tie your server's MAC address
to a fixed local IP (e.g. `192.168.1.50`) so port forwarding never breaks.

Find your MAC address:
```bash
ip link show
# Look for: link/ether xx:xx:xx:xx:xx:xx on your ethernet interface
```

---

## 5. Install Docker

Docker runs MinIO. The license backend itself does **not** use Docker.

[Docker install docs for Debian →](https://docs.docker.com/engine/install/debian/)

```bash
# Remove any old versions
apt remove -y docker docker-engine docker.io containerd runc

# Add Docker's official apt repository
apt install -y ca-certificates curl gnupg
install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | \
  gpg --dearmor -o /etc/apt/keyrings/docker.gpg
chmod a+r /etc/apt/keyrings/docker.gpg

echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

apt update
apt install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin

# Let your regular user run docker without sudo
usermod -aG docker dylan

# Enable and start Docker
systemctl enable --now docker

# Verify
docker run hello-world
```

Log out and back in for the group change to take effect:
```bash
exit
# ssh back in as dylan
```

---

## 6. Install Caddy

Caddy is your reverse proxy. It automatically obtains and renews HTTPS
certificates from Let's Encrypt — no Certbot, no cron jobs.

[Caddy install guide →](https://caddyserver.com/docs/install#debian-ubuntu-raspbian)
[Caddyfile reference →](https://caddyserver.com/docs/caddyfile)

```bash
apt install -y debian-keyring debian-archive-keyring apt-transport-https

curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | \
  gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg

curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | \
  tee /etc/apt/sources.list.d/caddy-stable.list

apt update
apt install -y caddy

systemctl enable --now caddy
caddy version
```

The config file lives at `/etc/caddy/Caddyfile`. After any edit:
```bash
caddy fmt --overwrite /etc/caddy/Caddyfile   # validates + formats
systemctl reload caddy
```

---

## 7. Router: Port Forwarding

In your router admin panel, find **Port Forwarding** and add:

| Name | External Port | Internal IP | Internal Port | Protocol |
|---|---|---|---|---|
| Web HTTP | 80 | 192.168.1.50 | 80 | TCP |
| Web HTTPS | 443 | 192.168.1.50 | 443 | TCP |

Replace `192.168.1.50` with your server's reserved local IP.

### Verify it works

From a phone on **cellular** (not Wi-Fi), visit `http://YOUR_PUBLIC_IP`.
Get your public IP:
```bash
curl -sf https://api.ipify.org
```
If Caddy responds at all (even a 404), port forwarding is working.

---

## 8. GoDaddy: Dynamic DNS

Residential IPs can change. This script checks your public IP every 5 minutes
and updates your GoDaddy A records automatically.

### Get your GoDaddy API credentials

1. Go to [GoDaddy Developer Portal →](https://developer.godaddy.com/keys)
2. Click **Create New API Key**
3. Name it e.g. `ddns-server`, environment **Production**
4. Copy the **Key** and **Secret** — you only see the secret once

### Store credentials on the server

```bash
echo 'GODADDY_API_KEY=your_key_here' >> /etc/environment
echo 'GODADDY_API_SECRET=your_secret_here' >> /etc/environment
source /etc/environment
```

### Create the dynamic DNS script

```bash
nano /usr/local/bin/update-dns.sh
```

```bash
#!/bin/bash

GODADDY_API_KEY="${GODADDY_API_KEY}"
GODADDY_API_SECRET="${GODADDY_API_SECRET}"
DOMAIN="koshkikode.com"

RECORDS=("@" "www" "vetviona" "unshelvd" "downloads")

IP_FILE="/tmp/last_known_ip.txt"
LOG="/var/log/ddns.log"

CURRENT_IP=$(curl -sf https://api.ipify.org)

if [ -z "$CURRENT_IP" ]; then
  echo "$(date): Failed to get public IP" >> "$LOG"
  exit 1
fi

LAST_IP=$(cat "$IP_FILE" 2>/dev/null)
[ "$CURRENT_IP" = "$LAST_IP" ] && exit 0

echo "$(date): IP changed ${LAST_IP:-none} -> $CURRENT_IP — updating GoDaddy" >> "$LOG"

for RECORD in "${RECORDS[@]}"; do
  RESPONSE=$(curl -sf -X PUT \
    "https://api.godaddy.com/v1/domains/${DOMAIN}/records/A/${RECORD}" \
    -H "Authorization: sso-key ${GODADDY_API_KEY}:${GODADDY_API_SECRET}" \
    -H "Content-Type: application/json" \
    -d "[{\"data\":\"${CURRENT_IP}\",\"ttl\":600}]")
  STATUS=$?
  if [ $STATUS -eq 0 ]; then
    echo "$(date):   ✓ ${RECORD}.${DOMAIN} -> ${CURRENT_IP}" >> "$LOG"
  else
    echo "$(date):   ✗ Failed to update ${RECORD}.${DOMAIN} (curl exit $STATUS)" >> "$LOG"
  fi
done

echo "$CURRENT_IP" > "$IP_FILE"
```

```bash
chmod +x /usr/local/bin/update-dns.sh

# Test manually first
/usr/local/bin/update-dns.sh
cat /var/log/ddns.log
```

### Add the cron job

```bash
crontab -e
# Add this line:
*/5 * * * * /usr/local/bin/update-dns.sh
```

### Verify GoDaddy DNS is pointing to you

```bash
curl -sf \
  -H "Authorization: sso-key ${GODADDY_API_KEY}:${GODADDY_API_SECRET}" \
  "https://api.godaddy.com/v1/domains/koshkikode.com/records/A/@" | jq .
```

---

## 9. Install Node.js

The license backend requires Node.js 18 LTS or later.

[NodeSource install guide →](https://github.com/nodesource/distributions)

```bash
curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
apt install -y nodejs
node --version   # should print v20.x.x
npm --version
```

---

## 10. Deploy MinIO (Object Storage)

MinIO stores the license database as a single JSON object. It speaks the
standard S3 protocol — the same API used by AWS S3, Backblaze B2, and
Cloudflare R2. Running it locally means zero ongoing storage costs.

[MinIO documentation →](https://min.io/docs/minio/container/index.html)

### Run MinIO in Docker

```bash
docker run -d \
  --name minio \
  --restart unless-stopped \
  -p 9000:9000 \
  -p 9001:9001 \
  -e MINIO_ROOT_USER=admin \
  -e MINIO_ROOT_PASSWORD=change_this_strong_password \
  -v /data/minio:/data \
  quay.io/minio/minio server /data --console-address ":9001"
```

### Create the bucket

Install the MinIO client:
```bash
curl -Lo /usr/local/bin/mc \
  https://dl.min.io/client/mc/release/linux-amd64/mc
chmod +x /usr/local/bin/mc
```

```bash
# Point mc at your local MinIO
mc alias set local http://localhost:9000 admin change_this_strong_password

# Create the bucket with no public access
mc mb local/vetviona-licenses
mc anonymous set none local/vetviona-licenses

# Verify
mc ls local/
```

### MinIO admin console

The MinIO web UI is available at `http://localhost:9001` when you're SSHed in
with a port-forward tunnel, or you can expose it behind Caddy on a private
subdomain. Do **not** expose port 9001 publicly without authentication.

To access from your local machine:
```bash
ssh -L 9001:localhost:9001 dylan@YOUR_SERVER_IP
# Then open http://localhost:9001 in your browser
```

---

## 11. Deploy the License Backend

### Create a service user

Run the license server as a dedicated non-root user:
```bash
useradd -r -s /bin/false -d /opt/vetviona vetviona
mkdir -p /opt/vetviona
```

### Clone the repo

```bash
cd /opt
git clone https://github.com/KoshkiKode/vetviona.git
cd vetviona/backend
```

### Install dependencies

```bash
# As root or with sudo
npm install nodemailer@^7.0.11   # real email delivery
npm install @aws-sdk/client-s3   # S3-protocol client — works with MinIO, B2, R2
```

> **Note:** `@aws-sdk/client-s3` is the standard S3-protocol library. It works
> with any S3-compatible provider — MinIO, Backblaze B2, Cloudflare R2. No AWS
> account or AWS services are involved.

### Configure environment

```bash
cp .env.example .env
nano .env
```

```env
PORT=8090

# Generate with: openssl rand -hex 32
ADMIN_SECRET=paste-generated-secret-here

# Generate with: openssl rand -hex 32  — must be stable across restarts
LICENSE_KEY_SECRET=paste-generated-secret-here

MAX_DEVICES_PER_LICENSE=15

# --- SMTP ---
SMTP_HOST=smtp.your-provider.com
SMTP_PORT=587
SMTP_USER=your-smtp-user
SMTP_PASS=your-smtp-password
SMTP_SECURE=false
EMAIL_FROM=Vetviona <noreply@koshkikode.com>

# --- MinIO (local S3-compatible storage) ---
S3_BUCKET=vetviona-licenses
S3_KEY=vetviona/license-db.json
S3_REGION=us-east-1
S3_ENDPOINT=http://localhost:9000
AWS_ACCESS_KEY_ID=admin
AWS_SECRET_ACCESS_KEY=change_this_strong_password
```

Generate secrets:
```bash
openssl rand -hex 32   # run twice — once for ADMIN_SECRET, once for LICENSE_KEY_SECRET
```

### Set correct ownership

```bash
chown -R vetviona:vetviona /opt/vetviona
chmod 600 /opt/vetviona/backend/.env
```

### Create the systemd service

```bash
nano /etc/systemd/system/vetviona-license.service
```

```ini
[Unit]
Description=Vetviona License Backend
After=network.target docker.service
Requires=docker.service

[Service]
Type=simple
User=vetviona
WorkingDirectory=/opt/vetviona/backend
ExecStart=/usr/bin/node license_server.js
Restart=on-failure
RestartSec=5
EnvironmentFile=/opt/vetviona/backend/.env

# Security hardening
NoNewPrivileges=yes
PrivateTmp=yes
ProtectSystem=strict
ReadWritePaths=/opt/vetviona/backend

[Install]
WantedBy=multi-user.target
```

```bash
systemctl daemon-reload
systemctl enable --now vetviona-license

# Watch startup logs
journalctl -fu vetviona-license
```

You should see the server print its port and confirm MinIO connectivity.

### Add to Caddy

Edit `/etc/caddy/Caddyfile` and add:
```
vetviona.koshkikode.com {
    reverse_proxy localhost:8090

    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}
```

```bash
caddy fmt --overwrite /etc/caddy/Caddyfile
systemctl reload caddy
```

Visit `https://vetviona.koshkikode.com` — Caddy provisions the SSL cert on
the first request (~5 seconds).

### Test the deployment

```bash
# Health check
curl -sf https://vetviona.koshkikode.com/health | jq .

# Verify SMTP works (sends a test token to your email)
curl -X POST https://vetviona.koshkikode.com/auth/request-token \
  -H "Content-Type: application/json" \
  -d '{"email":"your@email.com"}'
```

---

## 12. Caddy Config: Full Example

`/etc/caddy/Caddyfile` — combined with the rest of the KoshkiKode stack:

```
# KoshkiKode main site
koshkikode.com {
    root * /var/www/website
    file_server

    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
        Permissions-Policy "geolocation=(), microphone=(), camera=()"
    }

    try_files {path} {path}/index.html /index.html
}

www.koshkikode.com {
    redir https://koshkikode.com{uri} permanent
}

# Unshelvd marketplace
unshelvd.koshkikode.com {
    reverse_proxy localhost:8080
}

# Vetviona license backend
vetviona.koshkikode.com {
    reverse_proxy localhost:8090

    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "DENY"
        Referrer-Policy "strict-origin-when-cross-origin"
    }
}

# Paywalled downloads
downloads.koshkikode.com {
    reverse_proxy localhost:3001
}
```

Caddy handles HTTPS for all of these automatically. After any edit:
```bash
caddy fmt --overwrite /etc/caddy/Caddyfile
systemctl reload caddy
```

---

## 13. Flutter: Build Against Your Server

The Vetviona app is built with Flutter. License backend URL is injected at
build time via `--dart-define`.

[Flutter install guide →](https://docs.flutter.dev/get-started/install)

### Development (local server)

```bash
flutter run \
  --dart-define=LICENSE_BACKEND_URL=http://127.0.0.1:8090
```

### Production build

```bash
# Android
flutter build apk --release \
  --dart-define=PAID=true \
  --dart-define=LICENSE_BACKEND_URL=https://vetviona.koshkikode.com

# Android App Bundle (for Play Store)
flutter build appbundle --release \
  --dart-define=PAID=true \
  --dart-define=LICENSE_BACKEND_URL=https://vetviona.koshkikode.com

# iOS
flutter build ios --release \
  --dart-define=PAID=true \
  --dart-define=LICENSE_BACKEND_URL=https://vetviona.koshkikode.com

# Windows
flutter build windows --release \
  --dart-define=PAID=true \
  --dart-define=LICENSE_BACKEND_URL=https://vetviona.koshkikode.com

# macOS
flutter build macos --release \
  --dart-define=PAID=true \
  --dart-define=LICENSE_BACKEND_URL=https://vetviona.koshkikode.com

# Linux
flutter build linux --release \
  --dart-define=PAID=true \
  --dart-define=LICENSE_BACKEND_URL=https://vetviona.koshkikode.com
```

### Verify the build target

After building, confirm the embedded URL:
```bash
# Android APK — search for the URL string in the binary
strings build/app/outputs/flutter-apk/app-release.apk | grep koshkikode
```

---

## 14. Backups

### Nightly MinIO backup

The license database is a single JSON object in MinIO. Back it up nightly:

```bash
nano /usr/local/bin/backup-vetviona.sh
```

```bash
#!/bin/bash
DATE=$(date +%Y-%m-%d)
BACKUP_DIR="/var/backups/vetviona"
mkdir -p "$BACKUP_DIR"

# Pull the license DB from MinIO
mc cp local/vetviona-licenses/vetviona/license-db.json \
  "$BACKUP_DIR/license-db-$DATE.json"

# Compress
gzip "$BACKUP_DIR/license-db-$DATE.json"

# Keep only last 30 days
find "$BACKUP_DIR" -name "*.json.gz" -mtime +30 -delete

echo "$(date): Vetviona backup complete — $BACKUP_DIR/license-db-$DATE.json.gz" \
  >> /var/log/backup.log
```

```bash
chmod +x /usr/local/bin/backup-vetviona.sh
crontab -e
# Add:
0 3 * * * /usr/local/bin/backup-vetviona.sh
```

### Offsite backup

For offsite resilience, replicate the backup directory to
[Backblaze B2](https://www.backblaze.com/cloud-storage) using
[restic](https://restic.readthedocs.io):

```bash
apt install -y restic

# Initialize a B2 repo (run once)
restic -r b2:your-bucket-name:/vetviona-backups init

# Add to crontab (runs after the local backup at 3:05 AM)
5 3 * * * restic -r b2:your-bucket-name:/vetviona-backups \
  backup /var/backups/vetviona --quiet
```

---

## 15. Maintenance Cheat Sheet

```bash
# SSH in
ssh dylan@192.168.1.50

# License backend status and logs
systemctl status vetviona-license
journalctl -fu vetviona-license

# Restart the license backend
systemctl restart vetviona-license

# Update the license backend
cd /opt/vetviona
git pull
systemctl restart vetviona-license

# MinIO container status
docker ps | grep minio

# MinIO logs
docker logs minio -f

# Browse MinIO buckets
mc ls local/vetviona-licenses/

# Read the current license DB (useful for debugging)
mc cat local/vetviona-licenses/vetviona/license-db.json | jq .

# Reload Caddy after config edit
caddy fmt --overwrite /etc/caddy/Caddyfile && systemctl reload caddy

# Caddy logs (SSL issues show here)
journalctl -u caddy -f

# Dynamic DNS log
tail -f /var/log/ddns.log

# Backup log
tail -f /var/log/backup.log

# Disk usage
df -h

# RAM usage
free -h

# What's listening on which ports
ss -tlnp
```

---

## 16. Quick Reference Links

| Resource | URL |
|---|---|
| Debian 12 Download | https://www.debian.org/distrib/netinst |
| Rufus (Windows USB flasher) | https://rufus.ie |
| Balena Etcher (Mac/Linux) | https://etcher.balena.io |
| PuTTY (SSH client, Windows) | https://www.putty.org |
| Docker Install (Debian) | https://docs.docker.com/engine/install/debian/ |
| Docker Compose Docs | https://docs.docker.com/compose/ |
| Caddy Install | https://caddyserver.com/docs/install |
| Caddy Caddyfile Reference | https://caddyserver.com/docs/caddyfile |
| MinIO Docker Docs | https://min.io/docs/minio/container/index.html |
| MinIO Client (mc) | https://min.io/docs/minio/linux/reference/minio-mc.html |
| NodeSource (Node.js install) | https://github.com/nodesource/distributions |
| GoDaddy DNS Manager | https://dcc.godaddy.com/manage/dns |
| GoDaddy Developer API Keys | https://developer.godaddy.com/keys |
| GoDaddy DNS API Docs | https://developer.godaddy.com/doc/endpoint/domains |
| Flutter Install | https://docs.flutter.dev/get-started/install |
| restic Backup Tool | https://restic.readthedocs.io |
| Backblaze B2 | https://www.backblaze.com/cloud-storage |

---

*KoshkiKode LLC — Dylan Moore*
