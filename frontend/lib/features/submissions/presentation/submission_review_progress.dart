import 'package:flutter/material.dart';

import '../../../core/ui/app_theme.dart';
import '../domain/submission.dart';

class SubmissionReviewProgress extends StatelessWidget {
  const SubmissionReviewProgress({super.key, required this.submission});

  final Submission submission;

  @override
  Widget build(BuildContext context) {
    final outcome = _OutcomeVisual.from(submission.status);
    final active = submission.reviewTasks.where((task) => task.isActive);
    final activeLabel = active.isEmpty
        ? null
        : active
              .map((task) => '${task.stageLabel} · ${task.reviewer.fullName}')
              .join(', ');
    return Semantics(
      container: true,
      label: activeLabel == null
          ? outcome.title
          : '${outcome.title}. Task aktif: $activeLabel',
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 17, 18, 16),
        decoration: BoxDecoration(
          color: outcome.background,
          border: Border.all(color: outcome.border),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: outcome.iconBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    outcome.icon,
                    size: 18,
                    color: outcome.foreground,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        outcome.title,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: outcome.foreground,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        activeLabel == null
                            ? outcome.description
                            : 'Task aktif: $activeLabel',
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (submission.reviewTasks.isNotEmpty) ...[
              const SizedBox(height: 15),
              const Divider(height: 1),
              const SizedBox(height: 7),
              ...submission.reviewTasks.map(
                (task) => _ReviewTaskRow(task: task),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReviewTaskRow extends StatelessWidget {
  const _ReviewTaskRow({required this.task});

  final SubmissionReviewTask task;

  @override
  Widget build(BuildContext context) {
    final visual = _TaskVisual.from(task.status);
    final stage = task.stage == 'checker'
        ? task.stageLabel
        : '${task.stageLabel} ${task.position}';
    return Padding(
      padding: const EdgeInsets.only(top: 9),
      child: Row(
        children: [
          Icon(visual.icon, size: 18, color: visual.foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$stage · ${task.reviewer.fullName}',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (task.note case final String note when note.isNotEmpty)
                  Text(
                    '“$note”',
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.muted,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                if (task.decidedAt case final String decidedAt
                    when decidedAt.isNotEmpty)
                  Text(
                    _decisionTime(decidedAt),
                    style: const TextStyle(
                      fontSize: 10.5,
                      color: AppColors.faint,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            task.statusLabel,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: visual.foreground,
            ),
          ),
        ],
      ),
    );
  }
}

String _decisionTime(String value) {
  final date = DateTime.tryParse(value)?.toLocal();
  if (date == null) return value;
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year} '
      '${two(date.hour)}:${two(date.minute)}';
}

class _OutcomeVisual {
  const _OutcomeVisual({
    required this.title,
    required this.description,
    required this.background,
    required this.border,
    required this.iconBackground,
    required this.foreground,
    required this.icon,
  });

  final String title;
  final String description;
  final Color background;
  final Color border;
  final Color iconBackground;
  final Color foreground;
  final IconData icon;

  static _OutcomeVisual from(String status) => switch (status) {
    'approved' => const _OutcomeVisual(
      title: 'Pengajuan disetujui',
      description: 'Seluruh rangkaian pemeriksaan telah selesai.',
      background: Color(0xFFF4FAF6),
      border: Color(0xFFCDE4D5),
      iconBackground: Color(0xFFE1F1E7),
      foreground: Color(0xFF2F6B48),
      icon: Icons.check_rounded,
    ),
    'rejected' => const _OutcomeVisual(
      title: 'Pengajuan ditolak',
      description: 'Lihat catatan reviewer pada tahapan pemeriksaan.',
      background: Color(0xFFFFF7F5),
      border: Color(0xFFF0D2CC),
      iconBackground: Color(0xFFFBE5E1),
      foreground: Color(0xFF9C4030),
      icon: Icons.close_rounded,
    ),
    'cancelled' => const _OutcomeVisual(
      title: 'Pengajuan dibatalkan',
      description: 'Proses pemeriksaan untuk pengajuan ini telah dihentikan.',
      background: Color(0xFFF7F8F9),
      border: Color(0xFFDDE2E6),
      iconBackground: Color(0xFFE9EDF1),
      foreground: Color(0xFF64707A),
      icon: Icons.block_outlined,
    ),
    _ => const _OutcomeVisual(
      title: 'Pengajuan berhasil dikirim',
      description: 'Pengajuan sedang menunggu proses pemeriksaan berikutnya.',
      background: Color(0xFFF3F7FA),
      border: Color(0xFFD4E1E8),
      iconBackground: Color(0xFFE1ECF2),
      foreground: AppColors.navy,
      icon: Icons.outbox_outlined,
    ),
  };
}

class _TaskVisual {
  const _TaskVisual({required this.icon, required this.foreground});

  final IconData icon;
  final Color foreground;

  static _TaskVisual from(String status) => switch (status) {
    'ready' => const _TaskVisual(
      icon: Icons.radio_button_checked,
      foreground: Color(0xFF28618D),
    ),
    'approved' => const _TaskVisual(
      icon: Icons.check_circle_outline,
      foreground: Color(0xFF2F6B48),
    ),
    'rejected' => const _TaskVisual(
      icon: Icons.cancel_outlined,
      foreground: Color(0xFF9C4030),
    ),
    'voided' => const _TaskVisual(
      icon: Icons.block_outlined,
      foreground: Color(0xFF7C8791),
    ),
    _ => const _TaskVisual(
      icon: Icons.circle_outlined,
      foreground: Color(0xFFA0A8AF),
    ),
  };
}
