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
    required this.reviewPlan,
    required this.attachments,
    super.programName,
    super.programType,
    super.programTypeId,
    super.periodStart,
    super.periodEnd,
    super.estimatedCost,
  });

  final List<String> allowedActions;
  final List<SubmissionIssue> issues;
  final ReviewPlan reviewPlan;
  final List<SubmissionAttachment> attachments;

  Submission copyWith({
    int? version,
    List<SubmissionAttachment>? attachments,
    ReviewPlan? reviewPlan,
  }) => Submission(
    id: id,
    programNumber: programNumber,
    status: status,
    locations: locations,
    locationIds: locationIds,
    version: version ?? this.version,
    allowedActions: allowedActions,
    issues: issues,
    reviewPlan: reviewPlan ?? this.reviewPlan,
    attachments: attachments ?? this.attachments,
    programName: programName,
    programType: programType,
    programTypeId: programTypeId,
    periodStart: periodStart,
    periodEnd: periodEnd,
    estimatedCost: estimatedCost,
  );

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
      reviewPlan: ReviewPlan.fromJson(
        json['reviewPlan'] is Map
            ? Map<String, dynamic>.from(json['reviewPlan'] as Map)
            : const {},
      ),
      attachments: (json['attachments'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map(
            (attachment) => SubmissionAttachment.fromJson(
              Map<String, dynamic>.from(attachment),
            ),
          )
          .toList(growable: false),
    );
  }
}

class SubmissionAttachment {
  const SubmissionAttachment({
    required this.id,
    required this.submissionId,
    required this.fileName,
    required this.contentType,
    required this.sizeBytes,
    required this.scanStatus,
    required this.uploadedAt,
  });

  final String id;
  final String submissionId;
  final String fileName;
  final String contentType;
  final int sizeBytes;
  final String scanStatus;
  final String uploadedAt;

  factory SubmissionAttachment.fromJson(Map<String, dynamic> json) =>
      SubmissionAttachment(
        id: json['id'] as String? ?? '',
        submissionId: json['submissionId'] as String? ?? '',
        fileName: json['fileName'] as String? ?? 'Lampiran',
        contentType: json['contentType'] as String? ?? '',
        sizeBytes: json['sizeBytes'] as int? ?? 0,
        scanStatus: json['scanStatus'] as String? ?? 'pending',
        uploadedAt: json['uploadedAt'] as String? ?? '',
      );

  String get extension {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? 'FILE' : fileName.substring(dot + 1).toUpperCase();
  }
}

class AttachmentUploadResult {
  const AttachmentUploadResult({
    required this.attachment,
    required this.submissionVersion,
  });

  final SubmissionAttachment attachment;
  final int submissionVersion;

  factory AttachmentUploadResult.fromJson(Map<String, dynamic> json) {
    final attachment = json['attachment'];
    if (attachment is! Map) {
      throw const FormatException('Upload response is missing its attachment.');
    }
    return AttachmentUploadResult(
      attachment: SubmissionAttachment.fromJson(
        Map<String, dynamic>.from(attachment),
      ),
      submissionVersion: json['submissionVersion'] as int? ?? 0,
    );
  }
}

class AttachmentRemovalResult {
  const AttachmentRemovalResult({
    required this.attachmentId,
    required this.submissionVersion,
  });

  final String attachmentId;
  final int submissionVersion;

  factory AttachmentRemovalResult.fromJson(Map<String, dynamic> json) {
    if (json['attachmentId'] is! String || json['removed'] != true) {
      throw const FormatException('Attachment removal was not confirmed.');
    }
    return AttachmentRemovalResult(
      attachmentId: json['attachmentId'] as String,
      submissionVersion: json['submissionVersion'] as int? ?? 0,
    );
  }
}

class ReviewPlan {
  const ReviewPlan({
    required this.acknowledgers,
    required this.approvers,
    this.checker,
  });

  final PolicyPerson? checker;
  final List<PolicyPerson> acknowledgers;
  final List<PolicyPerson> approvers;

  factory ReviewPlan.fromJson(Map<String, dynamic> json) {
    List<PolicyPerson> people(String key) =>
        (json[key] as List<dynamic>? ?? const [])
            .whereType<Map>()
            .map(
              (person) =>
                  PolicyPerson.fromJson(Map<String, dynamic>.from(person)),
            )
            .toList(growable: false);
    final checker = json['checker'];
    return ReviewPlan(
      checker: checker is Map
          ? PolicyPerson.fromJson(Map<String, dynamic>.from(checker))
          : null,
      acknowledgers: people('acknowledgers'),
      approvers: people('approvers'),
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

enum ReviewerStage {
  acknowledgement('acknowledgement'),
  approval('approval');

  const ReviewerStage(this.apiValue);
  final String apiValue;

  static ReviewerStage? fromApiValue(String value) => switch (value) {
    'acknowledgement' => ReviewerStage.acknowledgement,
    'approval' => ReviewerStage.approval,
    _ => null,
  };
}

class ReviewerOption {
  const ReviewerOption({required this.person, required this.eligibleStages});

  final PolicyPerson person;
  final List<ReviewerStage> eligibleStages;

  factory ReviewerOption.fromJson(Map<String, dynamic> json) {
    final person = json['person'];
    if (person is! Map) {
      throw const FormatException('Reviewer option is missing its person.');
    }
    return ReviewerOption(
      person: PolicyPerson.fromJson(Map<String, dynamic>.from(person)),
      eligibleStages: (json['eligibleStages'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .map(ReviewerStage.fromApiValue)
          .whereType<ReviewerStage>()
          .toList(growable: false),
    );
  }
}

class ReviewerPage {
  const ReviewerPage({
    required this.items,
    required this.page,
    required this.totalPages,
    required this.totalItems,
  });

  final List<ReviewerOption> items;
  final int page;
  final int totalPages;
  final int totalItems;
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
