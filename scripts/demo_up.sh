#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RESET="${1:-}"

echo "SALUS demo preparation"
cd "$ROOT/backend"
python manage.py migrate
if [ "$RESET" = "--reset" ]; then
  python manage.py seed_demo --reset
else
  python manage.py seed_demo
fi
cd "$ROOT"
python scripts/generate_dataset.py
python scripts/ghost_copy.py

echo
echo "Demo ready"
echo "  Login: meera@acmetraders.test"
echo "  Suspect file: demo_data/clients_export_final.csv"
echo
echo "Start the API:   cd backend && python manage.py runserver 0.0.0.0:8000"
echo "Build the site:  ./scripts/build_site.sh"
echo "Serve the build: cd frontend/dist && python -m http.server 8080"
echo "Landing:         http://localhost:8080/"
echo "App:             http://localhost:8080/app/"
