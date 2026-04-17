# Vetviona License Backend

This backend handles only:

- Vetviona paid-license account registration
- paid-license verification for **apple** (`ios`), **android** (`android`), and **desktop** (`windows`/`macos`/`linux`)
- account license sync (entitlements + verified devices)

It does **not** store genealogy data.

## Run

```bash
cd backend
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

All three license flags are optional — set the ones you want to sell:

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

### Verify a paid app install

`appType` must be `"apple"`, `"android"`, or `"desktop"`.

```bash
# iOS device
curl -X POST http://127.0.0.1:8080/v1/license/verify \
  -H 'Content-Type: application/json' \
  -d '{
    "email":"owner@example.com",
    "password":"ChangeMe123!",
    "appType":"apple",
    "os":"ios",
    "deviceId":"example-device-1",
    "appVersion":"1.0.0"
  }'

# Android device
curl -X POST http://127.0.0.1:8080/v1/license/verify \
  -H 'Content-Type: application/json' \
  -d '{
    "email":"owner@example.com",
    "password":"ChangeMe123!",
    "appType":"android",
    "os":"android",
    "deviceId":"example-device-2",
    "appVersion":"1.0.0"
  }'

# Desktop (linux/windows/macos)
curl -X POST http://127.0.0.1:8080/v1/license/verify \
  -H 'Content-Type: application/json' \
  -d '{
    "email":"owner@example.com",
    "password":"ChangeMe123!",
    "appType":"desktop",
    "os":"linux",
    "deviceId":"example-device-3",
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
