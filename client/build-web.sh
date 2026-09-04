#!/usr/bin/env bash
# Build the LifeOnDeck Flutter web app as an installable PWA.
#
# Two phases:
#   1. flutter build web (--pwa-strategy=none disables Flutter's own SW so it
#      does not conflict with the Workbox one registered by web/index.html).
#   2. workbox-cli generateSW produces build/web/sw.js + precache manifest.
#
# Usage:
#   ./build-web.sh [API_BASE_URL] [BASE_HREF]
#
# The app is served from the root of its own host (https://lifeondeck.gmarra.it),
# so both default to root-relative values; pass arguments to override (e.g. a
# staging host, or a sub-path deployment).
set -euo pipefail

API_BASE_URL="${1:-/api/v1}"
BASE_HREF="${2:-/}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> flutter build web (API_BASE_URL=$API_BASE_URL, base-href=$BASE_HREF)"
flutter build web --release \
  --pwa-strategy=none \
  --base-href "$BASE_HREF" \
  --dart-define=API_BASE_URL="$API_BASE_URL"

# --pwa-strategy=none does not emit flutter_service_worker.js, but a previous
# build without the flag leaves one behind; drop it so Workbox neither precaches
# it nor competes with it.
rm -f build/web/flutter_service_worker.js

echo "==> workbox generateSW"
cd web-build-tools
if [ ! -d node_modules ]; then
  echo "    node_modules missing — running npm install"
  npm install
fi
npx workbox-cli generateSW workbox-config.cjs

echo "==> Done. Output: $SCRIPT_DIR/build/web/"
