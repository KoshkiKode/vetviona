# Deployment

This page covers everything needed to run a production Vetviona deployment: the license backend server, the app itself, all embedded or online database/search services, and the legal/EULA requirements.

> **First time deploying?** Start with the **[Step-by-Step Deployment Guide](Deploy-Step-by-Step)** — it walks through every step in order, from a fresh server to a fully live backend.

---

## Quick Summary

| Component | What it is | Needs manual setup? |
|-----------|-----------|-------------------|
| **EULA** | End User License Agreement shown at first launch | No — embedded in app binary |
| **License backend** | Node.js HTTP server | Yes — run on your own server |
| **License database** | Authoritative account/license store | **Yes — S3-compatible bucket (production) or local JSON file (dev)** |
| **App SQLite database** | Local `vetviona.db` | No — auto-created on first launch |
| **GeoNames offline database** | Bundled SQLite asset (32 k cities) | No — included in app binary |
| **Place service (built-in)** | Compiled-in historical place data | No — works offline |
| **Nominatim geocoding** | OpenStreetMap reverse-geocoding API | No key needed — requires internet |
| **WikiTree API** | Public genealogy profiles + GEDCOM export | No key for public search; user login for full access |
| **Find A Grave** | Grave/memorial data via HTML parsing | No key needed — requires internet |

---

## Legal — EULA and Copyright

**Copyright © KoshkiKode. All rights reserved.**

Vetviona and RootLoop™ are trademarks of KoshkiKode. The full text of the
End User License Agreement (EULA) is embedded inline in the app source at
`app/lib/screens/eula_screen.dart` (constant `eulaText`).  The same text is
reproduced in the Windows installer at `packaging/windows/LICENSE.rtf`.

### How the EULA is enforced

| Platform | Mechanism |
|----------|-----------|
| Mobile (iOS / Android) | Shown on first launch before onboarding; user must scroll to bottom and tap **Accept** |
| Desktop (Windows / macOS / Linux) | Same in-app EULA screen on first launch |
| Windows installer (.msi) | License page shown by WiX UI during installation |

### SharedPreferences key

| Key | Type | Meaning |
|-----|------|---------|
| `eulaAccepted` | `bool` | `true` once the user has tapped **Accept** in the EULA screen |

The startup router (`app/lib/app.dart → _StartupRouterState`) checks this key
**before** onboarding and license verification.  Users who have not accepted
the EULA are redirected to `EulaScreen` and cannot proceed until they accept.

### Read-only access

The EULA is also accessible at any time from **Settings → Privacy & Legal →
End User License Agreement** (read-only mode, no buttons).

### Updating the EULA

1. Edit the `eulaText` constant in `app/lib/screens/eula_screen.dart`.
2. Update `packaging/windows/LICENSE.rtf` with the same content.
3. Bump the "Last updated" date at the top of the EULA text.
4. Consider clearing `eulaAccepted` in SharedPreferences if the new version
   requires fresh consent (requires a migration in `_StartupRouterState`).

---

## License Backend

The license backend is a Node.js HTTP server that handles account registration, email verification, paid-license verification, license gifting, license re-entry codes, and voucher creation.

### Requirements

- Node.js 18+ (LTS recommended)
- Network-accessible host (any Linux VPS, bare metal, or home server)
- Optional: SMTP server for transactional email
- **Production: S3-compatible object storage** for durable, encrypted license database storage

### Run

```bash
cd backend
node license_server.js
```

Install optional dependencies:

```bash
npm install nodemailer@^7.0.11   # real email delivery
npm install @aws-sdk/client-s3   # S3-compatible object storage (production)
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | HTTP port |
| `LICENSE_DB_PATH` | `backend/license-db.json` | Path to local JSON database **(dev only — ignored when `S3_BUCKET` is set)** |
| `ADMIN_SECRET` | *(auto-generated and printed at startup in dev mode)* | Protects the voucher-creation endpoint — **always set in production** |
| `LICENSE_KEY_SECRET` | *(auto-generated and persisted in DB on first request)* | HMAC secret for verifiable re-entry license codes — **must be set to a stable ≥ 32-char value in production** |
| `MAX_DEVICES_PER_LICENSE` | `15` | Maximum verified devices per license type per account |
| `SMTP_HOST` | *(unset)* | SMTP server hostname. Leave unset for dev mode (tokens logged to console) |
| `SMTP_PORT` | `587` | SMTP port |
| `SMTP_USER` | *(unset)* | SMTP username |
| `SMTP_PASS` | *(unset)* | SMTP password |
| `SMTP_SECURE` | `false` | Set `true` for port-465 TLS |
| `EMAIL_FROM` | `Vetviona <noreply@vetviona.local>` | From address for outgoing emails |
| **`S3_BUCKET`** | *(unset)* | **Object storage bucket name** — set this to use S3-compatible storage instead of the local file |
| `S3_KEY` | `vetviona/license-db.json` | Object key (path within the bucket) |
| `S3_REGION` | `us-east-1` | Region (use any value if your provider doesn't require one) |
| `S3_ENDPOINT` | *(unset)* | Custom endpoint URL — **required for non-AWS providers** (e.g. MinIO, Backblaze B2, Cloudflare R2) |
| `AWS_ACCESS_KEY_ID` | *(unset)* | Access key ID for your object storage provider |
| `AWS_SECRET_ACCESS_KEY` | *(unset)* | Secret access key for your object storage provider |

> **Dev mode:** When `SMTP_HOST` is unset, all email tokens (verification codes, gift claim tokens, voucher codes, re-entry license codes) are printed to the console **and** returned in API responses as `_devToken` / `_devTokens`.

---

## Object Storage (Production)

In production the license database **must** live in durable object storage, not on the server's local disk — local disk is lost on server restarts or re-deployments.

The backend uses the `@aws-sdk/client-s3` package, which speaks standard S3 protocol and works with any S3-compatible provider.

### Recommended providers

| Provider | Notes |
|----------|-------|
| **MinIO** | Self-hosted, completely free, runs on your own VPS or LAN |
| **Backblaze B2** | Cheap hosted option ($0.006/GB/mo), S3-compatible API |
| **Cloudflare R2** | Zero egress fees, S3-compatible, generous free tier |
| **Hetzner Object Storage** | EU-based, affordable, S3-compatible |

### Self-hosted MinIO setup

```bash
# Pull and run MinIO (single-node, local data directory)
docker run -d \
  --name minio \
  -p 9000:9000 -p 9001:9001 \
  -e MINIO_ROOT_USER=admin \
  -e MINIO_ROOT_PASSWORD=changeme \
  -v /data/minio:/data \
  quay.io/minio/minio server /data --console-address ":9001"

# Create the bucket via the MinIO CLI (mc)
mc alias set local http://localhost:9000 admin changeme
mc mb local/vetviona-licenses
mc anonymous set none local/vetviona-licenses  # no public access
```

Then start the license backend pointing at MinIO:

```bash
export S3_BUCKET=vetviona-licenses
export S3_ENDPOINT=http://localhost:9000
export S3_REGION=us-east-1          # MinIO ignores this; any value works
export AWS_ACCESS_KEY_ID=admin
export AWS_SECRET_ACCESS_KEY=changeme
export LICENSE_KEY_SECRET=<stable-random-32+-chars>
export ADMIN_SECRET=<your-admin-secret>
export SMTP_HOST=your-smtp-host

npm install @aws-sdk/client-s3
node license_server.js
```

### Backblaze B2 setup

1. Create a bucket in the B2 dashboard — set **Files in Bucket** to **Private**.
2. Create an application key scoped to that bucket with read/write permissions.
3. Note the **Endpoint** from the bucket details page (e.g. `https://s3.us-west-004.backblazeb2.com`).

```bash
export S3_BUCKET=vetviona-licenses
export S3_ENDPOINT=https://s3.us-west-004.backblazeb2.com
export S3_REGION=us-west-004
export AWS_ACCESS_KEY_ID=<b2-key-id>
export AWS_SECRET_ACCESS_KEY=<b2-application-key>
export LICENSE_KEY_SECRET=<stable-random-32+-chars>
export ADMIN_SECRET=<your-admin-secret>

node license_server.js
```

### Cloudflare R2 setup

1. Create an R2 bucket in the Cloudflare dashboard.
2. Generate an **R2 API Token** with object read/write on that bucket.
3. Find your **Account ID** in the Cloudflare dashboard sidebar.

```bash
export S3_BUCKET=vetviona-licenses
export S3_ENDPOINT=https://<ACCOUNT_ID>.r2.cloudflarestorage.com
export S3_REGION=auto
export AWS_ACCESS_KEY_ID=<r2-access-key-id>
export AWS_SECRET_ACCESS_KEY=<r2-secret-access-key>
export LICENSE_KEY_SECRET=<stable-random-32+-chars>
export ADMIN_SECRET=<your-admin-secret>

node license_server.js
```

### Production security checklist

- [ ] `S3_BUCKET` set — object storage active
- [ ] Bucket has no public access
- [ ] `S3_ENDPOINT` set (if using a non-default provider)
- [ ] `LICENSE_KEY_SECRET` set to a stable ≥ 32-char random value
- [ ] `ADMIN_SECRET` set (voucher endpoint protection)
- [ ] `SMTP_HOST` set (real transactional email)
- [ ] Backend served over HTTPS (nginx/Caddy reverse proxy with valid TLS cert)

---

### Re-entry License Codes

After a successful `/v1/license/verify` or `/v1/account/sync` call the server returns `reentryLicenseCodes` — one per active license type.  These codes are deterministic HMAC digests tied to the account and license type.  A user can re-enter a re-entry code (instead of their password) to verify a new installation:

```bash
curl -X POST http://127.0.0.1:8080/v1/license/verify \
  -H 'Content-Type: application/json' \
  -d '{
    "email": "owner@example.com",
    "licenseCode": "DES-ABCD-EF12-3456-7890-ABCD-EF12",
    "appType": "desktop",
    "os": "linux",
    "deviceId": "new-device-id",
    "appVersion": "1.0.0"
  }'
```

> A re-entry code authenticates as the account owner for the purpose of license verification only.  It cannot be used to modify the account or transfer licenses.

### Device Limit

Each license type allows a maximum of **15** verified devices/computers by default (configurable via `MAX_DEVICES_PER_LICENSE`).  Re-verifying an already-registered device does not consume a new seat.  When the limit is reached, the response includes `deviceLimitPerLicense` and `devicesUsedForLicense` so the app can surface a clear message.

### Point the App at Your Backend

Pass the backend URL at build time:

```bash
flutter build <platform> --release \
  --dart-define=PAID=true \
  --dart-define=LICENSE_BACKEND_URL=https://your-backend.example.com
```

Or at runtime for development:

```bash
flutter run --dart-define=LICENSE_BACKEND_URL=http://127.0.0.1:8080
```

---

## App SQLite Database

**No setup required.**

On first launch the app creates `{ApplicationDocumentsDirectory}/vetviona.db` and applies the full schema (currently v7) automatically.  Subsequent launches open the existing file and migrate incrementally.

| Engine | Mobile | Desktop |
|--------|--------|---------|
| `sqflite` | ✅ | — |
| `sqflite_common_ffi` | — | ✅ |

Full schema reference → [Architecture and Technical Reference](Architecture-and-Technical-Reference#database-schema)

---

## Database Searches

Vetviona integrates four search and lookup services for place names, coordinates, and genealogy records.  All are **optional** — the app works fully offline without them.

### GeoNames Offline Database

A ~940 KB SQLite database bundled as `assets/geonames_cities.db` (32,444 world cities with population > ~1,000, sourced from GeoNames.org via the geonamescache data package).

| Detail | Value |
|--------|-------|
| Asset path | `assets/geonames_cities.db` |
| Requires setup | No — shipped with the app binary |
| Internet required | No — fully offline |
| Max results | 60 per query |
| Search strategy | FTS5 prefix search; LIKE fallback |

**How it works:** On first search, `GeonamesService.init()` copies the file from the Flutter asset bundle to the writable app directory, then opens it with `sqflite` in read-only mode.  The copy is reused on all subsequent launches.

---

### Place Service (Built-in Historical Data)

Compiled-in historical and modern place data covering thousands of locations across all continents, with `validFrom` / `validTo` era ranges for accurate date-aware filtering.

| Detail | Value |
|--------|-------|
| Requires setup | No — data is embedded in the app binary |
| Internet required | No — fully offline |
| Era filtering | Yes — filters by `eventDate` if supplied |
| Relevance sorting | Yes — exact matches ranked before partial matches |

---

### Nominatim (OpenStreetMap Geocoding)

Converts map coordinates to place names (reverse geocoding) and searches for place names by free text.

| Detail | Value |
|--------|-------|
| API endpoint | `https://nominatim.openstreetmap.org` |
| Requires API key | No |
| Internet required | Yes |
| Rate limits | No bulk requests; 1 request/second guideline |
| User-Agent sent | `Vetviona/1.0 (genealogy app; contact@vetviona.app)` |

**Usage policy:** Follow the [Nominatim usage policy](https://operations.osmfoundation.org/policies/nominatim/) — no bulk requests, do not hammer the endpoint.

---

### WikiTree API

Search WikiTree's collaborative genealogy database for public profiles and import them into your local tree.  Account login enables GEDCOM export.

| Detail | Value |
|--------|-------|
| API endpoint | `https://api.wikitree.com/api.php` |
| Requires setup | No setup for public profile search |
| Internet required | Yes |
| Authentication | Optional — cookie-based WikiTree account login |
| Cookie storage | Platform secure storage (Keychain / EncryptedSharedPreferences / Credential Manager / libsecret) |

---

### Find A Grave

Look up memorial records by memorial ID or direct URL.  The service extracts structured data from Schema.org JSON-LD embedded in memorial pages, with an HTML regex fallback.

| Detail | Value |
|--------|-------|
| Base URL | `https://www.findagrave.com/memorial/{id}` |
| Requires API key | No |
| Internet required | Yes |
| Data strategy | Schema.org JSON-LD → HTML regex fallback |

> **Important:** Fetch only on **explicit user demand** — never in the background or in bulk — to stay within reasonable usage limits for `findagrave.com`.

---

## Build and Packaging

For full build and packaging instructions for all platforms see [Building and Development](Building-and-Development).

---

## Production Security Checklist

Before going to production with the license backend:

1. **Set `ADMIN_SECRET`** — otherwise a random secret is generated and printed to the console on each restart.
2. **Set `LICENSE_KEY_SECRET`** — a stable secret of ≥ 32 characters ensures re-entry license codes are consistent across server restarts and deployments.  **Required when using object storage** (there is no local file to auto-persist the secret in).
3. **Configure SMTP** — so users receive real email verification codes, gift notifications, and voucher emails.
4. **Serve over HTTPS** — put the backend behind a reverse proxy (nginx, Caddy, etc.) with a valid TLS certificate.
5. **Use S3-compatible object storage for the license database** — in production never rely on local disk, which is lost on re-deployment.  For dev only: if using the local JSON fallback, restrict file permissions on `LICENSE_DB_PATH` — the file contains scrypt password hashes and should not be world-readable.
6. **Set `MAX_DEVICES_PER_LICENSE`** if 15 devices per license type is not appropriate for your deployment.

For the full encryption and privacy model see [Security and Privacy](Security-and-Privacy).
