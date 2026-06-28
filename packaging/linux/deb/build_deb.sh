#!/usr/bin/env bash
set -e

echo "Building Vetviona Linux Desktop Bundle..."
cd "$(dirname "$0")/../../../app"
flutter build linux --release

BUILD_DIR="$(pwd)/build/linux/x64/release/bundle"
DEB_STAGING="$(pwd)/../packaging/linux/deb/staging"

rm -rf "$DEB_STAGING"
mkdir -p "$DEB_STAGING/DEBIAN"
mkdir -p "$DEB_STAGING/usr/lib/vetviona"
mkdir -p "$DEB_STAGING/usr/bin"
mkdir -p "$DEB_STAGING/usr/share/applications"
mkdir -p "$DEB_STAGING/usr/share/pixmaps"

cp "$(pwd)/../packaging/linux/deb/control" "$DEB_STAGING/DEBIAN/control"
cp -r "$BUILD_DIR/"* "$DEB_STAGING/usr/lib/vetviona/"

ln -sf /usr/lib/vetviona/vetviona_app "$DEB_STAGING/usr/bin/vetviona"

cat <<EOF > "$DEB_STAGING/usr/share/applications/vetviona.desktop"
[Desktop Entry]
Name=Vetviona
Comment=Private local-first genealogy software
Exec=/usr/bin/vetviona
Icon=vetviona
Terminal=false
Type=Application
Categories=Office;Genealogy;Utility;
EOF

if [ -f "$(pwd)/assets/icon/app_icon.png" ]; then
  cp "$(pwd)/assets/icon/app_icon.png" "$DEB_STAGING/usr/share/pixmaps/vetviona.png"
fi

dpkg-deb --build "$DEB_STAGING" "$(pwd)/../packaging/linux/vetviona_1.0.0_amd64.deb"
echo "Debian package created successfully: packaging/linux/vetviona_1.0.0_amd64.deb"
