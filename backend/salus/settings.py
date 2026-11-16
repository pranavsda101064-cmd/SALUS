import os
from pathlib import Path
from urllib.parse import parse_qs, unquote, urlparse

from django.core.exceptions import ImproperlyConfigured

BASE_DIR = Path(__file__).resolve().parent.parent
REPO_DIR = BASE_DIR.parent
DEV_SECRET_KEY = "salus-insecure-dev-key"
DEV_HASH_SALT = "salus-demo-salt-v1"


def load_dotenv(path):
    if not path.exists():
        return
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key and key not in os.environ:
            os.environ[key] = value


load_dotenv(REPO_DIR / ".env")


def env_bool(name, default=False):
    value = os.environ.get(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


def env_list(name, default=None):
    value = os.environ.get(name, "")
    items = [item.strip() for item in value.split(",") if item.strip()]
    return items or list(default or [])


def env_float(name, default):
    value = os.environ.get(name)
    if value is None or not value.strip():
        return default
    try:
        return float(value)
    except ValueError:
        return default


def env_int(name, default):
    value = os.environ.get(name)
    if value is None or not value.strip():
        return default
    try:
        return int(value)
    except ValueError:
        return default


DEBUG = env_bool("DJANGO_DEBUG", True)
DEMO_MODE = env_bool("SALUS_DEMO_MODE", DEBUG)
STRICT_PRODUCTION = not DEBUG and not DEMO_MODE

SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", DEV_SECRET_KEY)
if not DEBUG and SECRET_KEY == DEV_SECRET_KEY:
    raise ImproperlyConfigured(
        "DJANGO_SECRET_KEY must be set to a unique value when DJANGO_DEBUG is off."
    )

ALLOWED_HOSTS = env_list("DJANGO_ALLOWED_HOSTS", ["*"]) or ["*"]
if STRICT_PRODUCTION and ALLOWED_HOSTS == ["*"]:
    raise ImproperlyConfigured(
        "DJANGO_ALLOWED_HOSTS must list explicit hosts when debug and demo mode are off."
    )

INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    "corsheaders",
    "rest_framework",
    "rest_framework.authtoken",
    "organizations",
    "assets",
    "pii_scan",
    "data_dna",
    "events",
    "simulator",
    "lineage",
    "incidents",
    "risk_engine",
    "ai_reports",
    "anomaly_model",
    "demo",
    "api",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "common.middleware.RequestIdMiddleware",
    "whitenoise.middleware.WhiteNoiseMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "salus.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "salus.wsgi.application"

DATABASE_URL = os.environ.get("DATABASE_URL", "").strip()

if DATABASE_URL.startswith(("postgres://", "postgresql://")):
    parsed = urlparse(DATABASE_URL)
    query = parse_qs(parsed.query)
    options = {}
    if query.get("sslmode"):
        options["sslmode"] = query["sslmode"][0]
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.postgresql",
            "NAME": unquote(parsed.path.lstrip("/")),
            "USER": unquote(parsed.username or ""),
            "PASSWORD": unquote(parsed.password or ""),
            "HOST": parsed.hostname or "",
            "PORT": str(parsed.port or 5432),
            "CONN_MAX_AGE": 60,
            **({"OPTIONS": options} if options else {}),
        }
    }
else:
    DATABASES = {
        "default": {
            "ENGINE": "django.db.backends.sqlite3",
            "NAME": BASE_DIR / "db.sqlite3",
        }
    }

LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STATICFILES_STORAGE = "whitenoise.storage.CompressedManifestStaticFilesStorage"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"
AUTH_USER_MODEL = "organizations.User"

REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "rest_framework.authentication.TokenAuthentication",
        "rest_framework.authentication.SessionAuthentication",
    ],
    "DEFAULT_PERMISSION_CLASSES": [
        "rest_framework.permissions.IsAuthenticated",
    ],
    "DEFAULT_RENDERER_CLASSES": [
        "rest_framework.renderers.JSONRenderer",
        "rest_framework.renderers.BrowsableAPIRenderer",
    ],
    "DEFAULT_THROTTLE_CLASSES": [
        "rest_framework.throttling.AnonRateThrottle",
        "rest_framework.throttling.UserRateThrottle",
    ],
    "DEFAULT_THROTTLE_RATES": {
        "anon": os.environ.get("SALUS_THROTTLE_ANON", "60/min"),
        "user": os.environ.get("SALUS_THROTTLE_USER", "600/min"),
        "login": os.environ.get("SALUS_THROTTLE_LOGIN", "20/min"),
        "seed": os.environ.get("SALUS_THROTTLE_SEED", "5/min"),
        "report": os.environ.get("SALUS_THROTTLE_REPORT", "30/min"),
        "upload": os.environ.get("SALUS_THROTTLE_UPLOAD", "30/min"),
    },
    "UNAUTHENTICATED_USER": "django.contrib.auth.models.AnonymousUser",
}

CORS_ALLOWED_ORIGINS = env_list(
    "CORS_ALLOWED_ORIGINS",
    [
        "http://localhost:8080",
        "http://127.0.0.1:8080",
        "http://localhost:5000",
        "http://127.0.0.1:5000",
        "http://localhost:3000",
    ],
)
CORS_ALLOW_ALL_ORIGINS = env_bool("CORS_ALLOW_ALL_ORIGINS", DEBUG)
if STRICT_PRODUCTION and CORS_ALLOW_ALL_ORIGINS:
    raise ImproperlyConfigured(
        "CORS_ALLOW_ALL_ORIGINS must be off in production. Set CORS_ALLOWED_ORIGINS instead."
    )
CORS_ALLOW_HEADERS = [
    "accept",
    "authorization",
    "content-type",
    "origin",
    "user-agent",
    "x-csrftoken",
    "x-requested-with",
    "x-request-id",
]
CSRF_TRUSTED_ORIGINS = env_list("CSRF_TRUSTED_ORIGINS", [])

SALUS_HASH_SALT = os.environ.get("SALUS_HASH_SALT", DEV_HASH_SALT)
if not DEBUG and SALUS_HASH_SALT == DEV_HASH_SALT:
    raise ImproperlyConfigured(
        "SALUS_HASH_SALT must be set to a unique value when DJANGO_DEBUG is off."
    )
SALUS_MATCH_THRESHOLD = min(1.0, max(0.0, env_float("SALUS_MATCH_THRESHOLD", 0.3)))
GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY", "").strip()
GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash")
GEMINI_TIMEOUT = env_float("GEMINI_TIMEOUT", 8.0)
GEMINI_RETRIES = max(0, env_int("GEMINI_RETRIES", 1))

SALUS_MAX_UPLOAD_BYTES = env_int("SALUS_MAX_UPLOAD_BYTES", 15 * 1024 * 1024)
SALUS_MAX_UPLOAD_ROWS = env_int("SALUS_MAX_UPLOAD_ROWS", 50000)
SALUS_MAX_UPLOAD_COLUMNS = env_int("SALUS_MAX_UPLOAD_COLUMNS", 200)
SALUS_MAX_XLSX_UNCOMPRESSED_BYTES = env_int(
    "SALUS_MAX_XLSX_UNCOMPRESSED_BYTES", 100 * 1024 * 1024
)
SALUS_MAX_XLSX_ENTRIES = env_int("SALUS_MAX_XLSX_ENTRIES", 5000)

DATA_UPLOAD_MAX_MEMORY_SIZE = SALUS_MAX_UPLOAD_BYTES
FILE_UPLOAD_MAX_MEMORY_SIZE = SALUS_MAX_UPLOAD_BYTES
DATA_UPLOAD_MAX_NUMBER_FIELDS = 1000

SECURE_PROXY_SSL_HEADER = ("HTTP_X_FORWARDED_PROTO", "https")
SECURE_SSL_REDIRECT = env_bool("DJANGO_SECURE_SSL_REDIRECT", not DEBUG)
SECURE_REDIRECT_EXEMPT = [r"^api/v1/health/?$"]
SESSION_COOKIE_SECURE = not DEBUG
CSRF_COOKIE_SECURE = not DEBUG
SESSION_COOKIE_HTTPONLY = True
SECURE_CONTENT_TYPE_NOSNIFF = True
SECURE_REFERRER_POLICY = "same-origin"
SECURE_CROSS_ORIGIN_OPENER_POLICY = "same-origin"
X_FRAME_OPTIONS = "DENY"
if not DEBUG:
    SECURE_HSTS_SECONDS = env_int("DJANGO_HSTS_SECONDS", 31536000)
    SECURE_HSTS_INCLUDE_SUBDOMAINS = env_bool("DJANGO_HSTS_INCLUDE_SUBDOMAINS", True)
    SECURE_HSTS_PRELOAD = env_bool("DJANGO_HSTS_PRELOAD", False)
else:
    SECURE_HSTS_SECONDS = 0

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "handlers": {"console": {"class": "logging.StreamHandler"}},
    "root": {"handlers": ["console"], "level": "INFO"},
}
