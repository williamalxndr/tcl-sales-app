import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import '../network/api_client.dart';
import '../session/session_store.dart';
import '../../features/authentication/application/auth_controller.dart';
import '../../features/authentication/data/auth_repository.dart';
import '../../features/service_status/data/service_status_repository.dart';

/// The environment is selected once in main and explicitly overridden in tests.
final appConfigProvider = Provider<AppConfig>((_) {
  throw StateError('AppConfig must be supplied by the application root.');
});

/// Shared ownership prevents widgets from constructing or leaking HTTP clients.
final apiClientProvider = Provider<ApiClient>((ref) {
  final client = ApiClient(baseUrl: ref.watch(appConfigProvider).apiBaseUrl);
  ref.onDispose(client.close);
  return client;
});

final sessionStoreProvider = Provider<SessionStore>(
  (ref) => createSessionStore(),
);

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    api: ref.watch(apiClientProvider),
    sessionStore: ref.watch(sessionStoreProvider),
  );
});

final authControllerProvider = NotifierProvider<AuthController, AuthState>(
  AuthController.new,
);

final serviceStatusRepositoryProvider = Provider<ServiceStatusRepository>((
  ref,
) {
  return ServiceStatusRepository(ref.watch(apiClientProvider));
});
