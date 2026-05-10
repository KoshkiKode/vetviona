# Contributing to Vetviona

See the [organisation-level contributing guide](https://github.com/KoshkiKode/.github/blob/main/.github/CONTRIBUTING.md) for branch naming, commit message conventions, PR guidelines, and code of conduct.

This file covers Vetviona-specific setup and conventions.

---

## Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel, version in `pubspec.yaml`)
- [Dart SDK](https://dart.dev/get-dart) (bundled with Flutter)
- [Rust](https://rustup.rs/) — for the license verification backend in `backend/`
- Android Studio or Xcode for mobile targets

## Local Development

```bash
# Get dependencies
flutter pub get

# Run on a connected device or simulator
flutter run

# Run tests
flutter test

# Analyse code
flutter analyze

# Format code
dart format .
```

## Backend (License Server)

See `backend/DEPLOY.md` for running the license verification server locally.

## Project Structure

```
app/          Flutter source code
backend/      Rust license verification server
packaging/    Platform-specific packaging scripts
tools/        Dev utilities
wiki/         Design docs and planning notes
website/      Vetviona marketing website source
```

## Key Conventions

- All Dart code must pass `flutter analyze` with zero warnings before submitting a PR
- Format with `dart format .` — CI will reject unformatted code
- Keep UI and business logic separated (follow the existing architecture pattern in `app/`)
- Place design documents and planning notes in `wiki/`, not at the repo root
