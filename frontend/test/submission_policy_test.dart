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
      'approvers': [],
    });

    expect(plan.acknowledgers.map((person) => person.id), [
      'usr_dewi',
      'usr_rahmat',
    ]);
  });
}
