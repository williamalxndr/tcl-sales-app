import 'package:flutter/material.dart';

import '../../../core/ui/app_theme.dart';
import '../domain/submission.dart';

class SubmissionAttachmentList extends StatelessWidget {
  const SubmissionAttachmentList({super.key, required this.attachments});
  final List<SubmissionAttachment> attachments;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FBFC),
          border: Border.all(color: AppColors.line),
          borderRadius: BorderRadius.circular(6),
        ),
        child: const Text(
          'Belum ada lampiran.',
          style: TextStyle(fontSize: 12.5, color: AppColors.muted),
        ),
      );
    }
    return Column(
      children: attachments
          .map(
            (attachment) => Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _AttachmentRow(attachment: attachment),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({required this.attachment});
  final SubmissionAttachment attachment;

  @override
  Widget build(BuildContext context) {
    final scan = AttachmentScanVisual.from(attachment.scanStatus);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE9EDF1)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scan.background,
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text(
              attachment.extension,
              style: TextStyle(
                fontSize: 9,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                color: scan.foreground,
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  attachment.fileName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${_bytes(attachment.sizeBytes)} · ${scan.label}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.faint,
                  ),
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              color: scan.background,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Text(
                scan.label,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: scan.foreground,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _bytes(int bytes) => bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(0)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class AttachmentScanVisual {
  const AttachmentScanVisual({
    required this.label,
    required this.background,
    required this.foreground,
  });
  final String label;
  final Color background;
  final Color foreground;
  static AttachmentScanVisual from(String status) => switch (status) {
    'clean' => const AttachmentScanVisual(
      label: 'Aman',
      background: Color(0xFFE8F5ED),
      foreground: Color(0xFF2F6B48),
    ),
    'rejected' => const AttachmentScanVisual(
      label: 'Ditolak',
      background: Color(0xFFFBECEA),
      foreground: Color(0xFF9C4030),
    ),
    _ => const AttachmentScanVisual(
      label: 'Dipindai',
      background: Color(0xFFFFF4D6),
      foreground: Color(0xFF855A08),
    ),
  };
}
