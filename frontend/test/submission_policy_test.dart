import 'package:flutter_test/flutter_test.dart';
import 'package:sales_app/features/submissions/domain/submission.dart';

void main() {
  test('parses the server-resolved draft policy', () {
    final policy = SubmissionPolicy.fromJson({
      'policyVersion': 'policy_example_1',
      'checker': {
        'id': 'usr_andi',
        'fullName': 'Andi Setiawan',
        'jobTitle': 'Supervisor Sales',
      },
      'minAcknowledgers': 1,
      'maxAcknowledgers': 2,
      'minApprovers': 1,
      'maxApprovers': 3,
      'allowedAttachmentExtensions': ['.pdf', '.xlsx'],
      'maxAttachmentBytes': 10000000,
      'routingConfigured': true,
    });

    expect(policy.checker?.fullName, 'Andi Setiawan');
    expect(policy.minAcknowledgers, 1);
    expect(policy.maxApprovers, 3);
    expect(policy.allowedAttachmentExtensions, ['.pdf', '.xlsx']);
    expect(policy.routingConfigured, isTrue);
  });

  test('maps submission issue fields to user-facing labels', () {
    final issue = SubmissionIssue.fromJson({
      'field': 'estimatedCost',
      'code': 'REQUIRED',
      'message': 'Estimated cost is required.',
    });

    expect(issue.fieldLabel, 'Estimasi biaya');
  });

  test('keeps reviewer order from the server review plan', () {
    final plan = ReviewPlan.fromJson({
      'checker': null,
      'acknowledgers': [
        {'id': 'usr_dewi', 'fullName': 'Dewi Larasati'},
        {'id': 'usr_rahmat', 'fullName': 'Rahmat Hidayat'},
      ],
      'approvers': [
        {'id': 'usr_ratna', 'fullName': 'Ratna Kusuma'},
      ],
    });

    expect(plan.acknowledgers.map((person) => person.id), [
      'usr_dewi',
      'usr_rahmat',
    ]);
    expect(plan.approvers.single.id, 'usr_ratna');
  });

  test('parses attachment metadata returned with a submission', () {
    final attachment = SubmissionAttachment.fromJson({
      'id': 'att_proposal',
      'submissionId': 'sub_0144',
      'fileName': 'Proposal Program.pdf',
      'contentType': 'application/pdf',
      'sizeBytes': 1800000,
      'scanStatus': 'clean',
      'uploadedAt': '2026-08-21T03:06:00Z',
    });

    expect(attachment.extension, 'PDF');
    expect(attachment.scanStatus, 'clean');
  });

  test('rejects attachment payloads without an API file name', () {
    expect(
      () => SubmissionAttachment.fromJson({
        'id': 'att_proposal',
        'submissionId': 'sub_0144',
        'contentType': 'application/pdf',
        'sizeBytes': 1800000,
        'scanStatus': 'clean',
        'uploadedAt': '2026-08-21T03:06:00Z',
      }),
      throwsA(anything),
    );
  });

  test('parses an attachment upload result and its new submission version', () {
    final result = AttachmentUploadResult.fromJson({
      'attachment': {
        'id': 'att_proposal',
        'submissionId': 'sub_0144',
        'fileName': 'Proposal Program.pdf',
        'contentType': 'application/pdf',
        'sizeBytes': 1800000,
        'scanStatus': 'pending',
        'uploadedAt': '2026-08-21T03:06:00Z',
      },
      'submissionVersion': 3,
    });

    expect(result.attachment.id, 'att_proposal');
    expect(result.submissionVersion, 3);
  });
}
