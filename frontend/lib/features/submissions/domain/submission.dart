class SubmissionSummary {
  const SubmissionSummary({
    required this.id,
    required this.programNumber,
    required this.status,
    required this.locations,
    required this.locationIds,
    required this.version,
    this.programName,
    this.programType,
    this.programTypeId,
    this.periodStart,
    this.periodEnd,
    this.estimatedCost,
  });

  final String id;
  final String programNumber;
  final String? programName;
  final String? programType;
  final String? programTypeId;
  final List<String> locations;
  final List<String> locationIds;
  final String? periodStart;
  final String? periodEnd;
  final String? estimatedCost;
  final String status;
  final int version;

  factory SubmissionSummary.fromJson(Map<String, dynamic> json) {
    final type = json['programType'];
    final cost = json['estimatedCost'];
    return SubmissionSummary(
      id: json['id'] as String,
      programNumber: json['programNumber'] as String,
      programName: json['programName'] as String?,
      programType: type is Map ? type['name'] as String? : null,
      programTypeId: type is Map ? type['id'] as String? : null,
      locations: (json['locations'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((value) => value['name'] as String? ?? '')
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      locationIds: (json['locations'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((value) => value['id'] as String? ?? '')
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      periodStart: json['periodStart'] as String?,
      periodEnd: json['periodEnd'] as String?,
      estimatedCost: cost is Map ? cost['amount'] as String? : null,
      status: json['status'] as String? ?? 'draft',
      version: json['version'] as int? ?? 1,
    );
  }

  String get periodLabel {
    if (periodStart == null) return 'Periode belum diisi';
    return periodEnd == null || periodEnd == periodStart
        ? periodStart!
        : '$periodStart – $periodEnd';
  }
}

class Submission extends SubmissionSummary {
  const Submission({
    required super.id,
    required super.programNumber,
    required super.status,
    required super.locations,
    required super.locationIds,
    required super.version,
    required this.allowedActions,
    required this.issues,
    super.programName,
    super.programType,
    super.programTypeId,
    super.periodStart,
    super.periodEnd,
    super.estimatedCost,
  });

  final List<String> allowedActions;
  final List<SubmissionIssue> issues;

  factory Submission.fromJson(Map<String, dynamic> json) {
    final summary = SubmissionSummary.fromJson(json);
    return Submission(
      id: summary.id,
      programNumber: summary.programNumber,
      programName: summary.programName,
      programType: summary.programType,
      programTypeId: summary.programTypeId,
      locations: summary.locations,
      locationIds: summary.locationIds,
      periodStart: summary.periodStart,
      periodEnd: summary.periodEnd,
      estimatedCost: summary.estimatedCost,
      status: summary.status,
      version: summary.version,
      allowedActions: (json['allowedActions'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(growable: false),
      issues: (json['submissionIssues'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (value) =>
                SubmissionIssue.fromJson(Map<String, dynamic>.from(value)),
          )
          .toList(growable: false),
    );
  }
}

class SubmissionIssue {
  const SubmissionIssue({
    required this.code,
    required this.message,
    this.field,
  });

  final String? field;
  final String code;
  final String message;

  factory SubmissionIssue.fromJson(Map<String, dynamic> json) =>
      SubmissionIssue(
        field: json['field'] as String?,
        code: json['code'] as String? ?? 'INVALID',
        message: json['message'] as String? ?? 'Data pengajuan belum lengkap.',
      );

  String get fieldLabel => switch (field) {
    'programName' => 'Nama program',
    'periodStart' => 'Periode pelaksanaan',
    'locationIds' => 'Lokasi',
    'programTypeId' => 'Jenis program',
    'estimatedCost' => 'Estimasi biaya',
    'checkerId' => 'Checker',
    'acknowledgement' => 'Reviewer Mengetahui',
    'approval' => 'Reviewer Persetujuan',
    _ => 'Ketentuan pengajuan',
  };
}

class SubmissionPolicy {
  const SubmissionPolicy({
    required this.policyVersion,
    required this.minAcknowledgers,
    required this.maxAcknowledgers,
    required this.minApprovers,
    required this.maxApprovers,
    required this.allowedAttachmentExtensions,
    required this.maxAttachmentBytes,
    required this.routingConfigured,
    this.checker,
  });

  final String policyVersion;
  final PolicyPerson? checker;
  final int minAcknowledgers;
  final int maxAcknowledgers;
  final int minApprovers;
  final int maxApprovers;
  final List<String> allowedAttachmentExtensions;
  final int maxAttachmentBytes;
  final bool routingConfigured;

  factory SubmissionPolicy.fromJson(Map<String, dynamic> json) {
    final checker = json['checker'];
    return SubmissionPolicy(
      policyVersion: json['policyVersion'] as String? ?? '',
      checker: checker is Map
          ? PolicyPerson.fromJson(Map<String, dynamic>.from(checker))
          : null,
      minAcknowledgers: json['minAcknowledgers'] as int? ?? 0,
      maxAcknowledgers: json['maxAcknowledgers'] as int? ?? 0,
      minApprovers: json['minApprovers'] as int? ?? 0,
      maxApprovers: json['maxApprovers'] as int? ?? 0,
      allowedAttachmentExtensions:
          (json['allowedAttachmentExtensions'] as List<dynamic>? ?? const [])
              .whereType<String>()
              .toList(growable: false),
      maxAttachmentBytes: json['maxAttachmentBytes'] as int? ?? 0,
      routingConfigured: json['routingConfigured'] as bool? ?? false,
    );
  }
}

class PolicyPerson {
  const PolicyPerson({required this.id, required this.fullName, this.jobTitle});

  final String id;
  final String fullName;
  final String? jobTitle;

  factory PolicyPerson.fromJson(Map<String, dynamic> json) => PolicyPerson(
    id: json['id'] as String? ?? '',
    fullName: json['fullName'] as String? ?? '',
    jobTitle: json['jobTitle'] as String?,
  );
}

class SubmissionPage {
  const SubmissionPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.totalItems,
  });

  final List<SubmissionSummary> items;
  final int page;
  final int totalPages;
  final int totalItems;
}

class MasterOption {
  const MasterOption({required this.id, required this.name});

  final String id;
  final String name;

  factory MasterOption.fromJson(Map<String, dynamic> json) =>
      MasterOption(id: json['id'] as String, name: json['name'] as String);
}
