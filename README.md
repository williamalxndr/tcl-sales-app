# Sales App

Flutter for Android, iOS, web, Windows, macOS and Linux; Django REST Framework for the API; MySQL 8.4 for storage.

The DRF/MySQL backend now implements login, drafts, sequential approvals, rejection, private uploads, signed PDFs and completed-review history. The Flutter launch screen remains the existing service-status shell. Follow [backend setup and employee provisioning](docs/BACKEND.md); cancellation remains gated until its allowed states are confirmed.

## Repository

```text
frontend/                 Flutter app and six platform projects
  lib/core/               Environment configuration and shared HTTP client
  lib/features/           Feature repositories and presentation
backend/                  Django 5.2 LTS + DRF, Python 3.12
  config/                 Settings, URLs, ASGI/WSGI entrypoints
  apps/accounts/          Employee identities, roles, signatures and sessions
  apps/core/              Envelopes, audit, idempotency, throttling and health checks
  apps/programs/          MySQL models, scoped APIs and workflow/file services
infra/mysql/              Development test-database initialization
compose.yaml              Isolated backend + MySQL development services
docs/API_DESIGN.md        Implemented business contract and open questions
docs/openapi.yaml         All 30 implemented API operations
docs/foundation.openapi.yaml  Compatible health-only API subset
docs/ARCHITECTURE.md      Boundaries, decisions and implementation status
docs/BACKEND.md           Setup, provisioning, policy and scanner operation
.github/workflows/ci.yml  Backend/MySQL and Flutter checks
```

`repo/docs/` is the version-controlled documentation source going forward. The earlier parent workspace `docs/` files are the initial design snapshot, and `../ui-mockup/` contains the original designs. Neither is required to build this repository.

## Start locally

Install Docker Desktop/Compose and Flutter 3.38.3 (the SDK used for this scaffold; Dart 3.10.1). Run these commands from this repository root:

```sh
cp .env.example .env
# Edit .env if your local ports differ; do not overwrite an existing .env.
docker compose up -d --build --wait mysql
docker compose build backend
docker compose run --rm backend python manage.py migrate --noinput
docker compose run --rm backend python manage.py configure_workflow
docker compose run --rm backend python manage.py seed_master_data
docker compose up -d --wait backend
docker compose --profile uploads up -d clamav attachment-scanner
```

Then run Flutter web in a separate terminal:

```sh
cd frontend
flutter pub get
flutter run -d chrome --web-port=3000 --dart-define=API_BASE_URL=http://localhost:8000/api/v1
```

The screen should show **Service connected**. Health endpoints:

```sh
curl http://localhost:8000/api/v1/health/live
curl http://localhost:8000/api/v1/health/ready
```

`live` checks the application process; `ready` actually queries MySQL, returning 503 when unavailable. Readiness does not check pending migrations, so apply migrations explicitly before starting the app. API URLs do not end in a slash. `.env.example` credentials are local examples only; `.env` is ignored. MySQL persists in the project-specific `mysql_data` volume. Backend and database ports bind to loopback by default; this stack is not a production deployment.

```sh
docker compose logs -f backend
docker compose down
```

`down` preserves MySQL data. Avoid adding `--volumes` unless you intend to erase that local database. Initialization SQL runs only on the first empty-volume startup. Changing database credentials in `.env` does not change existing MySQL users. If changing MYSQL_DATABASE/MYSQL_USER, update the test database initialization SQL too; the defaults are `sales` / `test_sales` with the `sales` user.

## Platforms and API addresses

| Target | Run command (inside frontend) | Development API address |
| --- | --- | --- |
| Web | `flutter run -d chrome --web-port=3000` | `http://localhost:8000/api/v1` |
| Android emulator | `flutter run -d <emulator-id>` | `http://10.0.2.2:8000/api/v1` (automatic Android debug default) |
| iOS simulator | `flutter run -d <simulator-id>` | localhost if permitted by local transport policy; otherwise HTTPS development endpoint |
| macOS | `flutter run -d macos` | localhost or HTTPS development endpoint |
| Windows | `flutter run -d windows` | localhost on that Windows host |
| Linux | `flutter run -d linux` | localhost on that Linux host |
| Physical phone/tablet | `flutter run -d <device-id> --dart-define=API_BASE_URL=https://<dev-api-host>/api/v1` | Reachable development server, never the phone’s localhost |

Use `flutter devices` for IDs. One Flutter application covers supported phone, tablet, browser and desktop targets; it does not imply support for every OS version, watch, TV or embedded device. Flutter lists its supported targets in the [platform documentation](https://docs.flutter.dev/reference/supported-platforms).

For trusted local LAN development, set `API_BIND_HOST=0.0.0.0`, add the computer’s LAN IP to `DJANGO_ALLOWED_HOSTS`, and use that address in `API_BASE_URL`. Android debug permits HTTP; release does not. Apple transport/local-network permissions may require a narrowly scoped development exception or a trusted HTTPS endpoint. Broad Apple transport-security exceptions have not been enabled. Web origins are allowlisted with `CORS_ALLOWED_ORIGINS`; the example uses port 3000. An HTTPS web page must call an HTTPS API. `API_BASE_URL` is public compiled configuration, never a place for secrets.

Platform build requirements:

- Android: Android SDK command-line tools and accepted SDK licenses.
- iOS/macOS: macOS with full Xcode and any required CocoaPods/plugin tooling; iOS distribution also needs signing.
- Windows: Windows with Visual Studio C++ desktop tooling.
- Linux: Linux with the Flutter desktop build dependencies (including GTK development headers).

At scaffold verification, this Mac had Chrome and Flutter available, but Android command-line tools/licenses and full Xcode/CocoaPods were incomplete. Native project generation is complete; those native binaries have not been built here. See Flutter’s [platform setup](https://docs.flutter.dev/platform-integration) for host-specific requirements. `com.totalchemindo.sales_app`-derived identifiers are placeholders; confirm release IDs/signing before store distribution.

## Checks

Backend tests use **real MySQL**, never SQLite. The local MySQL initializer gives the development user access to the separate `test_sales` database, not global database administration.

```sh
docker compose run --rm backend python manage.py check
docker compose run --rm backend python manage.py makemigrations --check --dry-run
docker compose run --rm backend python manage.py test --keepdb
```

```sh
cd frontend
dart format --output=none --set-exit-if-changed lib test tool
flutter analyze
flutter test
dart run tool/check_api.dart
flutter build web --dart-define=API_BASE_URL=https://api.example.com/api/v1
```

The smoke script requires the local backend to be running and calls it through the app's actual HTTP service/repository. The last command is a compilation check with an example URL. Replace it with a real HTTPS API URL before distributing a build. Release configuration rejects a missing or non-HTTPS API URL. CI repeats backend/MySQL tests, migration checks, Flutter analysis/tests and web compilation. Native builds must run on their matching hosts.

## Backend development

Docker supplies Python and the native mysqlclient libraries. Direct host development is optional: install Python 3.12 and mysqlclient build prerequisites, create a virtual environment, install `backend/requirements.txt`, and override `MYSQL_HOST=127.0.0.1 MYSQL_PORT=3307` while using the Compose MySQL instance. Settings load the root `.env` without overriding exported variables.

Backend direct dependencies are pinned in requirements.txt; frontend resolution is committed in pubspec.lock. Upgrade dependencies deliberately and rerun the checks. Django 5.2 LTS is chosen for a stable backend baseline; Django documents the [MySQL adapter and strict-mode requirements](https://docs.djangoproject.com/en/5.2/ref/databases/#mysql-notes).

Employees are provisioned with the trusted `provision_employee` management command described in [BACKEND.md](docs/BACKEND.md). Login issues rotating opaque sessions; roles and assignment scope are checked per request. No public signup/admin/account-management endpoint is exposed. Django `is_staff`/`is_superuser` flags do not grant Backoffice access.
