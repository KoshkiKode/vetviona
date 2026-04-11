# Building and Development

This page covers building Vetviona from source, running tests, and understanding the CI/CD pipeline.

---

## Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) ≥ 3.0.0 (stable channel)
- Dart ≥ 3.0.0 (included with Flutter)
- **Android:** Android SDK, JDK 17+
- **iOS / macOS:** Xcode 15+, CocoaPods
- **Windows:** Visual Studio 2022 with "Desktop development with C++"
- **Linux:** `clang`, `cmake`, `ninja-build`, `libgtk-3-dev`

---

## Clone and Set Up

```bash
git clone https://github.com/KoshkiKode/vetviona.git
cd vetviona/app
flutter pub get
```

---

## Running in Development

```bash
# Mobile Free (default)
flutter run

# Mobile Paid
flutter run --dart-define=MOBILE_PAID=true

# Desktop Pro (Windows example)
flutter run -d windows --dart-define=PAID=true
```

> Desktop builds without `--dart-define=PAID=true` will show a lock screen at startup.

---

## Build Commands

### Android APK

```bash
# Mobile Free
flutter build apk --release

# Mobile Paid
flutter build apk --release --dart-define=MOBILE_PAID=true
```

### iOS

```bash
# Mobile Free
flutter build ios --release

# Mobile Paid
flutter build ios --release --dart-define=MOBILE_PAID=true
```

### Windows

```bash
flutter build windows --release --dart-define=PAID=true
```

### macOS

```bash
flutter build macos --release --dart-define=PAID=true
```

### Linux

```bash
flutter build linux --release --dart-define=PAID=true
```

---

## Running Tests

All tests live in `app/test/`. Run the full suite with:

```bash
cd app
flutter test --reporter=expanded
```

### Test Structure

| Directory | Coverage area |
|-----------|--------------|
| `test/models/` | Model serialization: `toMap()`, `fromMap()`, `toJson()`, `fromJson()` |
| `test/providers/` | Provider state management, CRUD operations, theme loading |
| `test/services/` | GEDCOM parsing/export, place search and era filtering |

### Test Files

| File | What it tests |
|------|--------------|
| `models/person_test.dart` | Person serialization + all fields |
| `models/partnership_test.dart` | Partnership status, serialization |
| `models/source_test.dart` | Source fields, confidence rating |
| `models/life_event_test.dart` | LifeEvent serialization |
| `models/medical_condition_test.dart` | MedicalCondition categories, suggestions |
| `models/research_task_test.dart` | Task status/priority |
| `models/device_test.dart` | Device creation, serialization |
| `models/place_test.dart` | Place name helpers, era validity |
| `models/geo_coord_test.dart` | GeoCoord serialization, short label |
| `providers/tree_provider_test.dart` | searchPersons, findRelationshipPath, partnershipsFor, exportForSync |
| `providers/theme_provider_test.dart` | Theme loading, dark mode, color persistence |
| `services/gedcom_parser_test.dart` | GEDCOM parse + export round-trips |
| `services/place_service_test.dart` | Place search, era filtering |

### Writing Tests for TreeProvider

`TreeProvider` pure-logic methods can be tested without a database by directly assigning to the public lists:

```dart
final provider = TreeProvider();
provider.persons = [Person(id: '1', name: 'Alice'), ...];
provider.partnerships = [...];
final path = provider.findRelationshipPath('1', '3');
```

Auth tests use:

```dart
SharedPreferences.setMockInitialValues({});
```

---

## Lint

```bash
cd app
flutter analyze
```

Lint rules are in `analysis_options.yaml` (using `flutter_lints`).

---

## CI/CD

GitHub Actions workflow: `.github/workflows/test.yml`

Triggers on:
- Push to `main` / `master`
- Pull request to `main` / `master`
- Manual dispatch (`workflow_dispatch`)

Steps:
1. Checkout
2. Set up Flutter (stable channel, with cache)
3. `flutter pub get`
4. `flutter test`

---

## Project Structure Quick Reference

```
vetviona/
├── app/                    # Flutter app (all source code here)
│   ├── lib/
│   │   ├── app.dart
│   │   ├── main.dart
│   │   ├── config/         # Tier detection, build metadata
│   │   ├── models/         # Data models (9 files)
│   │   ├── providers/      # State management (2 files)
│   │   ├── screens/        # UI screens (27 files)
│   │   ├── services/       # Business logic (9+ files)
│   │   │   └── places/     # Historical place data
│   │   └── utils/          # Page routes helper
│   ├── test/               # Unit tests
│   ├── assets/             # App assets (sounds, icons)
│   └── pubspec.yaml
├── wiki/                   # GitHub Wiki markdown source (this folder)
├── website/                # Marketing website
├── packaging/              # Installers and packaging scripts
├── README.md
└── SECURITY.md
```

---

## App Icon

App icons are generated with `flutter_launcher_icons`. Configuration is in `pubspec.yaml` under `flutter_launcher_icons`. Re-run icon generation with:

```bash
cd app
dart run flutter_launcher_icons
```

---

## Versioning

Versions are defined in `app/lib/config/build_metadata.dart`:

```dart
static const String appVersion = '1.0.0';
static const String syncTechVersion = '1.0.0';
```

Update these constants and the `version` field in `pubspec.yaml` when releasing a new version.
