import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sales_app/core/ui/app_theme.dart';
import 'package:sales_app/core/ui/async_state_panel.dart';
import 'package:sales_app/features/submissions/presentation/submission_status_badge.dart';

void main() {
  test('all submission status colors meet WCAG AA text contrast', () {
    for (final status in const [
      'draft',
      'pendingChecker',
      'pendingAcknowledgement',
      'pendingApproval',
      'approved',
      'rejected',
      'cancelled',
    ]) {
      final visual = SubmissionStatusVisual.from(status);
      expect(
        _contrast(visual.foreground, visual.background),
        greaterThanOrEqualTo(4.5),
        reason: '${visual.label} harus memenuhi kontras WCAG AA',
      );
    }
  });

  testWidgets('status and errors expose useful screen-reader labels', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(),
        home: Scaffold(
          body: Column(
            children: [
              const SubmissionStatusBadge(status: 'pendingApproval'),
              Expanded(
                child: AppErrorState(
                  error: Exception('offline'),
                  fallbackMessage: 'Koneksi ke server terputus.',
                  onRetry: () {},
                ),
              ),
            ],
          ),
        ),
      ),
    );

    final status = _semanticsLabel('Status pengajuan: Menunggu Persetujuan');
    final error = _semanticsLabel(
      'Terjadi kesalahan. Koneksi ke server terputus.',
    );
    expect(status, findsOneWidget);
    expect(error, findsOneWidget);
    expect(tester.widget<Semantics>(error).properties.liveRegion, isTrue);
    expect(find.text('Coba lagi'), findsOneWidget);
    semantics.dispose();
  });
}

Finder _semanticsLabel(String label) => find.byWidgetPredicate(
  (widget) => widget is Semantics && widget.properties.label == label,
);

double _contrast(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first.computeLuminance()
      : second.computeLuminance();
  final darker = first.computeLuminance() > second.computeLuminance()
      ? second.computeLuminance()
      : first.computeLuminance();
  return (lighter + .05) / (darker + .05);
}
