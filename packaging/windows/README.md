# Windows Packaging — Vetviona

This directory contains the WiX v4 installer source (`vetviona.wxs`) used to produce a signed `.msi` installer for Vetviona Desktop Pro on Windows.

## Prerequisites

- [.NET SDK](https://dotnet.microsoft.com/download) ≥ 6
- WiX v4 dotnet tool: `dotnet tool install --global wix`
- A Windows Developer certificate (optional, for signing)

## Building the MSI locally

1. Build the Flutter release first:
   ```powershell
   cd ../../app
   flutter build windows --release --dart-define=PAID=true
   ```

2. Copy the WiX source into the build output:
   ```powershell
   copy packaging\windows\vetviona.wxs app\build\windows\x64\runner\Release\
   ```

3. Build the MSI:
   ```powershell
   cd app\build\windows\x64\runner\Release
   wix build vetviona.wxs -o vetviona-setup.msi
   ```

## Signing the installer (optional)

```powershell
signtool sign /fd SHA256 /tr http://timestamp.sectigo.com /td SHA256 `
  /f your-certificate.pfx /p YourPassword `
  vetviona-setup.msi
```

## WiX source notes

- `UpgradeCode` in `vetviona.wxs` is a fixed GUID — **do not change it** between releases; it is used to detect upgrades and remove old versions.
- The `Version` field must be incremented on each release to trigger a major-upgrade flow.
- The `data/` folder referenced in the WiX source maps to the `data/` subdirectory Flutter places alongside the executable in the release output.
