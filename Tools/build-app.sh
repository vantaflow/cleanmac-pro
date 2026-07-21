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

# Prefer a STABLE self-signed identity (see make-signing-cert.sh) so TCC
# permissions persist across rebuilds. Fall back to ad-hoc if it's not set up.
SIGN_ID="CleanMac Pro Dev"
if security find-identity -p codesigning 2>/dev/null | grep -q "$SIGN_ID"; then
    echo "Signing with stable identity: $SIGN_ID"
    codesign --force --deep --options runtime --sign "$SIGN_ID" "$APP" \
        2>&1 | grep -v "replacing existing" || true
else
    echo "No stable identity — ad-hoc signing (TCC will re-prompt after each rebuild)."
    echo "  Run ./Tools/make-signing-cert.sh once to fix this."
    codesign --force --deep --sign - "$APP" 2>&1 | grep -v "replacing existing" || true
fi

echo "✓ Built: $APP"
echo "  Size:  $(du -sh "$APP" | cut -f1)"
