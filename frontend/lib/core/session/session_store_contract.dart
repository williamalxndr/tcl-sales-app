abstract interface class SessionStore {
  Future<String?> readRefreshToken();

  Future<void> writeRefreshToken(String token);

  Future<void> clear();
}

/// Test double and an intentionally ephemeral store for browser builds.
class MemorySessionStore implements SessionStore {
  String? _token;

  @override
  Future<void> clear() async => _token = null;

  @override
  Future<String?> readRefreshToken() async => _token;

  @override
  Future<void> writeRefreshToken(String token) async => _token = token;
}
