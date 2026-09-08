import os
from pathlib import Path

from corsheaders.defaults import default_headers
from django.core.exceptions import ImproperlyConfigured
from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parent.parent
load_dotenv(BASE_DIR.parent / ".env", override=False)


def required(name):
    value = os.environ.get(name, "")
    if not value:
        raise ImproperlyConfigured(f"Set {name} in the environment.")
    return value


def csv(name, default=""):
    return [value.strip() for value in os.environ.get(name, default).split(",") if value.strip()]


SECRET_KEY = required("DJANGO_SECRET_KEY")
DEBUG = os.environ.get("DJANGO_DEBUG", "false").lower() == "true"
if not DEBUG and (SECRET_KEY.startswith("local-") or len(SECRET_KEY) < 50):
    raise ImproperlyConfigured("Use a strong, unique DJANGO_SECRET_KEY outside development.")
ALLOWED_HOSTS = csv("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1")

INSTALLED_APPS = [
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "rest_framework",
    "corsheaders",
    "apps.accounts",
    "apps.core",
]
MIDDLEWARE = [
    "apps.core.middleware.RequestIdMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]
ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"
APPEND_SLASH = False

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.mysql",
        "NAME": required("MYSQL_DATABASE"),
        "USER": required("MYSQL_USER"),
        "PASSWORD": required("MYSQL_PASSWORD"),
        "HOST": os.environ.get("MYSQL_HOST", "127.0.0.1"),
        "PORT": os.environ.get("MYSQL_PORT", "3306"),
        "CONN_MAX_AGE": 0,
        "OPTIONS": {
            "charset": "utf8mb4",
            "isolation_level": "read committed",
            "init_command": "SET sql_mode='STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_ENGINE_SUBSTITUTION'",
        },
        "TEST": {"NAME": "test_" + required("MYSQL_DATABASE")},
    }
}
AUTH_USER_MODEL = "accounts.User"
PASSWORD_HASHERS = [
    "django.contrib.auth.hashers.Argon2PasswordHasher",
    "django.contrib.auth.hashers.PBKDF2PasswordHasher",
]
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator", "OPTIONS": {"min_length": 15}},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]
LANGUAGE_CODE = "en-us"
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

REST_FRAMEWORK = {
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    # No implicit Basic/Session authentication for the API. Token + browser
    # session contracts must be implemented explicitly before business routes.
    "DEFAULT_AUTHENTICATION_CLASSES": [],
    "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"],
    "DEFAULT_PARSER_CLASSES": ["rest_framework.parsers.JSONParser"],
    "EXCEPTION_HANDLER": "apps.core.api.exception_handler",
}
CORS_ALLOWED_ORIGINS = csv("CORS_ALLOWED_ORIGINS")
CORS_URLS_REGEX = r"^/api/v1/.*$"
CORS_ALLOW_CREDENTIALS = False
CORS_ALLOW_HEADERS = [*default_headers, "idempotency-key", "if-match", "x-request-id"]
CORS_EXPOSE_HEADERS = ["ETag", "Location", "X-Request-Id", "Retry-After"]
SESSION_COOKIE_SECURE = not DEBUG
SESSION_COOKIE_HTTPONLY = True
SESSION_COOKIE_SAMESITE = "Lax"
CSRF_COOKIE_SECURE = not DEBUG
SECURE_CONTENT_TYPE_NOSNIFF = True
X_FRAME_OPTIONS = "DENY"
DATA_UPLOAD_MAX_MEMORY_SIZE = 1024 * 1024
