import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_app/core/network/api_client.dart';
import 'package:sales_app/features/backoffice/data/backoffice_repository.dart';

void main() {
  test('loads the paginated reviewer inbox', () async {
    final api = ApiClient(
      baseUrl: Uri.parse('https://api.example.com/api/v1'),
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/backoffice/program-submissions');
        expect(request.url.queryParameters, {'page': '2', 'pageSize': '20'});
        return http.Response(
          jsonEncode({
            'data': [
              {
                'id': 'sub_0144',
                'programNumber': 'PRG-2026-0144',
                'programName': 'Bundling September Outlet BSD',
                'programType': {'id': 'typ_1', 'name': 'Bundling'},
                'locations': [
                  {'id': 'loc_bsd', 'name': 'BSD'},
                ],
                'owner': {
                  'id': 'usr_rizky',
                  'fullName': 'Rizky Pratama',
                  'jobTitle': 'Sales Executive',
                },
                'status': 'pendingChecker',
                'currentStage': 'checker',
                'version': 5,
                'myActiveTaskIds': ['tsk_checker'],
              },
            ],
            'meta': {
              'requestId': 'req_inbox',
              'page': 2,
              'totalPages': 3,
              'totalItems': 41,
            },
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);

    final result = await BackofficeRepository(api).listInbox(page: 2);

    expect(result.page, 2);
    expect(result.totalPages, 3);
    expect(result.totalItems, 41);
    expect(result.items.single.submission.programNumber, 'PRG-2026-0144');
    expect(result.items.single.owner.fullName, 'Rizky Pratama');
    expect(result.items.single.myActiveTaskIds, ['tsk_checker']);
  });
}
