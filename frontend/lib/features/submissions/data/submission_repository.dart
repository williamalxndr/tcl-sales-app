import 'dart:math';

import '../../../core/network/api_client.dart';
import '../domain/submission.dart';

class SubmissionRepository {
  SubmissionRepository(this._api);

  final ApiClient _api;

  Future<SubmissionPage> list({String? query, int page = 1}) async {
    final response = await _api.request(
      'GET',
      'program-submissions',
      query: {'page': '$page', 'pageSize': '20', 'q': query?.trim()},
    );
    final rawItems = response.data;
    if (rawItems is! List) {
      throw const FormatException('Invalid submissions list.');
    }
    return SubmissionPage(
      items: rawItems
          .whereType<Map>()
          .map(
            (value) =>
                SubmissionSummary.fromJson(Map<String, dynamic>.from(value)),
          )
          .toList(growable: false),
      page: response.meta['page'] as int? ?? page,
      totalPages: response.meta['totalPages'] as int? ?? 1,
      totalItems: response.meta['totalItems'] as int? ?? rawItems.length,
    );
  }

  Future<Submission> createEmptyDraft() async {
    final data = await _api.postObject(
      'program-submissions',
      body: const {},
      idempotencyKey: _newIdempotencyKey(),
    );
    return Submission.fromJson(data);
  }

  Future<Submission> get(String submissionId) async {
    return Submission.fromJson(
      await _api.getObject('program-submissions/$submissionId'),
    );
  }

  Future<SubmissionPolicy> policy(String submissionId) async {
    return SubmissionPolicy.fromJson(
      await _api.getObject('program-submissions/$submissionId/policy'),
    );
  }

  Future<ReviewerPage> reviewerOptions(
    String submissionId, {
    required ReviewerStage stage,
    String? query,
    int page = 1,
  }) async {
    final cleanQuery = query?.trim();
    final response = await _api.request(
      'GET',
      'program-submissions/$submissionId/reviewer-options',
      query: {
        'stage': stage.apiValue,
        'page': '$page',
        'pageSize': '20',
        'q': cleanQuery == null || cleanQuery.isEmpty ? null : cleanQuery,
      },
    );
    if (response.data is! List) {
      throw const FormatException('Invalid reviewer options list.');
    }
    final items = (response.data as List)
        .whereType<Map>()
        .map(
          (value) => ReviewerOption.fromJson(Map<String, dynamic>.from(value)),
        )
        .toList(growable: false);
    return ReviewerPage(
      items: items,
      page: response.meta['page'] as int? ?? page,
      totalPages: response.meta['totalPages'] as int? ?? 1,
      totalItems: response.meta['totalItems'] as int? ?? items.length,
    );
  }

  Future<List<MasterOption>> locations() =>
      _masterOptions('master-data/locations');

  Future<List<MasterOption>> programTypes() =>
      _masterOptions('master-data/program-types');

  Future<List<MasterOption>> _masterOptions(String path) async {
    final response = await _api.request(
      'GET',
      path,
      query: {'pageSize': '100'},
    );
    if (response.data is! List) {
      throw const FormatException('Invalid master data.');
    }
    return (response.data as List)
        .whereType<Map>()
        .map((value) => MasterOption.fromJson(Map<String, dynamic>.from(value)))
        .toList(growable: false);
  }

  Future<Submission> updateDraft(
    String submissionId,
    Map<String, dynamic> fields,
    int version,
  ) async {
    final response = await _api.request(
      'PATCH',
      'program-submissions/$submissionId',
      body: fields,
      ifMatch: '"$version"',
    );
    if (response.data is! Map<String, dynamic>) {
      throw const FormatException('Invalid draft response.');
    }
    return Submission.fromJson(response.data as Map<String, dynamic>);
  }

  Future<AttachmentUploadResult> uploadAttachment(
    String submissionId, {
    required List<int> bytes,
    required String fileName,
    required int version,
  }) async {
    final response = await _api.postMultipart(
      'program-submissions/$submissionId/attachments',
      bytes: bytes,
      fileName: fileName,
      idempotencyKey: _newIdempotencyKey('attachment'),
      ifMatch: '"$version"',
    );
    if (response.data is! Map) {
      throw const FormatException('Invalid attachment upload response.');
    }
    return AttachmentUploadResult.fromJson(
      Map<String, dynamic>.from(response.data as Map),
    );
  }

  Future<AttachmentRemovalResult> removeAttachment(
    String submissionId, {
    required String attachmentId,
    required int version,
  }) async {
    final data = await _api.deleteObject(
      'program-submissions/$submissionId/attachments/$attachmentId',
      idempotencyKey: _newIdempotencyKey('remove-attachment'),
      ifMatch: '"$version"',
    );
    return AttachmentRemovalResult.fromJson(data);
  }

  Future<AttachmentDownload> downloadAttachment(
    String submissionId,
    SubmissionAttachment attachment,
  ) async {
    final response = await _api.getBytes(
      'program-submissions/$submissionId/attachments/${attachment.id}/content',
    );
    return AttachmentDownload(
      bytes: response.bytes,
      fileName: _downloadFileName(
        response.headers['content-disposition'],
        attachment.fileName,
      ),
      contentType: response.headers['content-type'] ?? attachment.contentType,
    );
  }

  Future<Submission> submitDraft(String submissionId, int version) async {
    final data = await _api.postObject(
      'program-submissions/$submissionId/submit',
      body: const {},
      idempotencyKey: _newIdempotencyKey('submit'),
      ifMatch: '"$version"',
    );
    return Submission.fromJson(data);
  }

  String _downloadFileName(String? disposition, String fallback) {
    final encoded = RegExp(
      r"filename\*=UTF-8''([^;]+)",
      caseSensitive: false,
    ).firstMatch(disposition ?? '');
    final quoted = RegExp(
      r'filename="([^\"]+)"',
      caseSensitive: false,
    ).firstMatch(disposition ?? '');
    final plain = RegExp(
      r'filename=([^;]+)',
      caseSensitive: false,
    ).firstMatch(disposition ?? '');
    final name = encoded == null
        ? quoted?.group(1) ?? plain?.group(1)?.trim()
        : Uri.decodeComponent(encoded.group(1)!);
    final sanitized = (name ?? fallback).replaceAll(
      RegExp(r'[\\/:*?"<>|]'),
      '_',
    );
    return sanitized.trim().isEmpty ? fallback : sanitized.trim();
  }

  String _newIdempotencyKey([String prefix = 'draft']) {
    final random = Random.secure();
    final parts = List<String>.generate(
      24,
      (_) => random.nextInt(36).toRadixString(36),
    );
    return '$prefix-${parts.join()}';
  }
}
