import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_app/core/network/api_client.dart';
import 'package:sales_app/features/submissions/data/submission_repository.dart';
import 'package:sales_app/features/submissions/domain/submission.dart';

void main() {
  test(
    'loads eligible reviewer options for the requested review stage',
    () async {
      final api = ApiClient(
        baseUrl: Uri.parse('https://api.example.com/api/v1'),
        client: MockClient((request) async {
          expect(
            request.url.path,
            '/api/v1/program-submissions/sub_0144/reviewer-options',
          );
          expect(request.url.queryParameters, {
            'stage': 'acknowledgement',
            'page': '2',
            'pageSize': '20',
            'q': 'dewi',
          });
          return http.Response(
            jsonEncode({
              'data': [
                {
                  'person': {
                    'id': 'usr_dewi',
                    'fullName': 'Dewi Larasati',
                    'jobTitle': 'Branch Manager BSD',
                  },
                  'eligibleStages': ['acknowledgement'],
                },
              ],
              'meta': {
                'requestId': 'req_reviewer',
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

      final result = await SubmissionRepository(api).reviewerOptions(
        'sub_0144',
        stage: ReviewerStage.acknowledgement,
        page: 2,
        query: ' dewi ',
      );

      expect(result.page, 2);
      expect(result.totalPages, 3);
      expect(result.items.single.person.fullName, 'Dewi Larasati');
      expect(result.items.single.eligibleStages, [
        ReviewerStage.acknowledgement,
      ]);
    },
  );
}
