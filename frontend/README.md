# Flutter client

See the [repository README](../README.md) for setup, platforms, API configuration and checks.

The app uses Riverpod for state/dependency injection and GoRouter for app navigation. The composition root is `lib/main.dart`; shared runtime dependencies are declared in `lib/core/di`, routes in `lib/app/router`, and product code in `lib/features/<feature>`. See [the Flutter architecture decision](../docs/FLUTTER_ARCHITECTURE.md) before adding a feature.

Authentication is wired end to end: Login, native secure refresh-token storage, web HttpOnly-cookie/CSRF refresh, session restoration, guarded routes, logout, and the signed-in identity shell. Program Submission and Backoffice screens follow in later milestones.

The client sends credentials on Flutter web so the backend can use its HttpOnly `sales_refresh` cookie. Configure the backend's `CORS_ALLOWED_ORIGINS` and `CSRF_TRUSTED_ORIGINS` for the web origin. Do not put tokens into browser LocalStorage.

The generated platform projects target Android, iOS, web, Windows, macOS and Linux. Keep `pubspec.lock` committed. Native build prerequisites and signing requirements are platform-specific.
