# Vetviona License Backend

This backend handles only:

- Vetviona paid-license account registration
- paid-license verification for **mobile** (`android`/`ios`) and **desktop** (`windows`/`macos`/`linux`)
- account license sync (entitlements + verified devices)

It does **not** store genealogy data.

## Run

```bash
cd /home/runner/work/vetviona/vetviona/backend
node license_server.js
```

Optional env vars:

- `PORT` (default `8080`)
- `LICENSE_DB_PATH` (default `backend/license-db.json`)

## Endpoints

- `GET /health`
- `POST /v1/account/register`
- `POST /v1/license/verify`
- `POST /v1/account/sync`

### Register account

```bash
curl -X POST http://127.0.0.1:8080/v1/account/register \
  -H 'Content-Type: application/json' \
  -d '{
    "email":"owner@example.com",
    "password":"ChangeMe123!",
    "mobileLicense":true,
    "desktopLicense":true
  }'
```

### Verify a paid app install

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

### Sync account licenses/devices

```bash
curl -X POST http://127.0.0.1:8080/v1/account/sync \
  -H 'Content-Type: application/json' \
  -d '{
    "email":"owner@example.com",
    "password":"ChangeMe123!"
  }'
```

## App integration

Set the Flutter app backend URL with:

```bash
--dart-define=LICENSE_BACKEND_URL=http://127.0.0.1:8080
```

Paid tiers now require one successful backend verification before the app can open.
