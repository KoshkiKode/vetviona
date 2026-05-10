# Contributing to Vetviona

Thanks for your interest in Vetviona. This guide covers how to set up a local development environment, the coding standards we follow, and how to submit changes.

## Table of Contents

- [Getting Started](#getting-started)
- [Running the App](#running-the-app)
- [Backend (License Server)](#backend-license-server)
- [Running Tests](#running-tests)
- [Code Style](#code-style)
- [Branch & Commit Conventions](#branch--commit-conventions)
- [Submitting a Pull Request](#submitting-a-pull-request)
- [Reporting Issues](#reporting-issues)

---

## Getting Started

**Prerequisites:**
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (latest stable)
- Android Studio (for Android builds + emulator) and/or Xcode (macOS, for iOS builds)
- A physical device or emulator/simulator

```bash
git clone https://github.com/KoshkiKode/vetviona.git
cd vetviona
flutter pub get
```

---

## Running the App

```bash
# List available devices
flutter devices

# Run on a connected device or emulator
flutter run

# Run on a specific device
flutter run -d <device-id>
```

For desktop targets:

```bash
flutter run -d windows
flutter run -d macos
flutter run -d linux
```

---

## Backend (License Server)

The license verification backend is a separate Node.js service in the `backend/` directory. You only need to run it locally if you're working on purchase/license validation flows.

See [`backend/DEPLOY.md`](./backend/DEPLOY.md) for setup instructions.

For local development without a real license server, the app includes a dev bypass — check the app's feature flag constants.

---

## Running Tests

```bash
# All Flutter unit and widget tests
flutter test

# A specific test file
flutter test test/some_test.dart
```

Please add or update tests for any behaviour you change.

---

## Code Style

- **Dart formatting** — run `dart format .` before committing. The CI will reject unformatted code.
- **Static analysis** — run `flutter analyze` and resolve all warnings before pushing.
- **Naming** — follow Dart/Flutter conventions: `camelCase` for variables and functions, `PascalCase` for classes and widgets, `snake_case` for files.
- **Widgets** — keep widgets small and focused. Extract child widgets into their own files when they grow beyond ~80 lines.
- **State management** — follow the existing pattern in the codebase; check how neighbouring screens manage state before introducing a new approach.

---

## Branch & Commit Conventions

**Branch naming:**

```
feat/short-description
fix/short-description
chore/short-description
docs/short-description
```

**Commit messages** follow [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add life timeline view for individuals
fix: correct GEDCOM import for multi-byte names
chore: upgrade flutter sdk to 3.x
docs: expand RootLoop sync troubleshooting section
```

---

## Submitting a Pull Request

1. Fork the repo and create your branch from `main`.
2. Make your changes with tests where applicable.
3. Run `dart format . && flutter analyze && flutter test` — all must pass.
4. Open a PR against `main` and fill in the PR template.
5. Link the relevant issue in the PR description.

PRs that touch RootLoop™ sync, GEDCOM import/export, or the license backend require extra care — please describe your change thoroughly and include manual testing notes across at least two platforms.

---

## Reporting Issues

Use the issue templates:
- **Bug report** — for unexpected behaviour
- **Feature request** — for new ideas

For security vulnerabilities, see [SECURITY.md](./SECURITY.md) — **do not** open a public issue.
