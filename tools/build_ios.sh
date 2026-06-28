#!/usr/bin/env bash
set -e

echo "========================================================"
echo " Building Vetviona Native iOS Release Package (Paid)   "
echo "========================================================"

CDIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$CDIR/app"

cd "$APP_DIR"
flutter pub get

echo "Building release iOS IPA..."
flutter build ipa --release --no-codesign

echo ""
echo "✅ iOS build completed! Package archive output generated in app/build/ios/archive/"
