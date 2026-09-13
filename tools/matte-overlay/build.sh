#!/bin/bash
set -euo pipefail
source_dir="$(cd "$(dirname "$0")" && pwd)"
app_dir="$source_dir/../../build/Matte Overlay.app"
mkdir -p "$app_dir/Contents/MacOS"
xcrun swiftc "$source_dir/MatteOverlay.swift" -O -framework AppKit -o "$app_dir/Contents/MacOS/MatteOverlay"
cat > "$app_dir/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>MatteOverlay</string>
<key>CFBundleIdentifier</key><string>local.shane.matte-overlay</string>
<key>CFBundleName</key><string>Matte Overlay</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign --force --sign - "$app_dir"
printf 'Built %s\n' "$app_dir"
