#!/usr/bin/env bash
set -e

echo "========================================================"
echo " Building Vetviona Native Linux Release Packages        "
echo "========================================================"

CDIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$CDIR/app"

cd "$APP_DIR"
flutter pub get

echo "Building release Linux Desktop binary..."
flutter build linux --release

echo "Building Debian (.deb) package..."
bash "$CDIR/packaging/linux/deb/build_deb.sh"

echo ""
echo "✅ Linux Desktop build completed!"
echo "Debian Package Output: packaging/linux/vetviona_1.0.0_amd64.deb"
echo "Snap Config: packaging/linux/snap/snapcraft.yaml"
echo "Flatpak Config: packaging/linux/flatpak/com.koshkikode.Vetviona.yml"
