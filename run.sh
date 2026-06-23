#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

if [ ! -x build/MacSense.app/Contents/MacOS/MacSense ]; then
  ./build.sh
fi

if [ -n "${GROQ_API_KEY:-}" ]; then
  launchctl setenv GROQ_API_KEY "$GROQ_API_KEY"
fi

pkill -x MacSense 2>/dev/null || true
rm -f "$HOME/Library/Application Support/MacSense/events.db"

exec build/MacSense.app/Contents/MacOS/MacSense
