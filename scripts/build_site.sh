#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FRONTEND="$ROOT/frontend"
LANDING="$FRONTEND/landing"
DIST="$FRONTEND/dist"
API_BASE="${API_BASE:-http://localhost:8000}"

cd "$FRONTEND"
flutter build web --release --base-href /app/ --dart-define=API_BASE="$API_BASE"

rm -rf "$DIST"
mkdir -p "$DIST/app"
cp -R build/web/. "$DIST/app/"
cp "$LANDING/index.html" "$LANDING/styles.css" "$LANDING/app.js" "$DIST/"
cp "$LANDING/simulation.css" "$LANDING/simulation.js" "$LANDING/simulation-data.json" "$DIST/"
cp "$LANDING/privacy.html" "$LANDING/terms.html" "$LANDING/404.html" "$DIST/"
cp "$LANDING/robots.txt" "$LANDING/sitemap.xml" "$DIST/"
cp "$LANDING/favicon.svg" "$LANDING/favicon-32.png" "$LANDING/favicon-192.png" "$LANDING/favicon-512.png" "$LANDING/apple-touch-icon.png" "$LANDING/og-image.png" "$DIST/"
cp -R "$LANDING/assets" "$DIST/assets"

sed -i "s|__SALUS_API_BASE__|$API_BASE|g" "$DIST/index.html"

echo "SALUS site built at $DIST"
echo "Landing: http://localhost:8080/"
echo "App: http://localhost:8080/app/"
