#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
mkdir -p build

swiftc \
  src/*.swift \
  -o build/macsense \
  -framework Cocoa \
  -framework ApplicationServices \
  -lsqlite3

cp resources/shortcuts.json build/shortcuts.json

echo "✅ Built: build/macsense"
