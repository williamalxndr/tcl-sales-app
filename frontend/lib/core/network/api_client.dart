import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'http_client_factory.dart';

typedef UnauthorizedHandler = Future<bool> Function();

/// Decoded API envelope and the transport metadata needed for concurrency.
class ApiResponse<T> {
  const ApiResponse({
    required this.data,
    required this.requestId,
    required this.meta,
    this.eTag,
    this.location,
  });

  final T data;
  final String requestId;
  final Map<String, dynamic> meta;
  final String? eTag;
  final String? location;
}

/// HTTP client for the `/api/v1` envelope.
///
/// It owns only short-lived access/CSRF values in memory. Refresh credentials
/// are deliberately owned by the authentication repository and secure store.
class ApiClient {
  ApiClient({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 15),
  }) : _client = client ?? createHttpClient();

  final Uri baseUrl;
  final http.Client _client;
  final Duration timeout;

  String? _accessToken;
  String? _csrfToken;
  UnauthorizedHandler? _unauthorizedHandler;
  Future<bool>? _refreshing;

  void configureSession({String? accessToken, String? csrfToken}) {
    _accessToken = accessToken;
    _csrfToken = csrfToken;
  }

  void clearSession() {
    _accessToken = null;
    _csrfToken = null;
  }

  void setUnauthorizedHandler(UnauthorizedHandler? handler) {
    _unauthorizedHandler = handler;
  }

  Future<Map<String, dynamic>> getObject(
    String path, {
    Map<String, String?> query = const {},
    bool authenticated = true,
    bool retryUnauthorized = true,
  }) async {
    final response = await request(
      'GET',
      path,
      query: query,
      authenticated: authenticated,
      retryUnauthorized: retryUnauthorized,
    );
    return _expectObject(response.data);
  }

  Future<Map<String, dynamic>> postObject(
    String path, {
    Map<String, dynamic>? body,
    Map<String, String?> query = const {},
    String? idempotencyKey,
    String? ifMatch,
    bool authenticated = true,
    bool retryUnauthorized = true,
  }) async {
    final response = await request(
      'POST',
      path,
      body: body,
      query: query,
      idempotencyKey: idempotencyKey,
      ifMatch: ifMatch,
      authenticated: authenticated,
      retryUnauthorized: retryUnauthorized,
    );
    return _expectObject(response.data);
  }

  Future<Map<String, dynamic>> putObject(
    String path, {
    required Map<String, dynamic> body,
    String? idempotencyKey,
    String? ifMatch,
  }) async {
    final response = await request(
      'PUT',
      path,
      body: body,
      idempotencyKey: idempotencyKey,
      ifMatch: ifMatch,
    );
    return _expectObject(response.data);
  }

  Future<Map<String, dynamic>> patchObject(
    String path, {
    required Map<String, dynamic> body,
    String? idempotencyKey,
    String? ifMatch,
  }) async {
    final response = await request(
      'PATCH',
      path,
      body: body,
      idempotencyKey: idempotencyKey,
      ifMatch: ifMatch,
    );
    return _expectObject(response.data);
  }

  Future<Map<String, dynamic>> deleteObject(
    String path, {
    Map<String, dynamic>? body,
    String? idempotencyKey,
    String? ifMatch,
  }) async {
    final response = await request(
      'DELETE',
      path,
      body: body,
      idempotencyKey: idempotencyKey,
      ifMatch: ifMatch,
    );
    return _expectObject(response.data);
  }

  Future<ApiResponse<dynamic>> request(
    String method,
    String path, {
    Object? body,
    Map<String, String?> query = const {},
    Map<String, String> headers = const {},
    String? idempotencyKey,
    String? ifMatch,
    bool authenticated = true,
    bool retryUnauthorized = true,
  }) {
    return _request(
      method.toUpperCase(),
      path,
      body: body,
      query: query,
      headers: headers,
      idempotencyKey: idempotencyKey,
      ifMatch: ifMatch,
      authenticated: authenticated,
      retryUnauthorized: retryUnauthorized,
      hasRetried: false,
    );
  }

  Future<ApiResponse<dynamic>> postMultipart(
    String path, {
    required List<int> bytes,
    required String fileName,
    String fieldName = 'file',
    String? idempotencyKey,
    String? ifMatch,
  }) {
    return _multipartRequest(
      path,
      bytes: bytes,
      fileName: fileName,
      fieldName: fieldName,
      idempotencyKey: idempotencyKey,
      ifMatch: ifMatch,
      hasRetried: false,
    );
  }

  Future<ApiResponse<dynamic>> _request(
    String method,
    String path, {
    required Object? body,
    required Map<String, String?> query,
    required Map<String, String> headers,
    required String? idempotencyKey,
    required String? ifMatch,
    required bool authenticated,
    required bool retryUnauthorized,
    required bool hasRetried,
  }) async {
    final uri = _uriFor(path, query);
    final requestHeaders = <String, String>{
      'Accept': 'application/json',
      ...headers,
      if (body != null) 'Content-Type': 'application/json',
      if (authenticated && _accessToken != null)
        'Authorization': 'Bearer $_accessToken',
      if (_requiresCsrf(method) && _csrfToken != null)
        'X-CSRFToken': _csrfToken!,
      ...?(idempotencyKey == null ? null : {'Idempotency-Key': idempotencyKey}),
      ...?(ifMatch == null ? null : {'If-Match': ifMatch}),
    };

    try {
      final request = http.Request(method, uri)..headers.addAll(requestHeaders);
      if (body != null) request.body = jsonEncode(body);
      final streamed = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(timeout);
      final decoded = _decodeEnvelope(response);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }

      if (response.statusCode == 401 &&
          authenticated &&
          retryUnauthorized &&
          !hasRetried &&
          await _refreshSession()) {
        return _request(
          method,
          path,
          body: body,
          query: query,
          headers: headers,
          idempotencyKey: idempotencyKey,
          ifMatch: ifMatch,
          authenticated: authenticated,
          retryUnauthorized: retryUnauthorized,
          hasRetried: true,
        );
      }
      throw _apiError(response, decoded.requestId);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        code: 'TIMEOUT',
        message: 'Layanan membutuhkan waktu terlalu lama untuk merespons.',
      );
    } on http.ClientException {
      throw const ApiException(
        code: 'NETWORK_ERROR',
        message: 'Tidak dapat terhubung ke layanan.',
      );
    } on FormatException {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'Layanan mengirim respons yang tidak dapat diproses.',
      );
    }
  }

  Future<ApiResponse<dynamic>> _multipartRequest(
    String path, {
    required List<int> bytes,
    required String fileName,
    required String fieldName,
    required String? idempotencyKey,
    required String? ifMatch,
    required bool hasRetried,
  }) async {
    final requestHeaders = <String, String>{
      'Accept': 'application/json',
      if (_accessToken != null) 'Authorization': 'Bearer $_accessToken',
      ...?(_csrfToken == null ? null : {'X-CSRFToken': _csrfToken!}),
      ...?(idempotencyKey == null ? null : {'Idempotency-Key': idempotencyKey}),
      ...?(ifMatch == null ? null : {'If-Match': ifMatch}),
    };
    try {
      final request = http.MultipartRequest('POST', _uriFor(path, const {}))
        ..headers.addAll(requestHeaders)
        ..files.add(
          http.MultipartFile.fromBytes(fieldName, bytes, filename: fileName),
        );
      final streamed = await _client.send(request).timeout(timeout);
      final response = await http.Response.fromStream(
        streamed,
      ).timeout(timeout);
      final decoded = _decodeEnvelope(response);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return decoded;
      }
      if (response.statusCode == 401 &&
          !hasRetried &&
          await _refreshSession()) {
        return _multipartRequest(
          path,
          bytes: bytes,
          fileName: fileName,
          fieldName: fieldName,
          idempotencyKey: idempotencyKey,
          ifMatch: ifMatch,
          hasRetried: true,
        );
      }
      throw _apiError(response, decoded.requestId);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(
        code: 'TIMEOUT',
        message: 'Layanan membutuhkan waktu terlalu lama untuk merespons.',
      );
    } on http.ClientException {
      throw const ApiException(
        code: 'NETWORK_ERROR',
        message: 'Tidak dapat terhubung ke layanan.',
      );
    } on FormatException {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'Layanan mengirim respons yang tidak dapat diproses.',
      );
    }
  }

  Future<bool> _refreshSession() {
    final handler = _unauthorizedHandler;
    if (handler == null) return Future.value(false);
    return _refreshing ??= handler().whenComplete(() => _refreshing = null);
  }

  Uri _uriFor(String path, Map<String, String?> query) {
    if (path.isEmpty ||
        path.startsWith('/') ||
        path.split('/').any((part) => part == '..' || part == '.') ||
        path.contains('?') ||
        path.contains('#')) {
      throw ArgumentError.value(path, 'path', 'Gunakan path API relatif.');
    }
    final resource = baseUrl.replace(path: '${baseUrl.path}/$path');
    final parameters = {
      for (final entry in query.entries)
        if (entry.value != null) entry.key: entry.value!,
    };
    return parameters.isEmpty
        ? resource
        : resource.replace(queryParameters: parameters);
  }

  ApiResponse<dynamic> _decodeEnvelope(http.Response response) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected an API envelope.');
    }
    final metadata = decoded['meta'];
    final requestId = metadata is Map<String, dynamic>
        ? metadata['requestId'] as String?
        : null;
    final resolvedRequestId = requestId ?? response.headers['x-request-id'];
    if (resolvedRequestId == null || resolvedRequestId.isEmpty) {
      throw const FormatException('Expected request metadata.');
    }
    return ApiResponse<dynamic>(
      data: decoded['data'],
      requestId: resolvedRequestId,
      meta: Map<String, dynamic>.from(metadata as Map),
      eTag: response.headers['etag'],
      location: response.headers['location'],
    );
  }

  ApiException _apiError(http.Response response, String requestId) {
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected an API error.');
    }
    final error = decoded['error'];
    if (error is! Map<String, dynamic> ||
        error['code'] is! String ||
        error['message'] is! String) {
      throw const FormatException('Expected an API error.');
    }
    final rawDetails = error['details'];
    return ApiException(
      code: error['code'] as String,
      message: error['message'] as String,
      statusCode: response.statusCode,
      requestId: requestId,
      details: rawDetails is List
          ? rawDetails
                .whereType<Map>()
                .map(
                  (item) =>
                      ApiErrorDetail.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList(growable: false)
          : const [],
    );
  }

  Map<String, dynamic> _expectObject(dynamic value) {
    if (value is! Map<String, dynamic>) {
      throw const ApiException(
        code: 'INVALID_RESPONSE',
        message: 'Layanan mengirim data yang tidak dapat diproses.',
      );
    }
    return value;
  }

  bool _requiresCsrf(String method) =>
      method != 'GET' && method != 'HEAD' && method != 'OPTIONS';

  void close() => _client.close();
}
