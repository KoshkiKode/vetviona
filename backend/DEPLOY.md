# Vetviona License Backend — Self-Hosting Guide

> **Self-hosted deployment only.** This guide covers running the Vetviona license backend
> on your own hardware (a home server or any Linux VPS) using Docker, Caddy, and GoDaddy DNS.

The license backend is a single Node.js process. It stores the license database as a JSON
file on disk (or optionally in any S3-compatible object store). No cloud provider account
required.

---

## Table of Contents

1. [Architecture Overview](#1-architecture-overview)
2. [Pre-deploy Checklist](#2-pre-deploy-checklist)
3. [Clone and Configure](#3-clone-and-configure)
4. [Environment Variables Reference](#4-environment-variables-reference)
5. [Dockerfile](#5-dockerfile)
6. [Run with Docker](#6-run-with-docker)
7. [Caddy Configuration](#7-caddy-configuration)
8. [DNS — GoDaddy](#8-dns--godaddy)
9. [Systemd Service (without Docker)](#9-systemd-service-without-docker)
10. [Backups](#10-backups)
11. [Updates](#11-updates)
12. [Troubleshooting](#12-troubleshooting)

---

## 1. Architecture Overview

```
Internet
    │
    ▼
GoDaddy DNS  ──▶  A record → your public IP  (updated by cron every 5 min if dynamic IP)
    │
    ▼
Router  ──▶  Port 80/443 forwarded to server LAN IP
    │
    ▼
Caddy (port 80/443)  ──▶  auto-HTTPS via Let's Encrypt
    │
    └──▶  license.koshkikode.com  →  localhost:8080  (license-server container / process)
    │
    ▼
license_server.js
    └── license-db.json  (local file on disk, bind-mounted into container)
```

The license server is never exposed directly to the internet — all traffic flows through Caddy.

---

## 2. Pre-deploy Checklist

- [ ] Server running Debian 12 (or any systemd Linux) with Docker installed
- [ ] Caddy installed and running (`systemctl status caddy`)
- [ ] Ports 80 and 443 forwarded in your router to the server's LAN IP
- [ ] `license.koshkikode.com` A record exists in GoDaddy pointing at your public IP
      (see [Section 8](#8-dns--godaddy))
- [ ] SMTP credentials ready for transactional email (verification codes, gift notifications)
- [ ] `ADMIN_SECRET` and `LICENSE_KEY_SECRET` generated (see Section 4)

---

## 3. Clone and Configure

```bash
cd /opt
git clone https://github.com/KoshkiKode/vetviona.git
cd vetviona/backend

# Create the data directory (persists the license DB across container restarts)
mkdir -p /var/lib/vetviona-license
touch /var/lib/vetviona-license/license-db.json

# Copy and fill in the environment file
cp .env.example .env   # if .env.example exists, otherwise create .env manually
nano .env
```

---

## 4. Environment Variables Reference

Create `/opt/vetviona/backend/.env`:

```bash
# --- Server ---
PORT=8080

# --- License database ---
# Path INSIDE the container (matches the bind mount in Section 6)
LICENSE_DB_PATH=/data/license-db.json

# REQUIRED: stable random secret for re-entry license code signing.
# Generate: openssl rand -hex 32
# Must not change after first run — changing it invalidates all users' re-entry codes.
LICENSE_KEY_SECRET=<generate-with-openssl-rand-hex-32>

# REQUIRED: protects the admin voucher-creation endpoint.
# Generate: openssl rand -hex 24
ADMIN_SECRET=<generate-with-openssl-rand-hex-24>

# --- Email (SMTP) ---
# Leave unset for dev mode — tokens printed to console instead of emailed.
SMTP_HOST=smtp.yourprovider.com
SMTP_PORT=587
SMTP_USER=your-smtp-username
SMTP_PASS=your-smtp-password
SMTP_SECURE=false          # set true for port 465 (TLS)
EMAIL_FROM=Vetviona <noreply@koshkikode.com>

# --- Limits ---
MAX_DEVICES_PER_LICENSE=15
```

> **Never commit `.env` to git.** It is in `.gitignore`.

### Optional — S3-compatible object storage

If you want off-box storage for the license database, the license server supports any
S3-compatible endpoint. Suitable providers include **Backblaze B2**, **Cloudflare R2**,
or a self-hosted **MinIO** instance. Add these to `.env`:

```bash
S3_BUCKET=my-vetviona-licenses
S3_KEY=vetviona/license-db.json
S3_REGION=auto                          # use 'auto' for Cloudflare R2
S3_ENDPOINT_URL=https://...             # R2/B2/MinIO endpoint URL
S3_ACCESS_KEY_ID=<your-key>
S3_SECRET_ACCESS_KEY=<your-secret>
```

When `S3_BUCKET` is set, the local file path is ignored.
`LICENSE_KEY_SECRET` **must** be set explicitly when using object storage (no local file to persist it).

---

## 5. Dockerfile

Add this file as `backend/Dockerfile` (not committed to the repo — create it on your server):

```dockerfile
FROM node:20-alpine
WORKDIR /app
COPY package.json ./
RUN npm install --omit=dev --include=optional
COPY license_server.js ./
EXPOSE 8080
CMD ["node", "license_server.js"]
```

---

## 6. Run with Docker

```bash
cd /opt/vetviona/backend

# Build the image
docker build -t vetviona-license .

# Run (bind-mount the data directory and load the .env file)
docker run -d \
  --name vetviona-license \
  --restart unless-stopped \
  --env-file .env \
  -v /var/lib/vetviona-license:/data \
  -p 127.0.0.1:8080:8080 \
  vetviona-license
```

`-p 127.0.0.1:8080:8080` binds only to localhost — Caddy proxies inbound HTTPS.
The container restarts automatically after a reboot.

Check it's up:
```bash
docker logs vetviona-license
curl http://localhost:8080/health
# Expected: {"ok":true}
```

---

## 7. Caddy Configuration

Edit `/etc/caddy/Caddyfile` and add:

```
license.koshkikode.com {
    reverse_proxy localhost:8080
}
```

Reload Caddy:

```bash
caddy fmt --overwrite /etc/caddy/Caddyfile
systemctl reload caddy
```

Caddy provisions the Let's Encrypt SSL certificate automatically on the first request.
Verify:

```bash
curl https://license.koshkikode.com/health
# Expected: {"ok":true}
```

Check Caddy logs if the cert doesn't provision:
```bash
journalctl -u caddy -f
# Common causes: port 80 not forwarded, DNS not pointing to you yet
```

---

## 8. DNS — GoDaddy

1. Log in to [GoDaddy](https://dcc.godaddy.com/manage/dns) and open the `koshkikode.com` DNS settings.
2. Add (or update) an **A record**:
   - **Type:** A
   - **Name:** `license`
   - **Value:** your server's public IP address
   - **TTL:** 600 (10 minutes)
3. Wait up to 10 minutes for propagation.
4. Verify: `dig license.koshkikode.com +short` should return your IP.

### Dynamic IP (home server)

If your IP changes, set up a cron job to update the GoDaddy A record automatically:

```bash
# Install jq if not present
apt-get install -y jq

# Create the update script
cat > /usr/local/bin/godaddy-ddns-license.sh << 'EOF'
#!/bin/bash
DOMAIN="koshkikode.com"
SUBDOMAIN="license"
API_KEY="YOUR_GODADDY_API_KEY"
API_SECRET="YOUR_GODADDY_API_SECRET"

CURRENT_IP=$(curl -sf https://api.ipify.org)
GODADDY_IP=$(curl -sf "https://api.godaddy.com/v1/domains/${DOMAIN}/records/A/${SUBDOMAIN}" \
  -H "Authorization: sso-key ${API_KEY}:${API_SECRET}" | jq -r '.[0].data')

if [ "$CURRENT_IP" != "$GODADDY_IP" ]; then
  curl -sf -X PUT "https://api.godaddy.com/v1/domains/${DOMAIN}/records/A/${SUBDOMAIN}" \
    -H "Authorization: sso-key ${API_KEY}:${API_SECRET}" \
    -H "Content-Type: application/json" \
    -d "[{\"data\":\"${CURRENT_IP}\",\"ttl\":600}]"
  echo "$(date): updated ${SUBDOMAIN}.${DOMAIN} → ${CURRENT_IP}"
fi
EOF

chmod +x /usr/local/bin/godaddy-ddns-license.sh

# Run every 5 minutes
echo "*/5 * * * * root /usr/local/bin/godaddy-ddns-license.sh >> /var/log/ddns-license.log 2>&1" \
  > /etc/cron.d/godaddy-ddns-license
```

Fill in your GoDaddy API key and secret from [GoDaddy Developer Portal](https://developer.godaddy.com/keys).

---

## 9. Systemd Service (without Docker)

If you prefer running the process directly (no Docker):

```bash
# Install dependencies
cd /opt/vetviona/backend
npm install --omit=dev --include=optional

# Create a systemd unit
cat > /etc/systemd/system/vetviona-license.service << 'EOF'
[Unit]
Description=Vetviona License Backend
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=/opt/vetviona/backend
EnvironmentFile=/opt/vetviona/backend/.env
ExecStart=/usr/bin/node license_server.js
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable --now vetviona-license

# Check status
systemctl status vetviona-license
journalctl -u vetviona-license -f
```

---

## 10. Backups

The entire license database is a single JSON file. Back it up nightly:

```bash
cat > /etc/cron.d/vetviona-license-backup << 'EOF'
0 3 * * * root \
  cp /var/lib/vetviona-license/license-db.json \
     /var/backups/vetviona-license-db-$(date +\%Y-\%m-\%d).json && \
  find /var/backups -name 'vetviona-license-db-*.json' -mtime +14 -delete
EOF
```

This keeps 14 days of daily snapshots. For off-box safety, copy backups to a separate
machine or external drive periodically.

### Restore from backup

```bash
# Stop the server
docker stop vetviona-license   # or: systemctl stop vetviona-license

# Restore
cp /var/backups/vetviona-license-db-2026-01-01.json \
   /var/lib/vetviona-license/license-db.json

# Start again
docker start vetviona-license   # or: systemctl start vetviona-license
```

---

## 11. Updates

```bash
cd /opt/vetviona
git pull

# Rebuild and restart the container
cd backend
docker build -t vetviona-license .
docker stop vetviona-license
docker rm vetviona-license
docker run -d \
  --name vetviona-license \
  --restart unless-stopped \
  --env-file .env \
  -v /var/lib/vetviona-license:/data \
  -p 127.0.0.1:8080:8080 \
  vetviona-license

# Or if running via systemd (no Docker):
systemctl restart vetviona-license
```

---

## 12. Troubleshooting

```bash
# Container won't start
docker logs vetviona-license

# Health check
curl http://localhost:8080/health
curl https://license.koshkikode.com/health

# SSL cert not provisioning
journalctl -u caddy -f
# Common causes: port 80 not forwarded in router, DNS not pointing to you yet

# Check what's listening
ss -tlnp | grep -E '80|443|8080'

# Dynamic DNS — check if IP is updating
tail -f /var/log/ddns-license.log
curl https://api.ipify.org   # your current public IP

# Database file permissions
ls -la /var/lib/vetviona-license/license-db.json
# Should be readable/writable by the Docker user (uid 1000 in node:alpine)
# Fix: chown 1000:1000 /var/lib/vetviona-license/license-db.json
```

### Common errors

| Error | Fix |
|---|---|
| `EACCES` on `license-db.json` | Fix file ownership: `chown 1000:1000 /var/lib/vetviona-license/license-db.json` |
| `ENOENT` on `license-db.json` | Create it: `touch /var/lib/vetviona-license/license-db.json` |
| SSL cert fails with `no such host` | DNS hasn't propagated — wait up to 10 min, or check GoDaddy |
| `LICENSE_KEY_SECRET` changes on restart | Set it explicitly in `.env` — do not leave it unset in production |
| Email not delivering | Check `SMTP_HOST`, `SMTP_PORT`, credentials. In dev mode (no SMTP), tokens are logged to console. |

---

## Flutter app integration

Build the Flutter app pointing at your self-hosted license server:

```bash
flutter build <platform> \
  --dart-define=LICENSE_BACKEND_URL=https://license.koshkikode.com
```

---

*KoshkiKode — Self-hosted on Debian + Docker + Caddy + GoDaddy DNS*
