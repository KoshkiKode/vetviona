#!/bin/bash
echo "Building iOS..."
flutter build ios --no-codesign
echo "Building APK..."
flutter build apk
echo "Done!"
