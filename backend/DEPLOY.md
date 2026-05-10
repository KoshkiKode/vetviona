# Vetviona License Backend — Self-Hosting Guide

This guide covers everything you need to run the Vetviona license backend on your own infrastructure.

---

## Requirements

- **Node.js 18+** (LTS recommended)
- A publicly reachable host (any Linux VPS, bare metal, or home server with port forwarding)
- A reverse proxy with TLS (nginx or Caddy recommended)
- Optional: SMTP credentials for transactional email
- Optional: S3-compatible object storage for durable database persistence

---

## Quick Start (Development)

```bash
cd backend
node license_server.js
```

In dev mode (no `S3_BUCKET`, no `SMTP_HOST` set):
- The license database is stored as a local JSON file (`backend/license-db.json`).
- Email tokens (verification codes, vouchers, etc.) are printed to the console and returned in API responses as `_devToken`.
- A random `ADMIN_SECRET` is printed at startup.

---

## Production Setup

### 1. Install optional dependencies

```bash
cd backend
npm install nodemailer@^7.0.11   # real email delivery
npm install @aws-sdk/client-s3   # S3-compatible object storage
```

### 2. Configure environment variables

Copy `.env.example` to `.env` and fill in your values, or export them directly.

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | HTTP port the server listens on |
| `LICENSE_DB_PATH` | `backend/license-db.json` | Local DB path (dev only — ignored when `S3_BUCKET` is set) |
| `ADMIN_SECRET` | *(random, printed at startup)* | Protects the voucher-creation endpoint — **always set in production** |
| `LICENSE_KEY_SECRET` | *(auto-generated, persisted in DB)* | HMAC secret for re-entry license codes — **must be a stable ≥ 32-char value in production** |
| `MAX_DEVICES_PER_LICENSE` | `15` | Max verified devices per license type per account |
| `SMTP_HOST` | *(unset = dev mode)* | SMTP hostname for real email delivery |
| `SMTP_PORT` | `587` | SMTP port |
| `SMTP_USER` | *(unset)* | SMTP username |
| `SMTP_PASS` | *(unset)* | SMTP password |
| `SMTP_SECURE` | `false` | Set `true` for port-465 TLS |
| `EMAIL_FROM` | `Vetviona <noreply@vetviona.local>` | From address for outgoing emails |
| `S3_BUCKET` | *(unset)* | Bucket name — set to enable object storage |
| `S3_KEY` | `vetviona/license-db.json` | Object key within the bucket |
| `S3_REGION` | `us-east-1` | Region (any value works for providers that don't require one) |
| `S3_ENDPOINT` | *(unset)* | Custom endpoint URL — **required for non-AWS providers** |
| `AWS_ACCESS_KEY_ID` | *(unset)* | Access key for your object storage provider |
| `AWS_SECRET_ACCESS_KEY` | *(unset)* | Secret key for your object storage provider |

### 3. Set up object storage (production)

The license database must live in durable object storage in production — local disk is lost on redeploys. The backend speaks standard S3 protocol and works with any compatible provider.

#### MinIO (self-hosted, free)

```bash
# Run MinIO in Docker
docker run -d \
  --name minio \
  -p 9000:9000 -p 9001:9001 \
  -e MINIO_ROOT_USER=admin \
  -e MINIO_ROOT_PASSWORD=changeme \
  -v /data/minio:/data \
  quay.io/minio/minio server /data --console-address ":9001"

# Create the bucket (no public access)
mc alias set local http://localhost:9000 admin changeme
mc mb local/vetviona-licenses
mc anonymous set none local/vetviona-licenses
```

Env vars:
```bash
export S3_BUCKET=vetviona-licenses
export S3_ENDPOINT=http://localhost:9000
export S3_REGION=us-east-1
export AWS_ACCESS_KEY_ID=admin
export AWS_SECRET_ACCESS_KEY=changeme
```

#### Backblaze B2

1. Create a private bucket in the B2 dashboard.
2. Create an application key scoped to that bucket with read/write.
3. Copy the **Endpoint** from the bucket details page.

```bash
export S3_BUCKET=vetviona-licenses
export S3_ENDPOINT=https://s3.us-west-004.backblazeb2.com
export S3_REGION=us-west-004
export AWS_ACCESS_KEY_ID=<b2-key-id>
export AWS_SECRET_ACCESS_KEY=<b2-application-key>
```

#### Cloudflare R2

1. Create an R2 bucket in the Cloudflare dashboard.
2. Generate an R2 API Token with object read/write on that bucket.
3. Find your Account ID in the Cloudflare sidebar.

```bash
export S3_BUCKET=vetviona-licenses
export S3_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
export S3_REGION=auto
export AWS_ACCESS_KEY_ID=<r2-access-key-id>
export AWS_SECRET_ACCESS_KEY=<r2-secret-access-key>
```

### 4. Set up a reverse proxy with TLS

#### Caddy (recommended — automatic HTTPS)

```caddyfile
license.yourdomain.com {
    reverse_proxy localhost:8080
}
```

```bash
caddy run --config /etc/caddy/Caddyfile
```

#### nginx

```nginx
server {
    listen 443 ssl;
    server_name license.yourdomain.com;

    ssl_certificate     /etc/letsencrypt/live/license.yourdomain.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/license.yourdomain.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

### 5. Run as a systemd service

```ini
# /etc/systemd/system/vetviona-license.service
[Unit]
Description=Vetviona License Backend
After=network.target

[Service]
Type=simple
User=vetviona
WorkingDirectory=/opt/vetviona/backend
ExecStart=/usr/bin/node license_server.js
Restart=on-failure
RestartSec=5
EnvironmentFile=/opt/vetviona/backend/.env

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now vetviona-license
sudo journalctl -fu vetviona-license
```

### 6. Point the app at your backend

```bash
# Build time
flutter build <platform> --release \
  --dart-define=PAID=true \
  --dart-define=LICENSE_BACKEND_URL=https://license.yourdomain.com

# Development
flutter run --dart-define=LICENSE_BACKEND_URL=http://127.0.0.1:8080
```

---

## Production Checklist

- [ ] `ADMIN_SECRET` set
- [ ] `LICENSE_KEY_SECRET` set to a stable ≥ 32-char value
- [ ] `S3_BUCKET` set — object storage active (not local disk)
- [ ] `S3_ENDPOINT` set if using a non-default provider
- [ ] Bucket has no public access
- [ ] `SMTP_HOST` set — real transactional email enabled
- [ ] Reverse proxy in front of the backend (nginx/Caddy)
- [ ] Valid TLS certificate on the proxy
- [ ] Firewall blocks direct access to port 8080 from the public internet
- [ ] `license_server.js` running as a non-root user
- [ ] Systemd service configured for auto-restart

---

## Troubleshooting

**Email tokens not arriving** — Check `SMTP_HOST` is set. In dev mode tokens are logged to stdout and returned in API responses.

**`NoSuchKey` error on startup** — Normal on first run; the DB object doesn't exist yet and will be created on the first write.

**`forcePathStyle` / 403 errors with MinIO** — The backend sets `forcePathStyle: true` automatically when `S3_ENDPOINT` is set. Verify your MinIO credentials and bucket name.

**Port already in use** — Change `PORT` in your `.env`.
