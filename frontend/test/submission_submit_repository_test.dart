import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_app/core/network/api_client.dart';
import 'package:sales_app/features/submissions/data/submission_repository.dart';

void main() {
  test('submits a draft with concurrency and idempotency headers', () async {
    final api = ApiClient(
      baseUrl: Uri.parse('https://api.example.com/api/v1'),
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/program-submissions/sub_0144/submit');
        expect(request.headers['if-match'], '"4"');
        expect(request.headers['idempotency-key'], startsWith('submit-'));
        expect(request.headers['idempotency-key']!.length, greaterThan(16));
        expect(jsonDecode(request.body), isEmpty);
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'sub_0144',
              'programNumber': 'PRG-2026-0144',
              'status': 'pendingChecker',
              'version': 5,
              'locations': [],
              'reviewPlan': {},
              'attachments': [],
              'allowedActions': ['downloadPdf'],
              'submissionIssues': [],
            },
            'meta': {'requestId': 'req_submit'},
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);

    final submission = await SubmissionRepository(
      api,
    ).submitDraft('sub_0144', 4);

    expect(submission.status, 'pendingChecker');
    expect(submission.version, 5);
  });
}
