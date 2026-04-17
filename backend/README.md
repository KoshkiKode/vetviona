# Vetviona License Backend

This backend handles only:

- Vetviona paid-license account registration with **email verification**
- paid-license verification for **apple** (`ios`), **android** (`android`), and **desktop** (`windows`/`macos`/`linux`)
- **License gifting / transfer** — transfer a license to another account
- account license sync (entitlements + verified devices)
- password changes

It does **not** store genealogy data.

## Run

```bash
cd backend
node license_server.js
```

Optional env vars:

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | HTTP port |
| `LICENSE_DB_PATH` | `backend/license-db.json` | Path to JSON database |
| `SMTP_HOST` | *(unset)* | SMTP server hostname. Leave unset for dev mode (tokens logged to console) |
| `SMTP_PORT` | `587` | SMTP port |
| `SMTP_USER` | *(unset)* | SMTP username |
| `SMTP_PASS` | *(unset)* | SMTP password |
| `SMTP_SECURE` | `false` | Set `true` for TLS on port 465 |
| `EMAIL_FROM` | `Vetviona <noreply@vetviona.local>` | From address |

**Dev mode (no SMTP):** verification codes and gift claim tokens are printed to the console **and** returned in API responses as `_devToken`.  Install nodemailer (`npm install nodemailer`) and set `SMTP_HOST` for real emails.

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

Response includes `_devToken` (dev mode) for the email verification code.

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

### Initiate a license gift / transfer

Transfers one of your licenses to another email address.  Requires email verification.
The license is put in escrow — the sender cannot use it until the gift is claimed or cancelled.

```bash
curl -X POST http://127.0.0.1:8080/v1/license/gift/initiate \
  -H 'Content-Type: application/json' \
  -d '{
    "email":"owner@example.com",
    "password":"ChangeMe123!",
    "licenseType":"apple",
    "toEmail":"recipient@example.com"
  }'
```

### Claim a gift

The recipient authenticates and claims by gift ID (from their sync response) or by the claim token (from the email they received).

```bash
# Claim by token
curl -X POST http://127.0.0.1:8080/v1/license/gift/claim \
  -H 'Content-Type: application/json' \
  -d '{"email":"recipient@example.com","password":"MyPassword!","token":"ABCD1234"}'

# Claim by gift ID
curl -X POST http://127.0.0.1:8080/v1/license/gift/claim \
  -H 'Content-Type: application/json' \
  -d '{"email":"recipient@example.com","password":"MyPassword!","giftId":"<uuid>"}'
```

### Cancel a gift (sender)

```bash
curl -X POST http://127.0.0.1:8080/v1/license/gift/cancel \
  -H 'Content-Type: application/json' \
  -d '{"email":"owner@example.com","password":"ChangeMe123!","licenseType":"apple"}'
```

### Sync account licenses/devices

```bash
curl -X POST http://127.0.0.1:8080/v1/account/sync \
  -H 'Content-Type: application/json' \
  -d '{"email":"owner@example.com","password":"ChangeMe123!"}'
```

## App integration

Set the Flutter app backend URL with:

```bash
--dart-define=LICENSE_BACKEND_URL=http://127.0.0.1:8080
```

Paid tiers require one successful backend verification before the app can open.
License transfers are accessible in-app via **Settings → Vetviona License Account → Manage License Account**.
