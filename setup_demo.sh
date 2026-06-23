#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

./build.sh

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

if [ -n "${GROQ_API_KEY:-}" ]; then
  launchctl setenv GROQ_API_KEY "$GROQ_API_KEY"
fi

echo ""
echo "MacSense demo setup"
echo "1. System Settings windows will open."
echo "2. Add or enable: $(pwd)/build/MacSense.app"
echo "3. Required: Accessibility, Input Monitoring, Notifications."
echo ""

open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility" || true
sleep 1
open "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent" || true
sleep 1
open "x-apple.systempreferences:com.apple.Notifications-Settings.extension" || true

echo ""
echo "After toggles are enabled, run:"
echo "  ./run.sh"
