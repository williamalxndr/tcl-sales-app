import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_app/core/network/api_client.dart';
import 'package:sales_app/features/backoffice/data/backoffice_repository.dart';

void main() {
  test('approves one active review task with concurrency headers', () async {
    final api = ApiClient(
      baseUrl: Uri.parse('https://api.example.com/api/v1'),
      client: MockClient((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/api/v1/backoffice/program-submissions/sub_1/'
          'review-tasks/tsk_1/approve',
        );
        expect(request.headers['if-match'], '"5"');
        expect(request.headers['idempotency-key'], startsWith('approve-'));
        expect(jsonDecode(request.body), {'note': 'Sesuai proposal.'});
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'sub_1',
              'programNumber': 'PRG-2026-0001',
              'locations': [],
              'owner': {'id': 'usr_1', 'fullName': 'Rizky'},
              'status': 'pendingAcknowledgement',
              'version': 6,
              'reviewPlan': {},
              'reviewTasks': [],
              'myActiveTaskIds': [],
              'attachments': [],
              'allowedActions': ['downloadPdf'],
              'submissionIssues': [],
            },
            'meta': {'requestId': 'req_approve'},
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);

    final detail = await BackofficeRepository(api).approveTask(
      submissionId: 'sub_1',
      taskId: 'tsk_1',
      version: 5,
      note: '  Sesuai proposal.  ',
    );

    expect(detail.submission.version, 6);
  });

  test('rejects one active review task with concurrency headers', () async {
    final api = ApiClient(
      baseUrl: Uri.parse('https://api.example.com/api/v1'),
      client: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/backoffice/program-submissions/sub_1/'
          'review-tasks/tsk_1/reject',
        );
        expect(request.headers['if-match'], '"6"');
        expect(request.headers['idempotency-key'], startsWith('reject-'));
        expect(jsonDecode(request.body), {'note': 'Anggaran perlu ditinjau.'});
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'sub_1',
              'programNumber': 'PRG-2026-0001',
              'locations': [],
              'owner': {'id': 'usr_1', 'fullName': 'Rizky'},
              'status': 'rejected',
              'version': 7,
              'reviewPlan': {},
              'reviewTasks': [],
              'myActiveTaskIds': [],
              'attachments': [],
              'allowedActions': ['downloadPdf'],
              'submissionIssues': [],
            },
            'meta': {'requestId': 'req_reject'},
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);

    final detail = await BackofficeRepository(api).rejectTask(
      submissionId: 'sub_1',
      taskId: 'tsk_1',
      version: 6,
      note: ' Anggaran perlu ditinjau. ',
    );

    expect(detail.submission.status, 'rejected');
    expect(detail.submission.version, 7);
  });
}
