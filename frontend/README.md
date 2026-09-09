# Flutter client

See the [repository README](../README.md) for setup, platforms, API configuration and checks.

The app uses Riverpod for state/dependency injection and GoRouter for app navigation. The composition root is `lib/main.dart`; shared runtime dependencies are declared in `lib/core/di`, routes in `lib/app/router`, and product code in `lib/features/<feature>`. See [the Flutter architecture decision](../docs/FLUTTER_ARCHITECTURE.md) before adding a feature.

Service availability is the first wired feature; Authentication, Program Submission, and Backoffice screens are implemented in subsequent milestones.

The generated platform projects target Android, iOS, web, Windows, macOS and Linux. Keep `pubspec.lock` committed. Native build prerequisites and signing requirements are platform-specific.
