import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sales_app/core/network/api_client.dart';
import 'package:sales_app/features/submissions/data/submission_repository.dart';

void main() {
  test('downloads submitter PDF with its server-provided file name', () async {
    final api = ApiClient(
      baseUrl: Uri.parse('https://api.example.com/api/v1'),
      client: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/program-submissions/sub_0144/pdf');
        return http.Response.bytes(
          [37, 80, 68, 70],
          200,
          headers: {
            'content-type': 'application/pdf',
            'content-disposition': 'attachment; filename="PRG-2026-0144.pdf"',
          },
        );
      }),
    );
    addTearDown(api.close);

    final result = await SubmissionRepository(
      api,
    ).downloadPdf('sub_0144', 'PRG-2026-0144');

    expect(result.bytes, [37, 80, 68, 70]);
    expect(result.fileName, 'PRG-2026-0144.pdf');
    expect(result.contentType, 'application/pdf');
  });
}
