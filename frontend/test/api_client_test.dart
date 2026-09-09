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
              'details': [
                {'field': 'name', 'code': 'REQUIRED', 'message': 'Required.'},
              ],
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

  test(
    'sends mutation concurrency headers and exposes response ETag',
    () async {
      final api = ApiClient(
        baseUrl: baseUrl,
        client: MockClient((request) async {
          expect(request.method, 'PATCH');
          expect(request.url.toString(), contains('page=2'));
          expect(request.headers['idempotency-key'], 'idem-001');
          expect(request.headers['if-match'], '"v3"');
          expect(jsonDecode(request.body), {'programName': 'Program baru'});
          return http.Response(
            jsonEncode({
              'data': {'id': 'prg_001'},
              'meta': {'requestId': 'req_patch'},
            }),
            200,
            headers: {'etag': '"v4"'},
          );
        }),
      );
      addTearDown(api.close);

      final response = await api.request(
        'PATCH',
        'program-submissions/prg_001',
        body: {'programName': 'Program baru'},
        query: {'page': '2'},
        idempotencyKey: 'idem-001',
        ifMatch: '"v3"',
      );
      expect(response.eTag, '"v4"');
    },
  );

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
