# Vetviona project status

Vetviona is an offline-first family-tree builder and research workspace. The
repository currently contains four connected surfaces:

| Surface | Current role |
| --- | --- |
| `app/` | Flutter client for Android, iOS, Windows, macOS, Linux, and web-facing shared code |
| `backend/` | Node.js license, account, MFA, encrypted cloud-tree, Stripe fulfillment, and download service |
| `website/` | Public product, pricing, and paid-download landing page |
| `wiki/` | Build, deployment, sync, GEDCOM, pricing, and architecture documentation |

## Current capabilities

- Local SQLite family trees with person, relationship, life-event, place,
  source, memory, medical, and research-task data.
- Relationship-safe editing and chart views including pedigree, ancestry,
  descendants, fan, and tree diagrams.
- GEDCOM import/export with multiline text, approximate/range dates, gender
  normalization, relationship pointers, and safer linking.
- Offline-first RootLoop synchronization over manual/Wi-Fi/Bluetooth/NFC and
  encrypted optional cloud backup.
- Research integrations for WikiTree, FamilySearch, Find a Grave, NARA,
  Chronicling America, GeoNames, Nominatim, and local/open archives.
- Mobile free, mobile paid, and desktop pro packaging paths with in-app
  purchase/license verification, account sessions, MFA, gifting, and paid
  downloads.
- PDF reports, sharing, localization, accessibility-aware Flutter widgets, and
  platform-specific packaging workflows.

## Verified baseline

The integrated branch has passed the local validation that is currently
available:

- `flutter analyze` — passed.
- `flutter test` from `app/` — 1,162 tests passed.
- `npm test` from `backend/` — 123 tests passed.
- Documentation link checks — passed.
- `git diff --check` — passed.

GitHub Actions billing is restored and CI runs normally on `main` again.

## Release and security posture

- Production builds now keep licensing enabled by default. Beta bypasses must
  explicitly opt in with `--dart-define=BETA=true`.
- Paid binary downloads require a verified bearer session token. Email query
  parameters are not accepted as authorization.
- Free-license registration can no longer be granted by a client-supplied
  flag; MFA attempts count toward account lockout; dev/debug tokens require
  an explicit `ALLOW_INSECURE_DEV` opt-in and never leak in production
  responses; Stripe fulfillment checks `payment_status` before granting a
  license.
- Android release builds sign with a real release key when
  `app/android/key.properties` is present, and refuse to fall back to the
  debug key silently in CI release artifacts.
- The repository has been swept for stale AWS branding and bloat: committed
  build artifacts, one-off AI patch scripts, a stale root-level `pubspec.*`,
  and a superseded AWS-specific deploy guide were removed. Object storage
  env vars are now generic `S3_*` names (MinIO-compatible); no code or docs
  depend on Amazon AWS specifically.
- The app remains offline-first: backend reachability is optional for local
  editing and local sync.
- The canonical object-storage choice is now resolved: self-hosted MinIO per
  `SERVER_SETUP.md`, with Google Cloud Storage as a documented managed
  alternative. No part of the deployment path uses or depends on AWS.
- Versioning is not yet fully separated between the app, RootLoop protocol,
  backend API, and persisted data schema; this is a release-management risk.

## Prioritized roadmap

### P0 — release safety and data integrity

1. Keep Flutter tests, backend tests, build exports, and CodeQL green on
   every `main` push (GitHub Actions billing is restored; this is ongoing
   maintenance, not a one-time unblock).
2. Add release smoke tests for every artifact type and verify that paid,
   mobile-free, mobile-paid, and explicit beta builds have the intended gates.
3. Define and test SQLite migrations, backup/restore, crash recovery, and
   atomic writes. A family tree must never be lost because a sync or import
   was interrupted.
4. Finish RootLoop conflict semantics: revision checks, duplicate replay
   protection, partial-transfer recovery, peer authentication, and clear
   conflict reporting.
5. Reconcile Stripe, account licenses, webhook retries, download authorization,
   and object storage configuration in one deployment contract. Payments work
   is intentionally deprioritized for now — see `backend/PAYMENTS_TODO.md`
   for the open items to pick back up before relying on it for real revenue.

### P1 — researcher-grade correctness

1. Add source citations and evidence provenance to every imported or
   externally matched fact.
2. Add duplicate-person resolution with preview, merge history, undo, and
   relationship-preserving safeguards.
3. Expand GEDCOM round-trip and malformed-input fixtures, including media,
   notes, sources, citations, aliases, adoption, and custom tags.
4. Add encrypted, user-controlled export and scheduled local/cloud backups.
5. Split the large person editor into tested sections for identity, dates and
   places, relationships, health, media, identifiers, and research.
6. Complete accessibility, keyboard navigation, localization coverage, and
   large-tree performance testing.

### P2 — collaboration and discovery

1. Add shared-tree collaboration with explicit roles, invitations, audit
   history, and mergeable changes.
2. Build a unified evidence graph connecting people, sources, records, places,
   media, and research tasks.
3. Improve full-text and faceted search across people, events, places, notes,
   sources, and external identifiers.
4. Add review queues for hints and possible matches so automation never silently
   changes a tree.

### P3 — ecosystem and advanced workflows

1. Publish stable APIs and import/export adapters for additional genealogy
   services.
2. Add privacy-aware publishing, share links, embeddable charts, and archival
   snapshots.
3. Add optional research assistance that cites its evidence, records
   uncertainty, and requires user approval before edits.
4. Establish a plugin/integration boundary and telemetry that is opt-in,
   minimized, and never required for offline use.

## Immediate next steps

1. Keep CI green on every push to `main` (Unit Tests, Code Quality, and the
   Build — Matrix Exports workflow across Android/iOS/Windows/macOS/Linux).
2. Add migration/backup/sync failure-injection tests before expanding feature
   scope.
3. Introduce explicit app, protocol, API, and schema version fields and
   compatibility tests.
