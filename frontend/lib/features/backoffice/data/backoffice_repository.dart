import '../../../core/network/api_client.dart';
import '../domain/backoffice_submission.dart';

class BackofficeRepository {
  BackofficeRepository(this._api);

  final ApiClient _api;

  Future<BackofficeSubmissionPage> listInbox({
    int page = 1,
    String? programNumber,
  }) async {
    final cleanProgramNumber = programNumber?.trim();
    final response = await _api.request(
      'GET',
      'backoffice/program-submissions',
      query: {
        'page': '$page',
        'pageSize': '20',
        'programNumber':
            cleanProgramNumber == null || cleanProgramNumber.isEmpty
            ? null
            : cleanProgramNumber,
      },
    );
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Invalid backoffice inbox response.');
    }
    final items = data
        .whereType<Map>()
        .map(
          (item) => BackofficeSubmissionSummary.fromJson(
            Map<String, dynamic>.from(item),
          ),
        )
        .toList(growable: false);
    return BackofficeSubmissionPage(
      items: items,
      page: response.meta['page'] as int? ?? page,
      totalPages: response.meta['totalPages'] as int? ?? 1,
      totalItems: response.meta['totalItems'] as int? ?? items.length,
    );
  }
}
