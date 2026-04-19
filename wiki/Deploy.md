# Deployment

This page covers everything needed to run a production Vetviona deployment: the license backend server, the app itself, all embedded or online database/search services, and the legal/EULA requirements.

> **First time deploying?** Start with the **[Step-by-Step Deployment Guide](Deploy-Step-by-Step)** — it walks through every AWS CLI command in order, from a fresh account to a fully live backend.

---

## Quick Summary

| Component | What it is | Needs manual setup? |
|-----------|-----------|-------------------|
| **EULA** | End User License Agreement shown at first launch | No — embedded in app binary |
| **License backend** | Node.js HTTP server | Yes — run on your own server |
| **License database** | Authoritative account/license store | **Yes — AWS S3 bucket (production) or local JSON file (dev)** |
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
- Network-accessible host (all device → server calls must reach it)
- Optional: SMTP server for transactional email
- **Production: AWS S3 bucket** for durable, encrypted license database storage

### Run

```bash
cd backend
node license_server.js
```

Install optional dependencies:

```bash
npm install nodemailer@^7.0.11          # real email delivery
npm install @aws-sdk/client-s3  # AWS S3 database storage (production)
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | HTTP port |
| `LICENSE_DB_PATH` | `backend/license-db.json` | Path to local JSON database **(dev only — ignored when `AWS_S3_BUCKET` is set)** |
| `ADMIN_SECRET` | *(auto-generated and printed at startup in dev mode)* | Protects the voucher-creation endpoint — **always set in production** |
| `LICENSE_KEY_SECRET` | *(auto-generated and persisted in DB on first request)* | HMAC secret for verifiable re-entry license codes — **must be set to a stable ≥ 32-char value in production** |
| `MAX_DEVICES_PER_LICENSE` | `15` | Maximum verified devices per license type per account |
| `SMTP_HOST` | *(unset)* | SMTP server hostname. Leave unset for dev mode (tokens logged to console) |
| `SMTP_PORT` | `587` | SMTP port |
| `SMTP_USER` | *(unset)* | SMTP username |
| `SMTP_PASS` | *(unset)* | SMTP password |
| `SMTP_SECURE` | `false` | Set `true` for port-465 TLS |
| `EMAIL_FROM` | `Vetviona <noreply@vetviona.local>` | From address for outgoing emails |
| **`AWS_S3_BUCKET`** | *(unset)* | **S3 bucket name** — set this to use S3 instead of the local file |
| `AWS_S3_KEY` | `vetviona/license-db.json` | S3 object key (path within the bucket) |
| `AWS_KMS_KEY_ID` | *(unset)* | KMS key ARN or alias for SSE-KMS encryption (recommended); falls back to SSE-S3/AES-256 |
| `AWS_REGION` | `us-east-1` | AWS region where the S3 bucket lives |
| `AWS_ACCESS_KEY_ID` | *(IAM role)* | AWS access key; not required when the host has an IAM role (EC2/ECS/Lambda) |
| `AWS_SECRET_ACCESS_KEY` | *(IAM role)* | AWS secret key (same as above) |

> **Dev mode:** When `SMTP_HOST` is unset, all email tokens (verification codes, gift claim tokens, voucher codes, re-entry license codes) are printed to the console **and** returned in API responses as `_devToken` / `_devTokens`.

### AWS S3 Database Storage

All license account data (password hashes, entitlements, device records, gift tokens) is stored in the license database.  In production this **must** live in S3, not on the server's local disk — local disk is lost on server restarts or re-deployments.

#### 1. Create and harden the S3 bucket

```bash
# Replace values for your account/region
aws s3api create-bucket \
  --bucket my-vetviona-licenses \
  --region us-east-1

# Block all public access
aws s3api put-public-access-block \
  --bucket my-vetviona-licenses \
  --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,\
    BlockPublicPolicy=true,RestrictPublicBuckets=true

# Enable versioning (point-in-time recovery)
aws s3api put-bucket-versioning \
  --bucket my-vetviona-licenses \
  --versioning-configuration Status=Enabled

# Enforce HTTPS-only access
aws s3api put-bucket-policy \
  --bucket my-vetviona-licenses \
  --policy '{
    "Version":"2012-10-17",
    "Statement":[{
      "Sid":"DenyHTTP","Effect":"Deny","Principal":"*",
      "Action":"s3:*",
      "Resource":["arn:aws:s3:::my-vetviona-licenses",
                  "arn:aws:s3:::my-vetviona-licenses/*"],
      "Condition":{"Bool":{"aws:SecureTransport":"false"}}
    }]
  }'
```

#### 2. Create a KMS key (recommended)

```bash
aws kms create-key --description "Vetviona license DB key" \
  --key-usage ENCRYPT_DECRYPT \
  --query KeyMetadata.KeyId --output text

aws kms create-alias --alias-name alias/vetviona-license-db \
  --target-key-id <KeyId>

aws kms enable-key-rotation --key-id <KeyId>
```

Set `AWS_KMS_KEY_ID=alias/vetviona-license-db`.  Without this the object is still encrypted with SSE-S3 (AES-256 managed by AWS).

#### 3. IAM policy for the backend process

Attach this to the IAM role (EC2 instance profile / ECS task role) — grant only the two operations needed:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "LicenseDbReadWrite",
      "Effect": "Allow",
      "Action": ["s3:GetObject","s3:PutObject"],
      "Resource": "arn:aws:s3:::my-vetviona-licenses/vetviona/license-db.json"
    },
    {
      "Sid": "LicenseDbKms",
      "Effect": "Allow",
      "Action": ["kms:GenerateDataKey","kms:Decrypt"],
      "Resource": "arn:aws:kms:us-east-1:123456789012:key/<KeyId>"
    }
  ]
}
```

#### 4. Start the backend with S3 enabled

```bash
export AWS_S3_BUCKET=my-vetviona-licenses
export AWS_S3_KEY=vetviona/license-db.json    # default; can omit
export AWS_KMS_KEY_ID=alias/vetviona-license-db
export AWS_REGION=us-east-1
export LICENSE_KEY_SECRET=<stable-random-32+-chars>  # REQUIRED with S3
export ADMIN_SECRET=<your-admin-secret>
export SMTP_HOST=email-smtp.us-east-1.amazonaws.com
# ... other SMTP vars ...

npm install @aws-sdk/client-s3
node license_server.js
```

#### 5. Production security checklist

- [ ] `AWS_S3_BUCKET` set — S3 storage active
- [ ] Bucket "Block all public access" enabled
- [ ] HTTPS-only bucket policy in place
- [ ] Bucket versioning enabled
- [ ] `AWS_KMS_KEY_ID` set (SSE-KMS) and annual key rotation enabled
- [ ] IAM policy grants only `GetObject` + `PutObject` on the exact S3 key
- [ ] `LICENSE_KEY_SECRET` set to a stable ≥ 32-char random value
- [ ] `ADMIN_SECRET` set (voucher endpoint protection)
- [ ] `SMTP_HOST` set (real transactional email)

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

**Steps to verify:**

1. Build the app with `flutter build <platform> --release`.
2. Open the app and navigate to any place picker field.
3. Type a city name — results from the GeoNames database appear alongside built-in place data.

---

### Place Service (Built-in Historical Data)

Compiled-in historical and modern place data covering thousands of locations across all continents, with `validFrom` / `validTo` era ranges for accurate date-aware filtering.

| Detail | Value |
|--------|-------|
| Requires setup | No — data is embedded in the app binary |
| Internet required | No — fully offline |
| Era filtering | Yes — filters by `eventDate` if supplied |
| Relevance sorting | Yes — exact matches ranked before partial matches |

**How it works:** `PlaceService.search(query, eventDate: ...)` loads all built-in places once into memory, then filters and sorts them on every query.

**Steps to verify:**

1. Open any person's birth / death / burial place field.
2. Type a place name — instant results appear with era context.
3. Set a birth year on the event — only historically valid places appear.

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

**Steps to verify:**

1. Open any place picker that has a map icon.
2. Tap the map and drop a pin — the app calls `NominatimService.reverseGeocode()` and fills in the place name automatically.
3. Type a place name in the search box — `NominatimService.search()` returns geocoded suggestions.

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

**Steps to verify:**

1. Navigate to **Settings → WikiTree & Find A Grave**.
2. Search for a public profile by name (no login needed).
3. Tap **Import** to create a local person record from the WikiTree data.
4. Optionally: sign in with your WikiTree account to enable GEDCOM download.

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

**Steps to verify:**

1. Open a person's source list and tap **Add source → Find A Grave**.
2. Enter a memorial ID (e.g. `1836` for George Washington).
3. The app fetches the memorial page, extracts name/dates/places, and creates a pre-filled source record.

---

## Build and Packaging

For full build and packaging instructions for all platforms see [Building and Development](Building-and-Development).

---

## Production Security Checklist

Before going to production with the license backend:

1. **Set `ADMIN_SECRET`** — otherwise a random secret is generated and printed to the console on each restart.
2. **Set `LICENSE_KEY_SECRET`** — a stable secret of ≥ 32 characters ensures re-entry license codes are consistent across server restarts and deployments.  **Required when using S3** (there is no local file to auto-persist the secret in).
3. **Configure SMTP** — so users receive real email verification codes, gift notifications, and voucher emails.
4. **Serve over HTTPS** — put the backend behind a reverse proxy (nginx, Caddy, etc.) with a valid TLS certificate.
5. **Use AWS S3 for the license database** (see the [AWS S3 Database Storage](#aws-s3-database-storage) section above) — in production never rely on local disk, which is lost on re-deployment.  For dev only: if using the local JSON fallback, restrict file permissions on `LICENSE_DB_PATH` — the file contains scrypt password hashes and should not be world-readable.
6. **Set `MAX_DEVICES_PER_LICENSE`** if 15 devices per license type is not appropriate for your deployment.

For the full encryption and privacy model see [Security and Privacy](Security-and-Privacy).
