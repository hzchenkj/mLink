#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="mLink"
PRODUCT_NAME="mlink"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/${APP_NAME}.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_BASENAME="AppIcon"
ICON_FILE="${ICON_BASENAME}.icns"

BUNDLE_ID="${BUNDLE_ID:-com.duobao.mlink}"
APP_VERSION="${APP_VERSION:-1.0.0}"
BUILD_VERSION="${BUILD_VERSION:-1}"
MIN_SYSTEM_VERSION="${MIN_SYSTEM_VERSION:-13.0}"
BUILD_TIME="$(date "+%Y-%m-%d %H:%M:%S %z")"

printf '[1/6] Building release binary...\n'
swift build -c release --package-path "$ROOT_DIR"

BIN_DIR="$(swift build -c release --show-bin-path --package-path "$ROOT_DIR")"
BIN_PATH="$BIN_DIR/$PRODUCT_NAME"

if [[ ! -x "$BIN_PATH" ]]; then
  printf 'Error: executable not found at %s\n' "$BIN_PATH" >&2
  exit 1
fi

printf '[2/6] Preparing app bundle...\n'
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

printf '[3/6] Copying executable...\n'
cp "$BIN_PATH" "$MACOS_DIR/$PRODUCT_NAME"
chmod +x "$MACOS_DIR/$PRODUCT_NAME"

printf '[4/6] Generating app icon...\n'
"$ROOT_DIR/scripts/generate_mcdonalds_icon.swift" "$RESOURCES_DIR/$ICON_FILE"

printf '[5/6] Writing bundle metadata...\n'
cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${PRODUCT_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleIconFile</key>
  <string>${ICON_BASENAME}</string>
  <key>CFBundleIconFiles</key>
  <array>
    <string>${ICON_FILE}</string>
    <string>${ICON_BASENAME}</string>
  </array>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${APP_VERSION}</string>
  <key>CFBundleVersion</key>
  <string>${BUILD_VERSION}</string>
  <key>MLinkBuildTime</key>
  <string>${BUILD_TIME}</string>
  <key>LSMinimumSystemVersion</key>
  <string>${MIN_SYSTEM_VERSION}</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "APPL????" > "$CONTENTS_DIR/PkgInfo"

printf '[6/6] Ad-hoc signing (optional)...\n'
if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_DIR" >/dev/null 2>&1 || true
fi

printf '\nDone. App bundle: %s\n' "$APP_DIR"
printf 'Run: open "%s"\n' "$APP_DIR"
