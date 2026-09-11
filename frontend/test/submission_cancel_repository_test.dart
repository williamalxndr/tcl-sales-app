import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_app/core/network/api_client.dart';
import 'package:sales_app/features/submissions/data/submission_repository.dart';

void main() {
  test('cancels an authorized submission with reason and headers', () async {
    final api = ApiClient(
      baseUrl: Uri.parse('https://api.example.com/api/v1'),
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/program-submissions/sub_0144/cancel');
        expect(request.headers['if-match'], '"5"');
        expect(request.headers['idempotency-key'], startsWith('cancel-'));
        expect(request.headers['idempotency-key']!.length, greaterThan(16));
        expect(jsonDecode(request.body), {
          'reason': 'Program tidak jadi dilaksanakan.',
        });
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'sub_0144',
              'programNumber': 'PRG-2026-0144',
              'status': 'cancelled',
              'currentStage': null,
              'version': 6,
              'locations': [],
              'myActiveTaskIds': [],
              'reviewPlan': {},
              'reviewTasks': [],
              'attachments': [],
              'allowedActions': ['downloadPdf'],
              'submissionIssues': [],
            },
            'meta': {'requestId': 'req_cancel'},
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);

    final submission = await SubmissionRepository(api).cancelSubmission(
      'sub_0144',
      reason: '  Program tidak jadi dilaksanakan.  ',
      version: 5,
    );

    expect(submission.status, 'cancelled');
    expect(submission.version, 6);
  });
}
