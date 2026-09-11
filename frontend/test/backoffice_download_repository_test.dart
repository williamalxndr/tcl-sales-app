import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_app/core/network/api_client.dart';
import 'package:sales_app/features/backoffice/data/backoffice_repository.dart';
import 'package:sales_app/features/submissions/domain/submission.dart';

void main() {
  test(
    'downloads attachment from the authorized backoffice endpoint',
    () async {
      final api = ApiClient(
        baseUrl: Uri.parse('https://api.example.com/api/v1'),
        client: MockClient((request) async {
          expect(
            request.url.path,
            '/api/v1/backoffice/program-submissions/sub_1/'
            'attachments/att_1/content',
          );
          return http.Response.bytes(
            Uint8List.fromList([1, 2, 3]),
            200,
            headers: {
              'content-type': 'application/pdf',
              'content-disposition': 'attachment; filename="Proposal.pdf"',
            },
          );
        }),
      );
      addTearDown(api.close);
      const attachment = SubmissionAttachment(
        id: 'att_1',
        submissionId: 'sub_1',
        fileName: 'fallback.pdf',
        contentType: 'application/pdf',
        sizeBytes: 3,
        scanStatus: 'clean',
        uploadedAt: '',
      );

      final result = await BackofficeRepository(
        api,
      ).downloadAttachment('sub_1', attachment);

      expect(result.bytes, [1, 2, 3]);
      expect(result.fileName, 'Proposal.pdf');
    },
  );

  test('downloads PDF from the authorized backoffice endpoint', () async {
    final api = ApiClient(
      baseUrl: Uri.parse('https://api.example.com/api/v1'),
      client: MockClient((request) async {
        expect(
          request.url.path,
          '/api/v1/backoffice/program-submissions/sub_1/pdf',
        );
        return http.Response.bytes(
          Uint8List.fromList([37, 80, 68, 70]),
          200,
          headers: {'content-type': 'application/pdf'},
        );
      }),
    );
    addTearDown(api.close);

    final result = await BackofficeRepository(
      api,
    ).downloadPdf('sub_1', 'PRG-2026-0001');

    expect(result.fileName, 'PRG-2026-0001.pdf');
    expect(result.contentType, 'application/pdf');
  });
}
