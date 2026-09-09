import 'package:flutter/foundation.dart';

import '../../../core/network/api_client.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/session/session_store.dart';
import '../domain/auth_session.dart';

class AuthRepository {
  AuthRepository({
    required ApiClient api,
    required SessionStore sessionStore,
    bool? isWeb,
  }) : _api = api,
       _sessionStore = sessionStore,
       _isWeb = isWeb ?? kIsWeb;

  final ApiClient _api;
  final SessionStore _sessionStore;
  final bool _isWeb;

  Future<AuthSession> login({
    required String email,
    required String password,
  }) async {
    if (_isWeb) await _bootstrapCsrf();
    final data = await _api.postObject(
      'auth/login',
      body: {
        'email': email.trim(),
        'password': password,
        'clientType': _isWeb ? 'web' : 'native',
      },
      authenticated: false,
      retryUnauthorized: false,
    );
    return _accept(AuthSession.fromJson(data));
  }

  /// Restores the session after launch. A missing or expired refresh credential
  /// means the caller should show Login, rather than treating it as an error.
  Future<AuthSession?> restoreSession() async {
    try {
      if (_isWeb) {
        await _bootstrapCsrf();
      } else if (await _sessionStore.readRefreshToken() == null) {
        return null;
      }
      return await refresh();
    } on ApiException catch (error) {
      if (error.statusCode == 401 || error.code == 'UNAUTHENTICATED') {
        await _clearLocalSession();
        return null;
      }
      rethrow;
    }
  }

  /// Called once by [ApiClient] for a burst of expired-token responses.
  Future<AuthSession?> refresh() async {
    if (_isWeb && _currentCsrf == null) await _bootstrapCsrf();
    final refreshToken = _isWeb ? null : await _sessionStore.readRefreshToken();
    if (!_isWeb && refreshToken == null) return null;
    final data = await _api.postObject(
      'auth/refresh',
      body: {
        ...?(refreshToken == null ? null : {'refreshToken': refreshToken}),
      },
      authenticated: false,
      retryUnauthorized: false,
    );
    return _accept(AuthSession.fromJson(data));
  }

  Future<void> logout() async {
    try {
      if (_isWeb && _currentCsrf == null) await _bootstrapCsrf();
      final refreshToken = _isWeb
          ? null
          : await _sessionStore.readRefreshToken();
      if (_isWeb || refreshToken != null) {
        await _api.postObject(
          'auth/logout',
          body: {
            ...?(refreshToken == null ? null : {'refreshToken': refreshToken}),
          },
          authenticated: false,
          retryUnauthorized: false,
        );
      }
    } on ApiException catch (error) {
      // A stale refresh credential is already unusable. The local application
      // must still return to Login; other failures remain observable to callers.
      if (error.statusCode != 401) rethrow;
    } finally {
      await _clearLocalSession();
    }
  }

  String? _currentCsrf;

  Future<void> _bootstrapCsrf() async {
    final data = await _api.getObject(
      'auth/csrf',
      authenticated: false,
      retryUnauthorized: false,
    );
    final token = data['csrfToken'];
    if (token is! String || token.isEmpty) {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'Layanan tidak mengirim token keamanan yang valid.',
      );
    }
    _currentCsrf = token;
    _api.configureSession(csrfToken: token);
  }

  Future<AuthSession> _accept(AuthSession session) async {
    if (_isWeb) {
      _currentCsrf = session.csrfToken ?? _currentCsrf;
    } else {
      final refreshToken = session.refreshToken;
      if (refreshToken == null || refreshToken.isEmpty) {
        throw const ApiException(
          code: 'INVALID_RESPONSE',
          message: 'Layanan tidak mengirim kredensial sesi yang valid.',
        );
      }
      await _sessionStore.writeRefreshToken(refreshToken);
    }
    _api.configureSession(
      accessToken: session.accessToken,
      csrfToken: _currentCsrf,
    );
    return session;
  }

  Future<void> _clearLocalSession() async {
    _currentCsrf = null;
    _api.clearSession();
    await _sessionStore.clear();
  }
}
