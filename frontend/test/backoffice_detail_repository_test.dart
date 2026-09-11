import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_app/core/network/api_client.dart';
import 'package:sales_app/features/backoffice/data/backoffice_repository.dart';

void main() {
  test('loads an authorized backoffice submission detail', () async {
    final api = ApiClient(
      baseUrl: Uri.parse('https://api.example.com/api/v1'),
      client: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/backoffice/program-submissions/sub_0144',
        );
        return http.Response(
          jsonEncode({
            'data': {
              'id': 'sub_0144',
              'programNumber': 'PRG-2026-0144',
              'programName': 'Bundling September',
              'locations': [],
              'owner': {'id': 'usr_1', 'fullName': 'Rizky Pratama'},
              'status': 'pendingChecker',
              'version': 5,
              'reviewPlan': {},
              'reviewTasks': [],
              'myActiveTaskIds': ['tsk_1'],
              'attachments': [],
              'allowedActions': ['approve', 'reject', 'downloadPdf'],
              'submissionIssues': [],
            },
            'meta': {'requestId': 'req_detail'},
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);

    final detail = await BackofficeRepository(api).getSubmission('sub_0144');

    expect(detail.submission.programName, 'Bundling September');
    expect(detail.submission.myActiveTaskIds, ['tsk_1']);
    expect(detail.owner.fullName, 'Rizky Pratama');
  });
}
