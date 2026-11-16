FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    DJANGO_DEBUG=0 \
    SALUS_DEMO_MODE=1 \
    SALUS_SEED_ON_START=1 \
    GUNICORN_WORKERS=1

WORKDIR /app

RUN apt-get update \
    && apt-get install -y --no-install-recommends libgomp1 \
    && rm -rf /var/lib/apt/lists/* \
    && groupadd --system salus \
    && useradd --system --gid salus --home-dir /app salus

COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
RUN mkdir -p staticfiles \
    && DJANGO_DEBUG=1 python manage.py collectstatic --noinput \
    && chmod +x start.sh \
    && chown -R salus:salus /app

USER salus

EXPOSE 8000

HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
    CMD python -c "import os,urllib.request; urllib.request.urlopen('http://127.0.0.1:' + os.environ.get('PORT','8000') + '/api/v1/health', timeout=4)"

CMD ["sh", "start.sh"]
