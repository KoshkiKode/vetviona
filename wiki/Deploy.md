# Deployment

This page covers everything needed to run a production Vetviona deployment: the license backend server, the app itself, and all embedded or online database/search services used in the app.

---

## Quick Summary

| Component | What it is | Needs manual setup? |
|-----------|-----------|-------------------|
| **License backend** | Node.js HTTP server | Yes — run on your own server |
| **App SQLite database** | Local `vetviona.db` | No — auto-created on first launch |
| **GeoNames offline database** | Bundled SQLite asset (32 k cities) | No — included in app binary |
| **Place service (built-in)** | Compiled-in historical place data | No — works offline |
| **Nominatim geocoding** | OpenStreetMap reverse-geocoding API | No key needed — requires internet |
| **WikiTree API** | Public genealogy profiles + GEDCOM export | No key for public search; user login for full access |
| **Find A Grave** | Grave/memorial data via HTML parsing | No key needed — requires internet |

---

## License Backend

The license backend is a Node.js HTTP server that handles account registration, email verification, paid-license verification, license gifting, license re-entry codes, and voucher creation.

### Requirements

- Node.js 18+ (LTS recommended)
- Network-accessible host (all device → server calls must reach it)
- Optional: SMTP server for transactional email

### Run

```bash
cd backend
node license_server.js
```

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | HTTP port |
| `LICENSE_DB_PATH` | `backend/license-db.json` | Path to the JSON account database |
| `ADMIN_SECRET` | *(auto-generated and printed at startup in dev mode)* | Protects the voucher-creation endpoint — **always set in production** |
| `LICENSE_KEY_SECRET` | *(auto-generated and persisted in DB on first request)* | HMAC secret for verifiable re-entry license codes — set to a stable value of ≥ 32 characters so codes survive backend restarts |
| `MAX_DEVICES_PER_LICENSE` | `15` | Maximum verified devices per license type per account |
| `SMTP_HOST` | *(unset)* | SMTP server hostname. Leave unset for dev mode (tokens logged to console) |
| `SMTP_PORT` | `587` | SMTP port |
| `SMTP_USER` | *(unset)* | SMTP username |
| `SMTP_PASS` | *(unset)* | SMTP password |
| `SMTP_SECURE` | `false` | Set `true` for port-465 TLS |
| `EMAIL_FROM` | `Vetviona <noreply@vetviona.local>` | From address for outgoing emails |

> **Dev mode:** When `SMTP_HOST` is unset, all email tokens (verification codes, gift claim tokens, voucher codes, re-entry license codes) are printed to the console **and** returned in API responses as `_devToken` / `_devTokens`.

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
2. **Set `LICENSE_KEY_SECRET`** — a stable secret of ≥ 32 characters ensures re-entry license codes are consistent across server restarts and deployments.
3. **Configure SMTP** — so users receive real email verification codes, gift notifications, and voucher emails.
4. **Serve over HTTPS** — put the backend behind a reverse proxy (nginx, Caddy, etc.) with a valid TLS certificate.
5. **Restrict file permissions** on `LICENSE_DB_PATH` — the JSON database contains password hashes (PBKDF2-SHA256) and should not be world-readable.
6. **Set `MAX_DEVICES_PER_LICENSE`** if 15 devices per license type is not appropriate for your deployment.

For the full encryption and privacy model see [Security and Privacy](Security-and-Privacy).
