#!/bin/bash
set -e

cd /Users/dylancmoore/vetviona/app

echo "=== Building Vetviona Native Artifacts ==="

echo "1/3: Building Android APK..."
flutter build apk --release

echo "2/3: Building macOS App..."
flutter build macos --release

echo "3/3: Building iOS App (No Codesign for local testing)..."
flutter build ios --release --no-codesign

echo "=== Build Complete! ==="
echo "Artifacts located in build/app/outputs/flutter-apk/, build/macos/Build/Products/Release/, and build/ios/iphoneos/"
