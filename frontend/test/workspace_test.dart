import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_app/app.dart';
import 'package:sales_app/core/di/providers.dart';
import 'package:sales_app/core/network/api_client.dart';

void main() {
  testWidgets(
    'connection failure can be retried successfully on a narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var attempts = 0;
      final api = ApiClient(
        baseUrl: Uri.parse('https://api.example.com/api/v1'),
        client: MockClient((_) async {
          attempts++;
          if (attempts == 1) throw http.ClientException('offline');
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
      await tester.pumpWidget(
        ProviderScope(
          overrides: [apiClientProvider.overrideWithValue(api)],
          child: const SalesApp(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Try again'), findsOneWidget);
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.text('Service connected'), findsOneWidget);
      expect(attempts, 2);
      expect(tester.takeException(), isNull);
    },
  );
}
