import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_app/app.dart';
import 'package:sales_app/core/di/providers.dart';
import 'package:sales_app/core/network/api_client.dart';
import 'package:sales_app/core/session/session_store.dart';

void main() {
  testWidgets('login validates fields and then displays signed-in identity', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final api = ApiClient(
      baseUrl: Uri.parse('https://api.example.com/api/v1'),
      client: MockClient((request) async {
        if (request.url.path.endsWith('/auth/csrf')) {
          expect(kIsWeb, isTrue);
          return http.Response(
            jsonEncode({
              'data': {'csrfToken': 'csrf-bootstrap'},
              'meta': {'requestId': 'req_csrf'},
            }),
            200,
          );
        }
        if (request.url.path.endsWith('/auth/refresh')) {
          expect(kIsWeb, isTrue);
          return http.Response(
            jsonEncode({
              'error': {
                'code': 'UNAUTHENTICATED',
                'message': 'No browser session.',
                'details': [],
              },
              'meta': {'requestId': 'req_refresh'},
            }),
            401,
          );
        }
        if (request.url.path.endsWith('/auth/login')) {
          if (kIsWeb) expect(request.headers['x-csrftoken'], 'csrf-bootstrap');
          final session = _session();
          if (kIsWeb) {
            session
              ..remove('refreshToken')
              ..['csrfToken'] = 'csrf-rotated';
          }
          return http.Response(
            jsonEncode({
              'data': session,
              'meta': {'requestId': 'req_login'},
            }),
            200,
          );
        }
        return http.Response(
          jsonEncode({
            'data': {'status': 'ready', 'database': 'ok'},
            'meta': {'requestId': 'req_ready'},
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          apiClientProvider.overrideWithValue(api),
          sessionStoreProvider.overrideWithValue(MemorySessionStore()),
        ],
        child: const SalesApp(),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Masuk'), findsAtLeastNWidgets(1));

    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pump();
    expect(find.text('Email wajib diisi.'), findsOneWidget);

    await tester.enterText(
      find.byType(TextFormField).at(0),
      'rizky@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password');
    await tester.tap(find.widgetWithText(FilledButton, 'Masuk'));
    await tester.pumpAndSettle();

    expect(find.text('RP'), findsOneWidget);
    expect(find.byTooltip('Keluar'), findsOneWidget);
  });
}

Map<String, dynamic> _session() => {
  'accessToken': 'access-1',
  'tokenType': 'Bearer',
  'expiresIn': 900,
  'refreshToken': 'refresh-1',
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
