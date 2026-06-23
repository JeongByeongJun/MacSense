#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
APP_DIR="build/MacSense.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
rm -f build/macsense build/shortcuts.json

swiftc \
  src/*.swift \
  -o "$MACOS_DIR/MacSense" \
  -framework Cocoa \
  -framework ApplicationServices \
  -framework UserNotifications \
  -lsqlite3

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>MacSense</string>
  <key>CFBundleIdentifier</key>
  <string>app.macsense.demo</string>
  <key>CFBundleName</key>
  <string>MacSense</string>
  <key>CFBundleDisplayName</key>
  <string>MacSense</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
</dict>
</plist>
PLIST

cp resources/shortcuts.json "$MACOS_DIR/shortcuts.json"
cp resources/shortcuts.json "$RESOURCES_DIR/shortcuts.json"

codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "✅ Built: $APP_DIR"
