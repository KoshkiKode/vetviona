#!/usr/bin/env bash
set -e

echo "========================================================"
echo " Building Vetviona Native Android Release (Paid)        "
echo "========================================================"

CDIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$CDIR/app"

cd "$APP_DIR"
flutter pub get

echo "Building release APK..."
flutter build apk --release

echo "Building release App Bundle (AAB)..."
flutter build appbundle --release

echo ""
echo "✅ Android build completed!"
echo "APK Output: app/build/app/outputs/flutter-apk/app-release.apk"
echo "AAB Output: app/build/app/outputs/bundle/release/app-release.aab"
