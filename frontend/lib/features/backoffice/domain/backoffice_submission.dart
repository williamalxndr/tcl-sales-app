import '../../submissions/domain/submission.dart';

class BackofficeSubmissionSummary {
  const BackofficeSubmissionSummary({
    required this.submission,
    required this.owner,
    required this.myActiveTaskIds,
    this.currentStage,
    this.submittedAt,
  });

  final SubmissionSummary submission;
  final PolicyPerson owner;
  final String? currentStage;
  final String? submittedAt;
  final List<String> myActiveTaskIds;

  factory BackofficeSubmissionSummary.fromJson(Map<String, dynamic> json) {
    final owner = json['owner'];
    if (owner is! Map) {
      throw const FormatException('Backoffice submission is missing its owner.');
    }
    return BackofficeSubmissionSummary(
      submission: SubmissionSummary.fromJson(json),
      owner: PolicyPerson.fromJson(Map<String, dynamic>.from(owner)),
      currentStage: json['currentStage'] as String?,
      submittedAt: json['submittedAt'] as String?,
      myActiveTaskIds:
          (json['myActiveTaskIds'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(growable: false),
    );
  }
}

class BackofficeSubmissionPage {
  const BackofficeSubmissionPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.totalItems,
  });

  final List<BackofficeSubmissionSummary> items;
  final int page;
  final int totalPages;
  final int totalItems;
}
