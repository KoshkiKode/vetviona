#!/usr/bin/env bash
set -e

echo "========================================================"
echo " Building Vetviona Native Windows Release (Paid Pro)    "
echo "========================================================"

CDIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$CDIR/app"

cd "$APP_DIR"
flutter pub get

echo "Building release Windows Desktop executable..."
flutter build windows --release

echo ""
echo "✅ Windows Desktop build completed! Bundle output in app/build/windows/x64/runner/Release/"
