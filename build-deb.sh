#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.0}"
VERSION="${VERSION#v}"
ARCH="amd64"
PKG_NAME="wallcycle"
STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT

if [[ ! -f "bin/WallCycle" ]]; then
  echo "Error: bin/WallCycle binary not found. Build first with lazbuild --widgetset=qt5 --build-mode=Release WallCycle.lpi" >&2
  exit 1
fi

mkdir -p "$STAGE_DIR/DEBIAN" \
         "$STAGE_DIR/usr/bin" \
         "$STAGE_DIR/usr/share/applications" \
         "$STAGE_DIR/usr/share/icons/hicolor/512x512/apps" \
         "$STAGE_DIR/usr/share/doc/$PKG_NAME"

install -m 755 "bin/WallCycle" "$STAGE_DIR/usr/bin/wallcycle"
install -m 644 "wallcycle.desktop" "$STAGE_DIR/usr/share/applications/wallcycle.desktop"
install -m 644 "wallcycle.png" "$STAGE_DIR/usr/share/icons/hicolor/512x512/apps/wallcycle.png"
install -m 644 "README.md" "$STAGE_DIR/usr/share/doc/$PKG_NAME/README.md"

cat > "$STAGE_DIR/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Depends: libqt5pas1 | libqt5pas1t64, curl | wget
Recommends: awww | hyprpaper | sway | feh
Maintainer: Federico Paolini <nightranger7@gmail.com>
Description: Cross-platform desktop wallpaper slideshow with clock overlay
 WallCycle runs an automatic wallpaper slideshow from local folders and
 WallHaven.cc with an ITU-R BT.709 luminance filter, customizable Date & Time
 overlay, multi-monitor support, Smart Pause, Favorites, and Blacklist.
EOF

OUT_DEB="${PKG_NAME}_${VERSION}_${ARCH}.deb"
dpkg-deb --build --root-owner-group "$STAGE_DIR" "$OUT_DEB"
echo "Created Debian package: $OUT_DEB"
