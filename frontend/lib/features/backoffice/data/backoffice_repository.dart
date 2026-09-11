import '../../../core/network/api_client.dart';
import '../../submissions/domain/submission.dart';
import '../domain/backoffice_submission.dart';

class BackofficeRepository {
  BackofficeRepository(this._api);

  final ApiClient _api;

  Future<BackofficeSubmissionPage> listInbox({
    int page = 1,
    String? programNumber,
    String? status,
    BackofficePersonField? reviewerField,
    String? reviewerId,
    String? periodStartFrom,
    String? periodStartTo,
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
        'status': status,
        if (reviewerField != null) reviewerField.queryParameter: reviewerId,
        'periodStartFrom': periodStartFrom,
        'periodStartTo': periodStartTo,
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

  Future<BackofficePeoplePage> listFilterPeople({
    required BackofficePersonField field,
    String scope = 'inbox',
    String? query,
    int page = 1,
  }) async {
    final cleanQuery = query?.trim();
    final response = await _api.request(
      'GET',
      'backoffice/filter-options/people',
      query: {
        'field': field.apiValue,
        'scope': scope,
        'page': '$page',
        'pageSize': '100',
        'q': cleanQuery == null || cleanQuery.isEmpty ? null : cleanQuery,
      },
    );
    final data = response.data;
    if (data is! List) {
      throw const FormatException('Invalid people filter response.');
    }
    final items = data
        .whereType<Map>()
        .map(
          (person) => PolicyPerson.fromJson(Map<String, dynamic>.from(person)),
        )
        .toList(growable: false);
    return BackofficePeoplePage(
      items: items,
      page: response.meta['page'] as int? ?? page,
      totalPages: response.meta['totalPages'] as int? ?? 1,
      totalItems: response.meta['totalItems'] as int? ?? items.length,
    );
  }

  Future<BackofficeSubmissionDetail> getSubmission(String submissionId) async {
    final data = await _api.getObject(
      'backoffice/program-submissions/$submissionId',
    );
    return BackofficeSubmissionDetail.fromJson(data);
  }
}
