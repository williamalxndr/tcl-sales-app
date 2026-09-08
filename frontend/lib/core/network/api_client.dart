import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client();

  final Uri baseUrl;
  final http.Client _client;
  final Duration timeout;

  /// Relative paths preserve the version prefix on every platform.
  /// Session/token storage and mutation retries will be added with auth.
  Future<Map<String, dynamic>> getObject(String path) async {
    if (path.isEmpty ||
        path.startsWith('/') ||
        path.split('/').any((part) => part == '..' || part == '.') ||
        path.contains('?') ||
        path.contains('#')) {
      throw ArgumentError.value(
        path,
        'path',
        'Use a relative API resource path.',
      );
    }
    final uri = baseUrl.replace(path: '${baseUrl.path}/$path');
    try {
      final response = await _client
          .get(uri, headers: {'Accept': 'application/json'})
          .timeout(timeout);
      final body = jsonDecode(response.body);
      if (body is! Map<String, dynamic>) {
        throw const FormatException('Expected an API envelope.');
      }
      final metadata = body['meta'];
      final candidate = metadata is Map<String, dynamic>
          ? metadata['requestId']
          : null;
      final requestId = candidate is String
          ? candidate
          : response.headers['x-request-id'];
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final error = body['error'];
        if (error is! Map<String, dynamic> ||
            error['code'] is! String ||
            error['message'] is! String) {
          throw const FormatException('Expected an API error.');
        }
        throw ApiException(
          code: error['code'] as String,
          message: error['message'] as String,
          statusCode: response.statusCode,
          requestId: requestId,
        );
      }
      if (body['data'] is! Map<String, dynamic> || requestId == null) {
        throw const FormatException(
          'Expected object data and request metadata.',
        );
      }
      return body['data'] as Map<String, dynamic>;
    } on TimeoutException {
      throw const ApiException(
        code: 'TIMEOUT',
        message: 'The service took too long to respond.',
      );
    } on http.ClientException {
      throw const ApiException(
        code: 'NETWORK_ERROR',
        message: 'Unable to connect to the service.',
      );
    } on FormatException {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'The service returned an unexpected response.',
      );
    }
  }

  void close() => _client.close();
}
