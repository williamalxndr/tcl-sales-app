import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_app/features/submissions/presentation/submission_status_badge.dart';

void main() {
  testWidgets('renders every workflow status with its Indonesian label', (
    tester,
  ) async {
    const labels = {
      'draft': 'Draft',
      'pendingChecker': 'Menunggu Checker',
      'pendingAcknowledgement': 'Menunggu Mengetahui',
      'pendingApproval': 'Menunggu Persetujuan',
      'approved': 'Disetujui',
      'rejected': 'Ditolak',
      'cancelled': 'Dibatalkan',
    };

    for (final entry in labels.entries) {
      await tester.pumpWidget(
        MaterialApp(home: SubmissionStatusBadge(status: entry.key)),
      );
      expect(find.text(entry.value), findsOneWidget);
      expect(SubmissionStatusVisual.from(entry.key).label, entry.value);
    }
  });
}
