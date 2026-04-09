# macOS Packaging — Vetviona

## Requirements

- macOS with Xcode ≥ 14
- Flutter ≥ 3.0 with macOS desktop enabled (`flutter config --enable-macos-desktop`)
- An Apple Developer account for signing and notarization

## Building locally

```bash
cd app
flutter build macos --release --dart-define=PAID=true
```

The built `.app` bundle will be at:
```
app/build/macos/Build/Products/Release/vetviona.app
```

## Creating a DMG

```bash
hdiutil create -volname "Vetviona" \
  -srcfolder app/build/macos/Build/Products/Release/vetviona.app \
  -ov -format UDZO \
  vetviona-macos.dmg
```

## Code signing (for distribution outside App Store)

```bash
codesign --deep --force --verify --verbose \
  --sign "Developer ID Application: KoshkiKode (TEAMID)" \
  --entitlements packaging/macos/entitlements.plist \
  app/build/macos/Build/Products/Release/vetviona.app
```

## Notarization

```bash
xcrun notarytool submit vetviona-macos.dmg \
  --apple-id "you@koshkikode.com" \
  --team-id "YOURTEAMID" \
  --password "@keychain:AC_PASSWORD" \
  --wait

xcrun stapler staple vetviona-macos.dmg
```

## Required secrets for CI

| Secret | Purpose |
|--------|---------|
| `MACOS_CERTIFICATE_BASE64` | Developer ID Application certificate (p12, base64) |
| `MACOS_CERTIFICATE_PASSWORD` | p12 password |
| `MACOS_NOTARIZE_APPLE_ID` | Apple ID email |
| `MACOS_NOTARIZE_TEAM_ID` | Team ID |
| `MACOS_NOTARIZE_PASSWORD` | App-specific password |
