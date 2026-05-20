#!/usr/bin/env bash
# Builds CleanMacPro.app from the SwiftPM release artifact.
# Usage: ./Tools/build-app.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/.build/release/CleanMacPro"
ICON="$ROOT/Tools/AppIcon.icns"
PLIST="$ROOT/Tools/Info.plist"
APP="$ROOT/build/CleanMac Pro.app"

if [[ ! -f "$BIN" ]]; then
    echo "Release binary missing — run: swift build -c release"
    exit 1
fi
if [[ ! -f "$ICON" ]]; then
    echo "Icon missing — run: swift Tools/render-icon.swift Tools/AppIcon.iconset && iconutil -c icns Tools/AppIcon.iconset -o Tools/AppIcon.icns"
    exit 1
fi

echo "Assembling $APP …"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

cp "$BIN"   "$APP/Contents/MacOS/CleanMacPro"
cp "$ICON"  "$APP/Contents/Resources/AppIcon.icns"
cp "$PLIST" "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/CleanMacPro"

# Ad-hoc sign so Gatekeeper lets us run it locally
codesign --force --deep --sign - "$APP" 2>&1 | grep -v "replacing existing" || true

echo "✓ Built: $APP"
echo "  Size:  $(du -sh "$APP" | cut -f1)"
