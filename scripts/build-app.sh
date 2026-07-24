#!/usr/bin/env bash
#
# Builds AudioPicker in release mode and assembles a proper .app bundle,
# then ad-hoc code signs it so launch-at-login (SMAppService) works.
#
set -euo pipefail

APP_NAME="AudioPicker"
BUNDLE_ID="com.craigstacey.audiopicker"

# Resolve project root (this script lives in <root>/scripts).
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

BUILD_DIR="$ROOT/.build/release"
APP_DIR="$ROOT/dist/${APP_NAME}.app"
CONTENTS="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS/MacOS"

echo "==> Building ${APP_NAME} (release)…"
swift build -c release

echo "==> Assembling ${APP_NAME}.app…"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$CONTENTS/Resources"

cp "$BUILD_DIR/${APP_NAME}" "$MACOS_DIR/${APP_NAME}"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"

echo "==> Ad-hoc code signing…"
codesign --force --deep --sign - "$APP_DIR"

echo "==> Verifying signature…"
codesign -dv "$APP_DIR" 2>&1 | sed 's/^/    /'

echo ""
echo "Done: $APP_DIR"
echo "Run it with:   open \"$APP_DIR\""
echo "Install it:    make install   (copies to /Applications)"
