import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_app/core/network/api_client.dart';
import 'package:sales_app/core/session/session_store.dart';
import 'package:sales_app/features/authentication/data/auth_repository.dart';

void main() {
  final baseUrl = Uri.parse('https://api.example.com/api/v1');

  test('native login persists refresh token and refresh rotates it', () async {
    final store = MemorySessionStore();
    var calls = 0;
    final api = ApiClient(
      baseUrl: baseUrl,
      client: MockClient((request) async {
        calls++;
        if (request.url.path.endsWith('/auth/login')) {
          expect(jsonDecode(request.body), {
            'email': 'rizky@example.com',
            'password': 'password',
            'clientType': 'native',
          });
          return _response(
            _nativeSession(access: 'access-1', refresh: 'refresh-1'),
          );
        }
        expect(request.url.path, endsWith('/auth/refresh'));
        expect(jsonDecode(request.body), {'refreshToken': 'refresh-1'});
        return _response(
          _nativeSession(access: 'access-2', refresh: 'refresh-2'),
        );
      }),
    );
    addTearDown(api.close);
    final repository = AuthRepository(
      api: api,
      sessionStore: store,
      isWeb: false,
    );

    final login = await repository.login(
      email: ' rizky@example.com ',
      password: 'password',
    );
    expect(login.user.fullName, 'Rizky Pratama');
    expect(await store.readRefreshToken(), 'refresh-1');

    final refresh = await repository.refresh();
    expect(refresh!.accessToken, 'access-2');
    expect(await store.readRefreshToken(), 'refresh-2');
    expect(calls, 2);
  });

  test(
    'expired access refreshes once and retries the protected request',
    () async {
      final store = MemorySessionStore();
      await store.writeRefreshToken('refresh-1');
      var protectedCalls = 0;
      final api = ApiClient(
        baseUrl: baseUrl,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/refresh')) {
            return _response(
              _nativeSession(access: 'access-2', refresh: 'refresh-2'),
            );
          }
          protectedCalls++;
          if (protectedCalls == 1) {
            expect(request.headers['authorization'], 'Bearer access-1');
            return http.Response(
              jsonEncode({
                'error': {
                  'code': 'UNAUTHENTICATED',
                  'message': 'Expired.',
                  'details': [],
                },
                'meta': {'requestId': 'req_expired'},
              }),
              401,
            );
          }
          expect(request.headers['authorization'], 'Bearer access-2');
          return _response({'status': 'ready', 'database': 'ok'});
        }),
      );
      addTearDown(api.close);
      final repository = AuthRepository(
        api: api,
        sessionStore: store,
        isWeb: false,
      );
      api.configureSession(accessToken: 'access-1');
      api.setUnauthorizedHandler(
        () async => await repository.refresh() != null,
      );

      expect((await api.getObject('health/ready'))['status'], 'ready');
      expect(protectedCalls, 2);
      expect(await store.readRefreshToken(), 'refresh-2');
    },
  );

  test(
    'browser login bootstraps CSRF and never writes a refresh token',
    () async {
      final store = MemorySessionStore();
      final api = ApiClient(
        baseUrl: baseUrl,
        client: MockClient((request) async {
          if (request.url.path.endsWith('/auth/csrf')) {
            return _response({'csrfToken': 'csrf-bootstrap'});
          }
          expect(request.url.path, endsWith('/auth/login'));
          expect(request.headers['x-csrftoken'], 'csrf-bootstrap');
          expect(jsonDecode(request.body)['clientType'], 'web');
          return _response(
            {
              ..._nativeSession(
                access: 'access-web',
                refresh: 'unused-refresh',
              ),
              'csrfToken': 'csrf-rotated',
            }..remove('refreshToken'),
          );
        }),
      );
      addTearDown(api.close);
      final repository = AuthRepository(
        api: api,
        sessionStore: store,
        isWeb: true,
      );

      await repository.login(email: 'rizky@example.com', password: 'password');
      expect(await store.readRefreshToken(), isNull);
    },
  );

  test(
    'logout revokes the native session and clears its stored credential',
    () async {
      final store = MemorySessionStore();
      await store.writeRefreshToken('refresh-1');
      final api = ApiClient(
        baseUrl: baseUrl,
        client: MockClient((request) async {
          expect(request.url.path, endsWith('/auth/logout'));
          expect(jsonDecode(request.body), {'refreshToken': 'refresh-1'});
          return _response({'revoked': true});
        }),
      );
      addTearDown(api.close);
      final repository = AuthRepository(
        api: api,
        sessionStore: store,
        isWeb: false,
      );

      await repository.logout();
      expect(await store.readRefreshToken(), isNull);
    },
  );
}

http.Response _response(Map<String, dynamic> data) => http.Response(
  jsonEncode({
    'data': data,
    'meta': {'requestId': 'req_test'},
  }),
  200,
);

Map<String, dynamic> _nativeSession({
  required String access,
  required String refresh,
}) => {
  'accessToken': access,
  'tokenType': 'Bearer',
  'expiresIn': 900,
  'refreshToken': refresh,
  'refreshExpiresAt': '2026-10-10T00:00:00Z',
  'sessionId': 'ses_rizky',
  'user': {
    'id': 'usr_rizky',
    'fullName': 'Rizky Pratama',
    'employeeNumber': 'B001',
    'email': 'rizky@example.com',
    'jobTitle': 'Sales Executive',
    'status': 'active',
    'roles': ['submitter'],
    'timeZone': 'Asia/Jakarta',
    'locationIds': ['loc_bsd'],
    'checkerId': 'usr_andi',
  },
};
