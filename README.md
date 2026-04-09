# Vetviona

**Your family history, beautifully organized.**

Vetviona is a private, local-first genealogy app by [KoshkiKode](https://koshkikode.com). Build interactive family trees, attach sources, sync across devices — all without a server you need to maintain.

> 🌿 **Website:** [vetviona.koshkikode.com](https://vetviona.koshkikode.com)

---

## Platforms

| Platform | Format | Status |
|----------|--------|--------|
| Android  | APK / AAB | ✅ Supported |
| iOS      | IPA | ✅ Supported |
| Windows  | EXE + MSI (WiX) | ✅ Supported |
| macOS    | DMG | ✅ Supported |
| Linux    | DEB + Snap + Flatpak | ✅ Supported |

---

## Features

- 🌳 **Interactive Tree Builder** — Add people, define parent-child relationships, link spouses, and visualize your tree with smooth pan & zoom.
- 📚 **Source Citations** — Attach citations to specific facts (birth, marriage, death) and keep every claim backed by evidence.
- 📍 **Historical Place Matching** — Date-aware place autocomplete that understands that borders, names, and jurisdictions change over time.
- 🔄 **RootLoop™ Sync** — Proprietary two-tier sync layer (see below).
- 📤 **GEDCOM Import & Export** — Industry-standard format for importing existing trees and exporting to any compatible app.
- 🎨 **Custom Themes** — Personalise the app's color scheme; theme settings sync across your devices.
- ⏱ **Life Timelines** — View an individual's key life events in a clean chronological timeline.
- 🔍 **Relationship Finder** — Instantly discover how two people in your tree are related.
- 🔒 **Encrypted Sync** — All device-to-device sync is zero-knowledge encrypted.

---

## RootLoop™

**RootLoop™** is Vetviona's proprietary sync layer. Devices exchange encrypted family-tree data directly — no external server required.

### RootLoop™ Auto
Full WiFi sync that runs automatically whenever your devices join the same home network. Like a client-server pair that just works — no setup needed.

### RootLoop™ Manual
On-demand sync you trigger inside the app, over Bluetooth or any local connection you initiate. Full control over when data moves.

| Tier | Transport | Trigger | Included In |
|------|-----------|---------|-------------|
| RootLoop™ Auto | WiFi | Automatic | Mobile Free + Desktop Pro |
| RootLoop™ Manual | Bluetooth | On-demand | Desktop Pro only |

> RootLoop™ is versioned independently from the app. Current version: **1.0.0**

---

## Pricing

| Tier | Price | Platforms |
|------|-------|-----------|
| **Mobile Free** | Free, always | Android & iOS |
| **Desktop Pro** | One-time purchase | Windows · macOS · Linux |

No subscriptions. No recurring fees. Desktop Pro unlocks GEDCOM import/export, Bluetooth sync (RootLoop™ Manual), and unlimited trees.

---

## Project Structure

```
vetviona/
├── app/                   # Flutter application
│   ├── lib/
│   │   ├── config/        # Build metadata, versioning
│   │   ├── models/        # Data models (Person, Source, Place, Device)
│   │   ├── providers/     # State management (TreeProvider, ThemeProvider)
│   │   ├── screens/       # UI screens
│   │   ├── services/      # GEDCOM parser, place service, sync
│   │   ├── app.dart       # App root widget
│   │   └── main.dart      # Entry point (with paid/free build flag)
│   └── pubspec.yaml
├── website/               # Static marketing site
│   └── index.html
├── packaging/
│   ├── windows/           # WiX installer config (.wxs)
│   ├── macos/             # Entitlements & notarization
│   ├── linux/
│   │   ├── snap/          # Snapcraft manifest
│   │   └── flatpak/       # Flatpak manifest
│   └── android/           # Signing docs
└── .github/workflows/     # CI/CD for all platforms
```

---

## Building from Source

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) ≥ 3.0.0
- Dart SDK ≥ 3.0.0 (bundled with Flutter)
- Platform-specific toolchains (Xcode for iOS/macOS, Visual Studio for Windows, etc.)

### Clone & setup

```bash
git clone https://github.com/KoshkiKode/untitled-ancestry-app.git
cd untitled-ancestry-app/app
flutter pub get
```

> **Note:** The repository is currently named `untitled-ancestry-app` on GitHub. The canonical name for the project is **Vetviona**.

### Run (debug)

```bash
flutter run
```

### Build — Mobile

```bash
# Android APK (free tier)
flutter build apk --release

# Android App Bundle (for Play Store)
flutter build appbundle --release

# iOS (requires macOS + Xcode)
flutter build ios --release --no-codesign
```

### Build — Desktop

```bash
# Windows EXE
flutter build windows --release

# macOS app bundle
flutter build macos --release

# Linux
flutter build linux --release
```

### Build — Desktop Pro (paid flag)

```bash
# The PAID compile-time flag unlocks the desktop version
flutter build windows --release --dart-define=PAID=true
flutter build macos  --release --dart-define=PAID=true
flutter build linux  --release --dart-define=PAID=true
```

### Package — Windows MSI (WiX)

See [`packaging/windows/README.md`](packaging/windows/README.md).

### Package — Linux Snap / Flatpak

See [`packaging/linux/snap/`](packaging/linux/snap/) and [`packaging/linux/flatpak/`](packaging/linux/flatpak/).

---

## CI / CD

GitHub Actions workflows live in [`.github/workflows/`](.github/workflows/):

| Workflow | Trigger | Output |
|----------|---------|--------|
| `build-android.yml` | push / tag | APK + AAB |
| `build-ios.yml` | push / tag | .ipa |
| `build-windows.yml` | push / tag | .exe + .msi |
| `build-macos.yml` | push / tag | .dmg |
| `build-linux.yml` | push / tag | .deb + .snap + .flatpak |
| `release.yml` | `v*` tag | All platforms → GitHub Release |

---

## Versioning

Components are versioned independently:

| Component | Version |
|-----------|---------|
| Vetviona App | 1.0.0 |
| RootLoop™ | 1.0.0 |

---

## Branding

| Token | Hex | Role |
|-------|-----|------|
| Primary | `#1a3c34` | Main brand, buttons, headers |
| Secondary | `#2d5a4f` | Hover states, borders |
| Accent | `#5a9a87` | CTAs, links, highlights |
| Paper | `#f8f7f3` | Backgrounds, cards |
| Ink | `#1f1f1f` | Main text |
| Dust | `#8b8b7f` | Secondary text |
| Brass | `#c9a86e` | Subtle borders, icons |
| Burgundy | `#5c2d2e` | Errors, root lines |

Full color reference: [`Role-Hex-LightModeUsage-DarkModeUsage.csv`](Role-Hex-LightModeUsage-DarkModeUsage.csv)

---

## License

© 2026 [KoshkiKode](https://koshkikode.com). All rights reserved.

Vetviona and RootLoop™ are trademarks of KoshkiKode.

---

## Support

- Website: [vetviona.koshkikode.com](https://vetviona.koshkikode.com)
- Patreon: [patreon.com/KoshkiKode](https://patreon.com/KoshkiKode)
