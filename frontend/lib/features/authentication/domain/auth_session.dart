import 'user_profile.dart';

class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.expiresIn,
    required this.refreshExpiresAt,
    required this.sessionId,
    required this.user,
    this.refreshToken,
    this.csrfToken,
  });

  final String accessToken;
  final int expiresIn;
  final DateTime refreshExpiresAt;
  final String sessionId;
  final UserProfile user;
  final String? refreshToken;
  final String? csrfToken;

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    final user = json['user'];
    if (user is! Map<String, dynamic> || json['accessToken'] is! String) {
      throw const FormatException('Invalid session response.');
    }
    return AuthSession(
      accessToken: json['accessToken'] as String,
      expiresIn: json['expiresIn'] as int? ?? 0,
      refreshExpiresAt: DateTime.parse(json['refreshExpiresAt'] as String),
      sessionId: json['sessionId'] as String? ?? '',
      user: UserProfile.fromJson(user),
      refreshToken: json['refreshToken'] as String?,
      csrfToken: json['csrfToken'] as String?,
    );
  }
}
