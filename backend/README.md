# Vetviona License Backend

A lightweight, self-hostable Node.js license server for Vetviona. Handles account registration, email verification, paid-license verification, license gifting, re-entry license codes, MFA, and voucher creation.

---

## Quick Start

```bash
cd backend
node license_server.js
```

No dependencies are required to run in dev mode. Optional deps unlock real email and object storage:

```bash
npm install nodemailer@^7.0.11   # real SMTP email
npm install @aws-sdk/client-s3   # S3-compatible object storage (production)
```

See [`DEPLOY.md`](./DEPLOY.md) for the full self-hosting guide (reverse proxy, TLS, systemd, object storage).

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | HTTP listen port |
| `LICENSE_DB_PATH` | `backend/license-db.json` | Local DB file path (dev only — ignored when `S3_BUCKET` is set) |
| `ADMIN_SECRET` | *(random, printed at startup)* | Protects `POST /v1/admin/voucher` — always set in production |
| `LICENSE_KEY_SECRET` | *(auto-generated, persisted in DB)* | HMAC secret for re-entry license codes — must be a stable ≥ 32-char value in production |
| `MAX_DEVICES_PER_LICENSE` | `15` | Max verified devices per license type per account |
| `SMTP_HOST` | *(unset = dev mode)* | SMTP hostname — leave unset to log tokens to console |
| `SMTP_PORT` | `587` | SMTP port |
| `SMTP_USER` | *(unset)* | SMTP username |
| `SMTP_PASS` | *(unset)* | SMTP password |
| `SMTP_SECURE` | `false` | Set `true` for port-465 TLS |
| `EMAIL_FROM` | `Vetviona <noreply@vetviona.local>` | From address for outgoing emails |
| `S3_BUCKET` | *(unset)* | Bucket name — set to enable object storage instead of local file |
| `S3_KEY` | `vetviona/license-db.json` | Object key within the bucket |
| `S3_REGION` | `us-east-1` | Region (any value works for providers that don't require one) |
| `S3_ENDPOINT` | *(unset)* | Custom endpoint — required for MinIO, Backblaze B2, Cloudflare R2, etc. |
| `AWS_ACCESS_KEY_ID` | *(unset)* | Access key for your object storage provider |
| `AWS_SECRET_ACCESS_KEY` | *(unset)* | Secret key for your object storage provider |

Copy `.env.example` to `.env` to get started.

---

## Object Storage

In production the license database must live in durable object storage — local disk is lost on redeploys. Set `S3_BUCKET` (and `S3_ENDPOINT` for self-hosted/third-party providers) to switch from the local JSON file to any S3-compatible backend:

| Provider | `S3_ENDPOINT` example |
|----------|-----------------------|
| MinIO (self-hosted) | `http://localhost:9000` |
| Backblaze B2 | `https://s3.us-west-004.backblazeb2.com` |
| Cloudflare R2 | `https://<ACCOUNT_ID>.r2.cloudflarestorage.com` |
| Hetzner Object Storage | `https://<LOCATION>.your-objectstorage.com` |

See [`DEPLOY.md`](./DEPLOY.md) for step-by-step setup for each provider.

---

## Dev Mode Behaviour

When `SMTP_HOST` is not set the server runs in dev mode:
- All email tokens (verification codes, gift tokens, voucher codes) are **printed to stdout**.
- They are also **returned in API responses** as `_devToken` / `_devTokens`.
- A random `ADMIN_SECRET` is generated and printed at startup.

---

## API Endpoints

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/v1/account/register` | Create account + issue entitlements |
| `POST` | `/v1/account/verify-email` | Verify email address |
| `POST` | `/v1/account/resend-verification` | Resend verification email |
| `POST` | `/v1/account/login` | Authenticate and get session token |
| `POST` | `/v1/account/logout` | Invalidate session token |
| `POST` | `/v1/account/logout-all` | Invalidate all sessions (bump token version) |
| `GET`  | `/v1/account/sync` | Fetch account state (requires Bearer token) |
| `POST` | `/v1/account/change-password` | Change password |
| `POST` | `/v1/account/forgot-password` | Request password reset email |
| `POST` | `/v1/account/reset-password` | Complete password reset |
| `POST` | `/v1/account/mfa/enroll` | Begin TOTP MFA enrollment |
| `POST` | `/v1/account/mfa/confirm` | Confirm enrollment + get recovery codes |
| `POST` | `/v1/account/mfa/disable` | Disable MFA |
| `POST` | `/v1/account/mfa/verify` | Verify TOTP code (step-up auth) |
| `POST` | `/v1/license/verify` | Verify license and register device |
| `POST` | `/v1/license/gift` | Send a license gift to another user |
| `POST` | `/v1/license/claim-gift` | Claim a pending gift |
| `POST` | `/v1/admin/voucher` | Create a voucher code (admin only) |
| `POST` | `/v1/voucher/redeem` | Redeem a voucher |
| `POST` | `/v1/tree/upload` | Upload a tree snapshot |
| `GET`  | `/v1/tree/latest` | Download the latest tree snapshot |
| `GET`  | `/health` | Health check |
