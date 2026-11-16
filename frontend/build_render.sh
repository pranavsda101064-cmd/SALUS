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

flutter config --enable-web >/dev/null
flutter pub get
flutter build web --release --dart-define=API_BASE="${API_BASE:-https://salus-api.onrender.com}"
