import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'session_store_contract.dart';

const _refreshTokenKey = 'sales_refresh_token';

class NativeSessionStore implements SessionStore {
  NativeSessionStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<void> clear() => _storage.delete(key: _refreshTokenKey);

  @override
  Future<String?> readRefreshToken() => _storage.read(key: _refreshTokenKey);

  @override
  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);
}

SessionStore createSessionStore() => NativeSessionStore();
