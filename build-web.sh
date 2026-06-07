#!/usr/bin/env bash
# Build the LifeOnDeck Flutter web app as an installable PWA.
#
# Two phases:
#   1. flutter build web (--pwa-strategy=none disables Flutter's own SW so it
#      does not conflict with the Workbox one).
#   2. workbox-cli generateSW produces build/web/sw.js + precache manifest.
#
# Usage:
#   ./build-web.sh [API_BASE_URL]
#
# API_BASE_URL defaults to the production host below; pass an argument to
# override (e.g. a staging host).
set -euo pipefail

API_BASE_URL="${1:-https://api.dominio.tld/api/v1}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> flutter build web (API_BASE_URL=$API_BASE_URL)"
flutter build web --release \
  --pwa-strategy=none \
  --dart-define=API_BASE_URL="$API_BASE_URL"

echo "==> workbox generateSW"
cd web-build-tools
if [ ! -d node_modules ]; then
  echo "    node_modules missing — running npm install"
  npm install
fi
npx workbox-cli generateSW workbox-config.cjs

echo "==> Done. Output: $SCRIPT_DIR/build/web/"
