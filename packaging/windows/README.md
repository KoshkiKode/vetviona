# Windows Packaging — Vetviona

This directory contains the WiX v5 installer source (`vetviona.wxs`) used to produce a signed `.msi` installer for Vetviona Desktop Pro on Windows.

## Prerequisites

- [.NET SDK](https://dotnet.microsoft.com/download) ≥ 6
- WiX v5 dotnet tool: `dotnet tool install --global wix --version 5.0.2`
- WiX UI extension: `wix extension add -g WixToolset.UI.wixext/5.0.2`
- A Windows Developer certificate (optional, for signing)

## Building the MSI locally

1. Build the Flutter release first:
   ```powershell
   cd ../../app
   flutter build windows --release --dart-define=PAID=true
   ```

2. Copy the WiX source and licence file into the build output:
   ```powershell
   copy packaging\windows\vetviona.wxs app\build\windows\x64\runner\Release\
   copy packaging\windows\LICENSE.rtf  app\build\windows\x64\runner\Release\
   ```

3. Harvest the release directory and build the MSI:
   ```powershell
   cd app\build\windows\x64\runner\Release
   wix harvest dir . -gg -srd -dr INSTALLFOLDER -cg AppFiles -o harvest.wxs
   wix build vetviona.wxs harvest.wxs -ext WixToolset.UI.wixext/5.0.2 -o vetviona-setup.msi
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
