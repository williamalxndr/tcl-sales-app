import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../data/auth_repository.dart';
import '../domain/auth_session.dart';
import '../domain/user_profile.dart';

enum AuthStatus { restoring, unauthenticated, authenticated }

class AuthState {
  const AuthState({
    required this.status,
    this.user,
    this.error,
    this.isSubmitting = false,
  });

  const AuthState.restoring() : this(status: AuthStatus.restoring);

  final AuthStatus status;
  final UserProfile? user;
  final ApiException? error;
  final bool isSubmitting;

  AuthState copyWith({
    AuthStatus? status,
    UserProfile? user,
    ApiException? error,
    bool clearError = false,
    bool? isSubmitting,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: clearError ? null : error ?? this.error,
      isSubmitting: isSubmitting ?? this.isSubmitting,
    );
  }
}

class AuthController extends Notifier<AuthState> {
  AuthRepository get _repository => ref.read(authRepositoryProvider);
  ApiClient get _api => ref.read(apiClientProvider);

  @override
  AuthState build() {
    final api = _api;
    api.setUnauthorizedHandler(_refreshAfterUnauthorized);
    ref.onDispose(() => api.setUnauthorizedHandler(null));
    Future<void>.microtask(_restore);
    return const AuthState.restoring();
  }

  Future<void> _restore() async {
    try {
      final session = await _repository.restoreSession();
      state = session == null ? _signedOut() : _signedIn(session);
    } on ApiException catch (error) {
      state = AuthState(status: AuthStatus.unauthenticated, error: error);
    }
  }

  Future<void> login({required String email, required String password}) async {
    state = state.copyWith(clearError: true, isSubmitting: true);
    try {
      state = _signedIn(
        await _repository.login(email: email, password: password),
      );
    } on ApiException catch (error) {
      state = AuthState(status: AuthStatus.unauthenticated, error: error);
    } on FormatException {
      state = const AuthState(
        status: AuthStatus.unauthenticated,
        error: ApiException(
          code: 'INVALID_RESPONSE',
          message: 'Layanan mengirim data sesi yang tidak dapat diproses.',
        ),
      );
    }
  }

  Future<void> logout() async {
    state = state.copyWith(clearError: true, isSubmitting: true);
    try {
      await _repository.logout();
      state = _signedOut();
    } on ApiException catch (error) {
      // The repository always erases local credentials in its finally block.
      // Reflect that locally even if the server could not be reached.
      state = AuthState(status: AuthStatus.unauthenticated, error: error);
    }
  }

  Future<bool> _refreshAfterUnauthorized() async {
    try {
      final session = await _repository.refresh();
      if (session == null) {
        state = _signedOut();
        return false;
      }
      state = _signedIn(session);
      return true;
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.code == 'UNAUTHENTICATED') {
        state = _signedOut();
        return false;
      }
      rethrow;
    }
  }

  AuthState _signedIn(AuthSession session) =>
      AuthState(status: AuthStatus.authenticated, user: session.user);

  AuthState _signedOut() => const AuthState(status: AuthStatus.unauthenticated);
}
