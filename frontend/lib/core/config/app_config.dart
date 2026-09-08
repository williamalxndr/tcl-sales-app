import 'package:flutter/foundation.dart';

class AppConfig {
  AppConfig({required String apiBaseUrl, bool allowInsecure = false})
    : apiBaseUrl = _validate(apiBaseUrl, allowInsecure);

  final Uri apiBaseUrl;

  factory AppConfig.fromEnvironment() {
    const configured = String.fromEnvironment('API_BASE_URL');
    if (kReleaseMode && configured.isEmpty) {
      throw StateError('API_BASE_URL is required for release builds.');
    }
    final host = !kIsWeb && defaultTargetPlatform == TargetPlatform.android
        ? '10.0.2.2'
        : 'localhost';
    return AppConfig(
      apiBaseUrl: configured.isEmpty ? 'http://$host:8000/api/v1' : configured,
      allowInsecure: !kReleaseMode,
    );
  }

  static Uri _validate(String value, bool allowInsecure) {
    final uri = Uri.parse(value);
    if (!uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        !['https', if (allowInsecure) 'http'].contains(uri.scheme) ||
        !['/api/v1', '/api/v1/'].contains(uri.path)) {
      throw ArgumentError('API_BASE_URL must be an API origin ending /api/v1.');
    }
    return uri.replace(path: '/api/v1');
  }
}
