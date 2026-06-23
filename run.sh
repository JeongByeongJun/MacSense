#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

if [ -f .env ]; then
  set -a
  source .env
  set +a
fi

if [ ! -x build/macsense ]; then
  ./build.sh
fi

./build/macsense
