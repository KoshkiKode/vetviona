#!/usr/bin/env bash
# Builds the Debian package for Vetviona.
#
#   packaging/linux/deb/build_deb.sh                       # build Flutter, then package
#   SKIP_FLUTTER_BUILD=1 packaging/linux/deb/build_deb.sh  # package an existing bundle (CI)
#
# FLUTTER_BUILD_ARGS overrides the default `--dart-define=PAID=true`.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
APP="$ROOT/app"
PKG="$ROOT/packaging/linux"
APP_ID="com.koshkikode.Vetviona"
BIN="vetviona"

VERSION="$(grep -E '^version:' "$APP/pubspec.yaml" | head -1 | awk '{print $2}' | cut -d'+' -f1)"

if [ "${SKIP_FLUTTER_BUILD:-0}" != "1" ]; then
  echo "Building the Vetviona Linux bundle..."
  (cd "$APP" && flutter build linux --release ${FLUTTER_BUILD_ARGS:---dart-define=PAID=true})
fi

BUNDLE="$APP/build/linux/x64/release/bundle"
if [ ! -x "$BUNDLE/$BIN" ]; then
  echo "error: $BUNDLE/$BIN not found - run 'flutter build linux --release' first" >&2
  exit 1
fi

STAGING="$PKG/deb/staging"
rm -rf "$STAGING"
install -d "$STAGING/DEBIAN" "$STAGING/usr/lib/vetviona" "$STAGING/usr/bin"

cp -r "$BUNDLE/." "$STAGING/usr/lib/vetviona/"

# Launcher: run the real binary from its install directory without changing the
# working directory (so relative file arguments keep working).
cat > "$STAGING/usr/bin/$BIN" <<'WRAPPER'
#!/bin/sh
exec /usr/lib/vetviona/vetviona "$@"
WRAPPER
chmod 0755 "$STAGING/usr/bin/$BIN"

# Desktop integration (shared with the Flatpak packaging).
install -Dm644 "$PKG/flatpak/$APP_ID.desktop" "$STAGING/usr/share/applications/$APP_ID.desktop"
install -Dm644 "$PKG/flatpak/$APP_ID.metainfo.xml" "$STAGING/usr/share/metainfo/$APP_ID.metainfo.xml"
install -Dm644 "$PKG/flatpak/$APP_ID.mime.xml" "$STAGING/usr/share/mime/packages/$APP_ID.xml"
install -Dm644 "$APP/assets/icon/app_icon.png" "$STAGING/usr/share/icons/hicolor/256x256/apps/$APP_ID.png"

SIZE="$(du -sk "$STAGING/usr" | cut -f1)"
sed -e "s/^Version:.*/Version: $VERSION/" "$PKG/deb/control" > "$STAGING/DEBIAN/control"
echo "Installed-Size: $SIZE" >> "$STAGING/DEBIAN/control"

OUT="$PKG/vetviona_${VERSION}_amd64.deb"
dpkg-deb --root-owner-group --build "$STAGING" "$OUT"
echo "Debian package created: $OUT"
