# Architecture and Technical Reference

This page documents the internal structure of Vetviona for contributors and developers.

---

## High-Level Architecture

```
┌─────────────────────────────────────────────────────┐
│                    Flutter UI Layer                 │
│  (27 screens in app/lib/screens/)                   │
└────────────────────────┬────────────────────────────┘
                         │ context.watch / context.read
┌────────────────────────▼────────────────────────────┐
│              State Management (Provider)            │
│  TreeProvider   ·   ThemeProvider                   │
└──────────┬──────────────────────┬───────────────────┘
           │                      │
┌──────────▼────────┐   ┌─────────▼─────────────────┐
│  SQLite Database  │   │    Services / Utilities    │
│  (vetviona.db)    │   │  SyncService  BluetoothSync│
│  sqflite / FFI    │   │  GedcomParser  PlaceService│
└───────────────────┘   │  PdfReport  PurchaseService│
                        └───────────────────────────┘
```

---

## Directory Structure

```
app/
├── lib/
│   ├── app.dart                 # MultiProvider root, startup router
│   ├── main.dart                # Entry point, desktop Pro lock check
│   ├── config/
│   │   ├── app_config.dart      # Tier detection, build flags, limits
│   │   └── build_metadata.dart  # App name, version, sync tech constants
│   ├── models/                  # Data model classes (9 files)
│   ├── providers/               # ChangeNotifier state (2 files)
│   ├── screens/                 # UI screens (27 files)
│   ├── services/                # Business logic services (9+ files)
│   │   ├── places/              # Historical place data files (6 files)
│   └── utils/
│       └── page_routes.dart     # Navigation helpers
├── test/                        # Unit tests (13 files)
│   ├── models/
│   ├── providers/
│   └── services/
└── pubspec.yaml
```

---

## State Management

Vetviona uses Flutter's **`provider` package** (`ChangeNotifier` pattern).

### Providers at App Startup (`app.dart`)

```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider<TreeProvider>(...),
    ChangeNotifierProvider<ThemeProvider>(...),
    ChangeNotifierProxyProvider<TreeProvider, SyncService>(...),
    ChangeNotifierProxyProvider<SyncService, BluetoothSyncService>(...),
    ChangeNotifierProxyProvider<TreeProvider, PurchaseService>(...),
  ],
)
```

`SyncService` and `BluetoothSyncService` observe `TreeProvider` via `ProxyProvider` so they can access the latest tree data without a circular dependency.

---

## Data Models

All models live in `app/lib/models/`. Each implements `toMap()` / `fromMap()` for SQLite serialization and optionally `toJson()` / `fromJson()`.

| Model | File | Key purpose |
|-------|------|-------------|
| `Person` | `person.dart` | Genealogical individual |
| `Partnership` | `partnership.dart` | Marriage / union |
| `Source` | `source.dart` | Citation / evidence record |
| `LifeEvent` | `life_event.dart` | Dated life milestone |
| `MedicalCondition` | `medical_condition.dart` | Health record |
| `ResearchTask` | `research_task.dart` | Genealogy to-do |
| `Place` | `place.dart` | Historical place with era validity |
| `GeoCoord` | `geo_coord.dart` | Lat/lng + reverse-geocoded metadata |
| `Device` | `device.dart` | Paired sync device + shared secret |

### Serialization Conventions

| Data type | SQLite storage format |
|-----------|-----------------------|
| `List<String>` (e.g. `parentIds`) | Comma-separated: `id1,id2,id3` |
| `Map<String, String>` (e.g. `parentRelTypes`) | `key=value,key=value` |
| `DateTime` | ISO-8601 string |
| `GeoCoord` | JSON blob |
| `List<String>` with free text (aliases, photoPaths) | Semicolon-separated |
| `bool` | Integer 0/1 |

---

## Database Schema

**Engine:** SQLite via `sqflite` (mobile) and `sqflite_common_ffi` (desktop)  
**File:** `{ApplicationDocumentsDirectory}/vetviona.db`  
**Current schema version:** 7

### Tables

#### `trees`
| Column | Type | Notes |
|--------|------|-------|
| `id` | TEXT PK | UUID |
| `name` | TEXT | Display name |

#### `persons`
| Column | Type |
|--------|------|
| `id` | TEXT PK |
| `name` | TEXT |
| `birthDate` | TEXT |
| `birthPlace` | TEXT |
| `birthCoord` | TEXT (JSON) |
| `birthPostalCode` | TEXT |
| `deathDate` | TEXT |
| `deathPlace` | TEXT |
| `deathCoord` | TEXT (JSON) |
| `deathPostalCode` | TEXT |
| `causeOfDeath` | TEXT |
| `burialDate` | TEXT |
| `burialPlace` | TEXT |
| `burialCoord` | TEXT (JSON) |
| `burialPostalCode` | TEXT |
| `gender` | TEXT |
| `parentIds` | TEXT |
| `childIds` | TEXT |
| `parentRelTypes` | TEXT |
| `photoPaths` | TEXT |
| `sourceIds` | TEXT |
| `notes` | TEXT |
| `treeId` | TEXT |
| `occupation` | TEXT |
| `nationality` | TEXT |
| `maidenName` | TEXT |
| `isPrivate` | INTEGER (0/1) |
| `preferredSourceIds` | TEXT |
| `bloodType` | TEXT |
| `eyeColour` | TEXT |
| `hairColour` | TEXT |
| `height` | TEXT |
| `religion` | TEXT |
| `education` | TEXT |
| `aliases` | TEXT |

#### `sources`
| Column | Type |
|--------|------|
| `id` | TEXT PK |
| `personId` | TEXT |
| `title` | TEXT |
| `type` | TEXT |
| `url` | TEXT |
| `imagePath` | TEXT |
| `extractedInfo` | TEXT |
| `citedFacts` | TEXT |
| `author` | TEXT |
| `publisher` | TEXT |
| `publicationDate` | TEXT |
| `repository` | TEXT |
| `volumePage` | TEXT |
| `retrievalDate` | TEXT |
| `confidence` | TEXT |
| `treeId` | TEXT |

#### `partnerships`
| Column | Type |
|--------|------|
| `id` | TEXT PK |
| `person1Id` | TEXT |
| `person2Id` | TEXT |
| `status` | TEXT |
| `startDate` | TEXT |
| `startPlace` | TEXT |
| `endDate` | TEXT |
| `endPlace` | TEXT |
| `notes` | TEXT |
| `ceremonyType` | TEXT |
| `sourceIds` | TEXT |
| `witnesses` | TEXT |
| `treeId` | TEXT |

#### `life_events`
| Column | Type |
|--------|------|
| `id` | TEXT PK |
| `personId` | TEXT |
| `title` | TEXT |
| `date` | TEXT |
| `place` | TEXT |
| `notes` | TEXT |
| `treeId` | TEXT |

#### `medical_conditions`
| Column | Type |
|--------|------|
| `id` | TEXT PK |
| `personId` | TEXT |
| `condition` | TEXT |
| `category` | TEXT |
| `ageOfOnset` | TEXT |
| `notes` | TEXT |
| `attachmentPaths` | TEXT |
| `treeId` | TEXT |

#### `research_tasks`
| Column | Type |
|--------|------|
| `id` | TEXT PK |
| `personId` | TEXT |
| `title` | TEXT |
| `notes` | TEXT |
| `status` | TEXT |
| `priority` | TEXT |
| `treeId` | TEXT |

#### `devices`
| Column | Type |
|--------|------|
| `id` | TEXT PK |
| `sharedSecret` | TEXT |
| `tier` | TEXT |

### Migration History

| Version | Changes |
|---------|---------|
| 1 → 2 | Added `tier` to `devices` table |
| 2 → 3 | Added `parentRelTypes`; created `partnerships` table; migrated `spouseId` → `partnerships` |
| 3 → 4 | Added `occupation`, `nationality`, `maidenName`, burial fields to `persons` |
| 4 → 5 | Added `GeoCoord` columns (`birthCoord`, `deathCoord`, `burialCoord`, postal codes) |
| 5 → 6 | Added `isPrivate`, `preferredSourceIds`; created `medical_conditions` and `research_tasks` tables |
| 6 → 7 | Added physical traits (`bloodType`, `eyeColour`, `hairColour`, `height`, `religion`, `education`, `aliases`); added source metadata (`author`, `publisher`, `publicationDate`, `repository`, `volumePage`, `retrievalDate`, `confidence`); expanded `partnerships` fields |

---

## TreeProvider (Central Data Hub)

`app/lib/providers/tree_provider.dart` (~1300 lines) is the single source of truth for all genealogical data.

### Key State

| Property | Type | Description |
|----------|------|-------------|
| `persons` | `List<Person>` | All people |
| `sources` | `List<Source>` | All sources |
| `partnerships` | `List<Partnership>` | All partnerships |
| `lifeEvents` | `List<LifeEvent>` | All life events |
| `medicalConditions` | `List<MedicalCondition>` | All medical records |
| `researchTasks` | `List<ResearchTask>` | All research tasks |
| `trees` | `List<Map<String, String>>` | Tree records (id + name) |
| `currentTreeId` | `String` | Active tree UUID |
| `pairedDevices` | `List<Device>` | Sync-paired devices |
| `homePersonId` | `String?` | Tree view focal point |
| `dateFormat` | `String` | User date format preference |
| `colonizationLevel` | `int` | Place name display level |
| `isLoaded` | `bool` | True after first `loadPersons()` completes |
| `loadingProgress` | `double` | 0.0 → 1.0 during load |

### Key Methods

| Method | Description |
|--------|-------------|
| `loadPersons()` | Async load of all tables; updates progress/message |
| `addPerson(Person)` | Insert + notifyListeners |
| `updatePerson(Person)` | Update + notifyListeners |
| `deletePerson(id)` | Delete + clean up cross-references |
| `addPartnership(Partnership)` | Insert partnership |
| `updatePartnership(Partnership)` | Update partnership |
| `deletePartnership(id)` | Delete partnership |
| `addSource(Source)` | Insert source |
| `updateSource(Source)` | Update source |
| `deleteSource(id)` | Delete source |
| `addLifeEvent(LifeEvent)` | Insert life event |
| `updateLifeEvent(LifeEvent)` | Update life event |
| `deleteLifeEvent(id)` | Delete life event |
| `addMedicalCondition(MedicalCondition)` | Insert condition |
| `addResearchTask(ResearchTask)` | Insert task |
| `importFromSync(Map)` | Merge incoming sync data |
| `exportForSync()` | Serialize all data for transmission |
| `findRelationshipPath(fromId, toId)` | BFS relationship finder |
| `searchPersons(query)` | Filter persons by name/place/notes |
| `setHomePersonId(id?)` | Set focal person; persist to SharedPreferences |
| `setDateFormat(format)` | Persist date format |
| `setColonizationLevel(level)` | Persist place display level |
| `login(username, password)` | Local SHA-256 auth |
| `register(username, password)` | Create local account |
| `logout()` | Clear current user |

---

## Services Reference

| Service | File | Responsibility |
|---------|------|---------------|
| `SyncService` | `sync_service.dart` | RootLoop™ HTTP server + mDNS + AES-256 sync engine |
| `BluetoothSyncService` | `bluetooth_sync_service.dart` | BLE advertisement and peer discovery |
| `GedcomParser` | `gedcom_parser.dart` | GEDCOM 5.5.1 import and export |
| `PlaceService` | `place_service.dart` | Historical place search with era filtering |
| `PurchaseService` | `purchase_service.dart` | In-app purchase (Mobile Paid) |
| `PdfReportService` | `pdf_report_service.dart` | PDF generation for family book and medical history |
| `SoundService` | `sound_service.dart` | UI sound effects for sync events |
| `ShareSyncService` | `share_sync_service.dart` | File-based encrypted tree export/import |
| `NominatimService` | `nominatim_service.dart` | Reverse geocoding (lat/lng → address) |

---

## Key Packages

| Package | Version | Use |
|---------|---------|-----|
| `sqflite` + `sqflite_common_ffi` | ^2.0 | SQLite (mobile + desktop) |
| `provider` | ^6.0 | State management |
| `encrypt` | ^5.0 | AES-256-CBC encryption |
| `crypto` | ^3.0 | SHA-256 hashing |
| `bonsoir` | ^6.0 | mDNS discovery |
| `shelf` + `shelf_router` | ^1.4 | HTTP server |
| `flutter_blue_plus` | ^2.0 | Bluetooth LE |
| `graphview` | ^1.2 | Graph layout (descendants tree) |
| `flutter_map` | ^7.0 | OpenStreetMap widget |
| `in_app_purchase` | ^3.2 | IAP |
| `pdf` + `printing` | ^3.11 | PDF generation |
| `mobile_scanner` + `qr_flutter` | ^6.0 / ^4.1 | QR code scan/generate |
| `uuid` | ^4.0 | UUID generation |
| `intl` | ^0.20 | Date/time formatting |
| `file_picker` | ^11.0 | File system access |
| `shared_preferences` | ^2.0 | Persistent key-value settings |
| `share_plus` | ^10.0 | AirDrop / Nearby Share |

---

## Authentication

Authentication is **local-only** — there is no server.

```
Registration:
  salt     = UUID()
  hash     = SHA-256(password + salt) → hex
  stored   = SharedPreferences["user_<username>"] = "<salt>:<hash>"

Login:
  split    = stored.split(":")
  computed = SHA-256(password + split[0]) → hex
  match    = (computed == split[1])
```

Authentication is **optional** — the app works without login for local single-user use.

---

## Navigation Patterns

All screen navigation uses `utils/page_routes.dart` helpers:

```dart
Navigator.push(context, fadeSlideRoute(builder: (_) => SomeScreen()));
```

This applies a consistent **fade + slide** transition across the whole app.

The startup router in `app.dart` checks `SharedPreferences["onboardingDone"]` to decide whether to show `OnboardingScreen` or `HomeScreen` on first launch.
