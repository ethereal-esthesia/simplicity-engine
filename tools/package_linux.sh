#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

ARCH_LABEL="${ARCH_LABEL:-x64}"
mkdir -p dist

cmake --preset release
cmake --build --preset release
ctest --test-dir build/release --output-on-failure

STAGE_DIR="dist/simplicity-engine-linux-${ARCH_LABEL}"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"
cp "build/release/hello_pixel" "$STAGE_DIR/"

tar -C dist -czf "dist/simplicity-engine-linux-${ARCH_LABEL}.tar.gz" "simplicity-engine-linux-${ARCH_LABEL}"
echo "Created dist/simplicity-engine-linux-${ARCH_LABEL}.tar.gz"

APPIMAGE_ARCH=""
case "$ARCH_LABEL" in
  x64)
    APPIMAGE_ARCH="x86_64"
    ;;
  arm64)
    APPIMAGE_ARCH="aarch64"
    ;;
  *)
    echo "Unsupported ARCH_LABEL: ${ARCH_LABEL}"
    echo "Expected one of: x64, arm64"
    exit 1
    ;;
esac

APPDIR="${ROOT_DIR}/dist/AppDir-${ARCH_LABEL}"
rm -rf "$APPDIR"
mkdir -p "$APPDIR/usr/bin" "$APPDIR/usr/share/applications" "$APPDIR/usr/share/icons/hicolor/scalable/apps"
cp "build/release/hello_pixel" "$APPDIR/usr/bin/hello_pixel"

DESKTOP_FILE="$APPDIR/usr/share/applications/simplicity-engine.desktop"
cat >"$DESKTOP_FILE" <<'EOF'
[Desktop Entry]
Type=Application
Name=Simplicity Engine
Comment=Simple fluid motion graphics runtime
Exec=hello_pixel
Icon=simplicity-engine
Categories=Graphics;Development;
Terminal=false
EOF

ICON_FILE="$APPDIR/usr/share/icons/hicolor/scalable/apps/simplicity-engine.svg"
cat >"$ICON_FILE" <<'EOF'
<svg xmlns="http://www.w3.org/2000/svg" width="256" height="256" viewBox="0 0 256 256">
  <rect width="256" height="256" rx="36" fill="#0c1018"/>
  <rect x="120" y="120" width="16" height="16" fill="#ffffff"/>
</svg>
EOF

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

LINUXDEPLOY_APPIMAGE="${TMP_DIR}/linuxdeploy-${APPIMAGE_ARCH}.AppImage"
curl -fL "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-${APPIMAGE_ARCH}.AppImage" -o "$LINUXDEPLOY_APPIMAGE"
chmod +x "$LINUXDEPLOY_APPIMAGE"

(
  cd "$TMP_DIR"
  APPIMAGE_EXTRACT_AND_RUN=1 "$LINUXDEPLOY_APPIMAGE" \
    --appdir "$APPDIR" \
    --desktop-file "$DESKTOP_FILE" \
    --icon-file "$ICON_FILE" \
    --output appimage
)

GENERATED_APPIMAGE="$(find "$TMP_DIR" -maxdepth 1 -type f -name '*.AppImage' ! -name 'linuxdeploy-*.AppImage' | head -n 1)"
if [[ -z "$GENERATED_APPIMAGE" ]]; then
  echo "linuxdeploy did not produce an AppImage"
  exit 1
fi

mv "$GENERATED_APPIMAGE" "dist/simplicity-engine-linux-${ARCH_LABEL}.AppImage"
chmod +x "dist/simplicity-engine-linux-${ARCH_LABEL}.AppImage"
echo "Created dist/simplicity-engine-linux-${ARCH_LABEL}.AppImage"
