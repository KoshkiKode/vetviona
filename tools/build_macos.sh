#!/usr/bin/env bash
set -e

echo "========================================================"
echo " Building Vetviona Native macOS Release (Paid Pro)      "
echo "========================================================"

CDIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$CDIR/app"

cd "$APP_DIR"
flutter pub get

echo "Building release macOS Desktop bundle..."
flutter build macos --release

echo ""
echo "✅ macOS Desktop build completed! Bundle output in app/build/macos/Build/Products/Release/Vetviona.app"
