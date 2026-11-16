#!/usr/bin/env bash
set -euo pipefail

if ! command -v flutter >/dev/null 2>&1; then
  FLUTTER_HOME="${HOME}/flutter-sdk"
  if [ ! -d "$FLUTTER_HOME" ]; then
    git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$FLUTTER_HOME"
  fi
  export PATH="$FLUTTER_HOME/bin:$PATH"
  git config --global --add safe.directory "$FLUTTER_HOME" || true
fi

API_BASE="${API_BASE:-https://salus-api.onrender.com}"
DIST="$(pwd)/dist"

flutter config --enable-web >/dev/null
flutter pub get
flutter build web --release --base-href /app/ --dart-define=API_BASE="$API_BASE"

rm -rf "$DIST"
mkdir -p "$DIST/app"
cp -R build/web/. "$DIST/app/"
cp landing/index.html landing/styles.css landing/app.js "$DIST/"
cp landing/simulation.css landing/simulation.js landing/simulation-data.json "$DIST/"
cp landing/privacy.html landing/terms.html landing/404.html "$DIST/"
cp landing/robots.txt landing/sitemap.xml "$DIST/"
cp landing/favicon.svg landing/favicon-32.png landing/favicon-192.png landing/favicon-512.png landing/apple-touch-icon.png landing/og-image.png "$DIST/"
cp -R landing/assets "$DIST/assets"

sed -i "s|__SALUS_API_BASE__|$API_BASE|g" "$DIST/index.html"

echo "SALUS site built at $DIST"
echo "Landing: /"
echo "App: /app/"
