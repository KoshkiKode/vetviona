#!/usr/bin/env bash
set -e

echo "========================================================================="
echo " Vetviona Master Native Local Build Pipeline Automation Suite           "
echo "========================================================================="

CDIR="$(cd "$(dirname "$0")" && pwd)"

OS_TYPE="$(uname -s)"
echo "Detected Host Operating System: $OS_TYPE"
echo ""

case "$OS_TYPE" in
  Darwin*)
    echo "[1/3] Building macOS Native Desktop Release..."
    bash "$CDIR/build_macos.sh"
    echo ""
    echo "[2/3] Building iOS Native Mobile Archive..."
    bash "$CDIR/build_ios.sh"
    echo ""
    echo "[3/3] Building Android Native Mobile Package..."
    bash "$CDIR/build_android.sh"
    ;;
  Linux*)
    echo "[1/2] Building Linux Native Desktop Releases (Deb, Snap, Flatpak)..."
    bash "$CDIR/build_linux.sh"
    echo ""
    echo "[2/2] Building Android Native Mobile Package..."
    bash "$CDIR/build_android.sh"
    ;;
  MINGW*|MSYS*|CYGWIN*)
    echo "[1/2] Building Windows Native Desktop Release..."
    bash "$CDIR/build_windows.sh"
    echo ""
    echo "[2/2] Building Android Native Mobile Package..."
    bash "$CDIR/build_android.sh"
    ;;
  *)
    echo "Building cross-platform artifacts for host: $OS_TYPE"
    bash "$CDIR/build_android.sh"
    ;;
esac

echo ""
echo "========================================================================="
echo " 🎉 All Native Local Build Pipeline Targets Completed Successfully!     "
echo "========================================================================="
