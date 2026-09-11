# Flutter client

See the [repository README](../README.md) for setup, platforms, API configuration and checks.

The app uses Riverpod for state/dependency injection and GoRouter for app navigation. The composition root is `lib/main.dart`; shared runtime dependencies are declared in `lib/core/di`, routes in `lib/app/router`, and product code in `lib/features/<feature>`. See [the Flutter architecture decision](../docs/FLUTTER_ARCHITECTURE.md) before adding a feature.

Authentication is wired end to end: Login, native secure refresh-token storage, web HttpOnly-cookie/CSRF refresh, session restoration, guarded routes, logout, and the signed-in identity shell. Program Submission and Backoffice screens follow in later milestones.

The client sends credentials on Flutter web so the backend can use its HttpOnly `sales_refresh` cookie. Configure the backend's `CORS_ALLOWED_ORIGINS` and `CSRF_TRUSTED_ORIGINS` for the web origin. Do not put tokens into browser LocalStorage.

The generated platform projects target Android, iOS, web, Windows, macOS and Linux. Keep `pubspec.lock` committed. Native build prerequisites and signing requirements are platform-specific.

## API integration test

The draft-to-approval test is opt-in because it creates an approved program in the configured test environment. Supply a submitter whose assigned checker matches `TEST_CHECKER_EMAIL`, plus one eligible acknowledger and approver:

```sh
flutter test integration_test/draft_to_approve_test.dart \
  --dart-define=TEST_API_BASE_URL=https://test-api.example.com/api/v1 \
  --dart-define=TEST_SUBMITTER_EMAIL=submitter@example.com \
  --dart-define=TEST_SUBMITTER_PASSWORD=... \
  --dart-define=TEST_CHECKER_EMAIL=checker@example.com \
  --dart-define=TEST_CHECKER_PASSWORD=... \
  --dart-define=TEST_ACKNOWLEDGER_EMAIL=acknowledger@example.com \
  --dart-define=TEST_ACKNOWLEDGER_PASSWORD=... \
  --dart-define=TEST_APPROVER_EMAIL=approver@example.com \
  --dart-define=TEST_APPROVER_PASSWORD=...
```

Never target production or commit test credentials. Without the defines, the test is reported as skipped.
