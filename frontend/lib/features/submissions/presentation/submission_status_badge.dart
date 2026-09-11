import 'package:flutter/material.dart';

import '../../../core/ui/app_theme.dart';

class SubmissionStatusBadge extends StatelessWidget {
  const SubmissionStatusBadge({
    super.key,
    required this.status,
    this.compact = false,
  });

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final visual = SubmissionStatusVisual.from(status);
    return Semantics(
      container: true,
      label: 'Status pengajuan: ${visual.label}',
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: visual.background,
            border: Border.all(color: visual.foreground.withValues(alpha: .2)),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 9 : 11,
              vertical: 4,
            ),
            child: Text(
              visual.label,
              style: TextStyle(
                fontSize: compact ? 11.5 : 12,
                fontWeight: FontWeight.w600,
                color: visual.foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SubmissionStatusVisual {
  const SubmissionStatusVisual({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  static SubmissionStatusVisual from(String status) => switch (status) {
    'draft' => const SubmissionStatusVisual(
      label: 'Draft',
      background: Color(0xFFE9EDF1),
      foreground: Color(0xFF59646E),
    ),
    'pendingChecker' => const SubmissionStatusVisual(
      label: 'Menunggu Checker',
      background: Color(0xFFFFF4D6),
      foreground: Color(0xFF855A08),
    ),
    'pendingAcknowledgement' => const SubmissionStatusVisual(
      label: 'Menunggu Mengetahui',
      background: Color(0xFFE7F0F8),
      foreground: Color(0xFF28618D),
    ),
    'pendingApproval' => const SubmissionStatusVisual(
      label: 'Menunggu Persetujuan',
      background: Color(0xFFEEEAF9),
      foreground: Color(0xFF59428E),
    ),
    'approved' => const SubmissionStatusVisual(
      label: 'Disetujui',
      background: Color(0xFFE8F5ED),
      foreground: Color(0xFF2F6B48),
    ),
    'rejected' => const SubmissionStatusVisual(
      label: 'Ditolak',
      background: Color(0xFFFBECEA),
      foreground: Color(0xFF9C4030),
    ),
    'cancelled' => const SubmissionStatusVisual(
      label: 'Dibatalkan',
      background: Color(0xFFF0F2F4),
      foreground: Color(0xFF64707A),
    ),
    _ => SubmissionStatusVisual(
      label: status,
      background: AppColors.softNavy,
      foreground: AppColors.navy,
    ),
  };
}
