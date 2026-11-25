#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-1.0.0}"
VERSION="${VERSION#v}"
ARCH="amd64"
PKG_NAME="wallcycle"
STAGE_DIR="$(mktemp -d)"
trap 'rm -rf "$STAGE_DIR"' EXIT

if [[ ! -f "bin/WallCycle" ]]; then
  echo "Errore: binario bin/WallCycle non trovato. Compila prima con lazbuild --build-mode=Release WallCycle.lpi" >&2
  exit 1
fi

mkdir -p "$STAGE_DIR/DEBIAN" \
         "$STAGE_DIR/usr/bin" \
         "$STAGE_DIR/usr/share/applications" \
         "$STAGE_DIR/usr/share/doc/$PKG_NAME"

install -m 755 "bin/WallCycle" "$STAGE_DIR/usr/bin/wallcycle"
install -m 644 "wallcycle.desktop" "$STAGE_DIR/usr/share/applications/wallcycle.desktop"
install -m 644 "README.md" "$STAGE_DIR/usr/share/doc/$PKG_NAME/README.md"

cat > "$STAGE_DIR/DEBIAN/control" <<EOF
Package: $PKG_NAME
Version: $VERSION
Section: utils
Priority: optional
Architecture: $ARCH
Depends: libgtk2.0-0 (>= 2.24.0), curl | wget
Recommends: awww | hyprpaper | sway | feh
Maintainer: WallCycle Maintainers <noreply@example.com>
Description: Cross-platform desktop wallpaper slideshow with clock overlay
 WallCycle gestisce slideshow automatici di sfondi da cartelle locali e
 WallHaven.cc con filtro luminanza BT.709, overlay Data & Ora personalizzabile,
 istanza singola CLI e supporto per GNOME, KDE, XFCE, Hyprland, Niri e Umbriel.
EOF

OUT_DEB="${PKG_NAME}_${VERSION}_${ARCH}.deb"
dpkg-deb --build --root-owner-group "$STAGE_DIR" "$OUT_DEB"
echo "Creato pacchetto Debian: $OUT_DEB"
