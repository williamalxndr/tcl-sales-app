# Flutter client

See the [repository README](../README.md) for setup, platforms, API configuration and checks.

The shared code uses `lib/core` for environment/HTTP concerns and `lib/features/<feature>/data` and `presentation` for repositories and widgets. Service availability is the first wired feature; the business screens are not implemented yet.

The generated platform projects target Android, iOS, web, Windows, macOS and Linux. Keep `pubspec.lock` committed. Native build prerequisites and signing requirements are platform-specific.
