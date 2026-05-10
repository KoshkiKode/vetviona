# Vetviona License Backend

This backend handles only:

- Vetviona paid-license account registration with **email verification**
- paid-license verification for **apple** (`ios`), **android** (`android`), and **desktop** (`windows`/`macos`/`linux`)
- reusable, **verifiable re-entry license codes** for reinstall/multi-device flows
- a hard cap of **15 computers/devices per license type** (configurable via `MAX_DEVICES_PER_LICENSE`)
- **License gifting / transfer** — transfer a license to another account
- account license sync (entitlements + verified devices)
- password changes

It does **not** store genealogy data.

> **Deploying to a server?** See [**DEPLOY.md**](./DEPLOY.md) for the full
> self-hosting guide (Docker + Caddy + GoDaddy DNS).

---

## Run locally (dev)

```bash
cd backend
node license_server.js
```

In dev mode (no `SMTP_HOST` set), verification tokens and gift claim tokens are printed
to the console **and** returned in API responses as `_devToken` — no email setup needed.

### Installing optional dependencies

```bash
# For real email delivery (SMTP):
npm install nodemailer@^7.0.11

# For S3-compatible object storage (production, optional):
npm install @aws-sdk/client-s3
```

---

## Environment variables

| Variable | Default | Description |
|---|---|---|
| `PORT` | `8080` | HTTP port |
| `LICENSE_DB_PATH` | `backend/license-db.json` | Path to local JSON database. Ignored when `AWS_S3_BUCKET` is set. |
| `LICENSE_KEY_SECRET` | *(auto-generated and persisted in DB)* | HMAC secret for re-entry license codes. **Must be set explicitly in production** — changing it invalidates all users' codes. Generate: `openssl rand -hex 32` |
| `ADMIN_SECRET` | *(printed at startup in dev mode)* | Protects the voucher-creation endpoint. Generate: `openssl rand -hex 24` |
| `SMTP_HOST` | *(unset)* | SMTP server hostname. Unset = dev mode (tokens logged, not emailed). |
| `SMTP_PORT` | `587` | SMTP port |
| `SMTP_USER` | *(unset)* | SMTP username |
| `SMTP_PASS` | *(unset)* | SMTP password |
| `SMTP_SECURE` | `false` | Set `true` for TLS on port 465 |
| `EMAIL_FROM` | `Vetviona <noreply@vetviona.local>` | From address |
| `MAX_DEVICES_PER_LICENSE` | `15` | Max verified devices per license type |

### Optional — S3-compatible object storage

The local JSON file is fine for most self-hosted setups. If you want off-box durability
(e.g. Backblaze B2, Cloudflare R2, MinIO, or any S3-compatible service), add:

| Variable | Description |
|---|---|
| `AWS_S3_BUCKET` | Bucket name. Setting this enables S3 storage; local file is ignored. |
| `AWS_S3_KEY` | Object key path. Default: `vetviona/license-db.json` |
| `AWS_REGION` | Region or `auto` (Cloudflare R2) |
| `AWS_ENDPOINT_URL` | Custom endpoint URL for non-AWS providers (R2, B2, MinIO) |
| `AWS_ACCESS_KEY_ID` | Access key |
| `AWS_SECRET_ACCESS_KEY` | Secret key |

`LICENSE_KEY_SECRET` **must** be set explicitly when using S3 — there is no local file
to persist the auto-generated secret across restarts.

---

## Endpoints

- `GET /health`
- `POST /v1/account/register`
- `POST /v1/account/verify-email`
- `POST /v1/account/resend-verification`
- `POST /v1/account/change-password`
- `POST /v1/account/sync`
- `POST /v1/license/verify`
- `POST /v1/license/gift/initiate`
- `POST /v1/license/gift/claim`
- `POST /v1/license/gift/cancel`
- `POST /v1/license/voucher/create` *(admin-protected)*

### Register account

```bash
curl -X POST http://127.0.0.1:8080/v1/account/register \
  -H 'Content-Type: application/json' \
  -d '{
    "email":"owner@example.com",
    "password":"ChangeMe123!",
    "appleLicense":true,
    "androidLicense":true,
    "desktopLicense":true
  }'
```

### Verify account email

```bash
curl -X POST http://127.0.0.1:8080/v1/account/verify-email \
  -H 'Content-Type: application/json' \
  -d '{"email":"owner@example.com","token":"ABCD1234"}'
```

### Resend verification email

```bash
curl -X POST http://127.0.0.1:8080/v1/account/resend-verification \
  -H 'Content-Type: application/json' \
  -d '{"email":"owner@example.com","password":"ChangeMe123!"}'
```

### Change password

```bash
curl -X POST http://127.0.0.1:8080/v1/account/change-password \
  -H 'Content-Type: application/json' \
  -d '{
    "email":"owner@example.com",
    "currentPassword":"ChangeMe123!",
    "newPassword":"BetterPassword!1"
  }'
```

### Verify a paid app install

`appType` must be `"apple"`, `"android"`, or `"desktop"`.
Authenticate with either `email` + `password`, or `email` + `licenseCode`.

```bash
curl -X POST http://127.0.0.1:8080/v1/license/verify \
  -H 'Content-Type: application/json' \
  -d '{
    "email":"owner@example.com",
    "password":"ChangeMe123!",
    "appType":"desktop",
    "os":"linux",
    "deviceId":"example-device-1",
    "appVersion":"1.0.0"
  }'
```

Or by reusable re-entry code:

```bash
curl -X POST http://127.0.0.1:8080/v1/license/verify \
  -H 'Content-Type: application/json' \
  -d '{
    "email":"owner@example.com",
    "licenseCode":"DES-ABCD-EF12-3456-7890-ABCD-EF12",
    "appType":"desktop",
    "os":"linux",
    "deviceId":"example-device-2",
    "appVersion":"1.0.0"
  }'
```

Successful verification responses include:
- `reentryLicenseCodes` (per active license type; reusable/verifiable)
- `deviceLimitPerLicense`
- `devicesUsedForLicense`

### Create vouchers (admin)

```bash
curl -X POST http://127.0.0.1:8080/v1/license/voucher/create \
  -H 'Content-Type: application/json' \
  -d '{
    "adminSecret": "<your-admin-secret>",
    "licenseType": "desktop",
    "quantity": 3,
    "fromEmail": "purchaser@example.com",
    "notes": "Order #1234"
  }'
```

### Sync account licenses/devices

```bash
curl -X POST http://127.0.0.1:8080/v1/account/sync \
  -H 'Content-Type: application/json' \
  -d '{"email":"owner@example.com","password":"ChangeMe123!"}'
```

---

## Flutter app integration

```bash
flutter build <platform> \
  --dart-define=LICENSE_BACKEND_URL=https://license.koshkikode.com
```

Paid tiers require one successful backend verification before the app can open.
License management is accessible in-app via
**Settings → Vetviona License Account → Manage License Account**.
