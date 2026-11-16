#!/bin/sh
set -eu

python manage.py migrate --noinput

if [ "${SALUS_DEMO_MODE:-0}" = "1" ] && [ "${SALUS_SEED_ON_START:-1}" = "1" ]; then
  python manage.py seed_demo
fi

exec gunicorn salus.wsgi:application --config gunicorn.conf.py
