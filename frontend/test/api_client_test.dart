import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_app/core/config/app_config.dart';
import 'package:sales_app/core/network/api_client.dart';
import 'package:sales_app/core/network/api_exception.dart';

void main() {
  final baseUrl = Uri.parse('https://api.example.com/api/v1');

  test('keeps version prefix and decodes camelCase JSON envelope', () async {
    final api = ApiClient(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://api.example.com/api/v1/health/ready',
        );
        return http.Response(
          jsonEncode({
            'data': {'status': 'ready', 'database': 'ok'},
            'meta': {'requestId': 'req_test'},
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);
    expect((await api.getObject('health/ready'))['status'], 'ready');
  });

  test('preserves server error code, status and correlation ID', () async {
    final api = ApiClient(
      baseUrl: baseUrl,
      client: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'error': {
              'code': 'SERVICE_UNAVAILABLE',
              'message': 'Unavailable.',
              'details': [],
            },
            'meta': {'requestId': 'req_failure'},
          }),
          503,
        ),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      api.getObject('health/ready'),
      throwsA(
        isA<ApiException>()
            .having((e) => e.code, 'code', 'SERVICE_UNAVAILABLE')
            .having((e) => e.statusCode, 'statusCode', 503)
            .having((e) => e.requestId, 'requestId', 'req_failure'),
      ),
    );
  });

  test('HTML error pages become a safe client error', () async {
    final api = ApiClient(
      baseUrl: baseUrl,
      client: MockClient(
        (_) async => http.Response('<html>proxy error</html>', 502),
      ),
    );
    addTearDown(api.close);
    await expectLater(
      api.getObject('health/ready'),
      throwsA(
        isA<ApiException>().having((e) => e.code, 'code', 'INVALID_RESPONSE'),
      ),
    );
  });

  test('release configuration requires HTTPS and correct API prefix', () {
    expect(
      () => AppConfig(apiBaseUrl: 'http://localhost:8000/api/v1'),
      throwsArgumentError,
    );
    expect(
      () => AppConfig(apiBaseUrl: 'https://api.example.com'),
      throwsArgumentError,
    );
    expect(
      AppConfig(apiBaseUrl: 'https://api.example.com/api/v1/').apiBaseUrl,
      baseUrl,
    );
  });
}
