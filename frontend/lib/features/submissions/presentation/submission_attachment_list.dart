import 'package:flutter/material.dart';

import '../../../core/ui/app_theme.dart';
import '../domain/submission.dart';

class SubmissionAttachmentList extends StatelessWidget {
  const SubmissionAttachmentList({
    super.key,
    required this.attachments,
    this.onRemove,
    this.removingAttachmentId,
    this.onDownload,
    this.downloadingAttachmentId,
  });
  final List<SubmissionAttachment> attachments;
  final ValueChanged<SubmissionAttachment>? onRemove;
  final String? removingAttachmentId;
  final ValueChanged<SubmissionAttachment>? onDownload;
  final String? downloadingAttachmentId;

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
              child: _AttachmentRow(
                attachment: attachment,
                onRemove: onRemove,
                isRemoving: removingAttachmentId == attachment.id,
                isRemovalInProgress: removingAttachmentId != null,
                onDownload: onDownload,
                isDownloading: downloadingAttachmentId == attachment.id,
                isDownloadInProgress: downloadingAttachmentId != null,
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _AttachmentRow extends StatelessWidget {
  const _AttachmentRow({
    required this.attachment,
    required this.onRemove,
    required this.isRemoving,
    required this.isRemovalInProgress,
    required this.onDownload,
    required this.isDownloading,
    required this.isDownloadInProgress,
  });
  final SubmissionAttachment attachment;
  final ValueChanged<SubmissionAttachment>? onRemove;
  final bool isRemoving;
  final bool isRemovalInProgress;
  final ValueChanged<SubmissionAttachment>? onDownload;
  final bool isDownloading;
  final bool isDownloadInProgress;

  @override
  Widget build(BuildContext context) {
    final scan = AttachmentScanVisual.from(attachment.scanStatus);
    return Container(
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        border: Border.all(color: const Color(0xFFE9EDF1)),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Semantics(
        label: '${attachment.fileName}. Status pemindaian: ${scan.label}',
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(scan.icon, size: 12, color: scan.foreground),
                    const SizedBox(width: 4),
                    Text(
                      scan.label,
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        color: scan.foreground,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (onDownload != null && attachment.scanStatus == 'clean') ...[
              const SizedBox(width: 2),
              Semantics(
                button: true,
                label: isDownloading
                    ? 'Mengunduh ${attachment.fileName}'
                    : 'Unduh ${attachment.fileName}',
                child: IconButton(
                  tooltip: 'Unduh lampiran',
                  onPressed: isDownloadInProgress
                      ? null
                      : () => onDownload!(attachment),
                  icon: isDownloading
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.download_outlined, size: 19),
                  color: AppColors.navy,
                ),
              ),
            ],
            if (onRemove != null) ...[
              const SizedBox(width: 2),
              Semantics(
                button: true,
                label: isRemoving
                    ? 'Menghapus ${attachment.fileName}'
                    : 'Hapus ${attachment.fileName}',
                child: IconButton(
                  tooltip: 'Hapus lampiran',
                  onPressed: isRemovalInProgress
                      ? null
                      : () => onRemove!(attachment),
                  icon: isRemoving
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline, size: 19),
                  color: const Color(0xFF9C4030),
                ),
              ),
            ],
          ],
        ),
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
    required this.icon,
  });
  final String label;
  final Color background;
  final Color foreground;
  final IconData icon;
  static AttachmentScanVisual from(String status) => switch (status) {
    'clean' => const AttachmentScanVisual(
      label: 'Aman',
      background: Color(0xFFE8F5ED),
      foreground: Color(0xFF2F6B48),
      icon: Icons.verified_outlined,
    ),
    'rejected' => const AttachmentScanVisual(
      label: 'Ditolak',
      background: Color(0xFFFBECEA),
      foreground: Color(0xFF9C4030),
      icon: Icons.error_outline,
    ),
    'pending' => const AttachmentScanVisual(
      label: 'Menunggu pemindaian',
      background: Color(0xFFFFF4D6),
      foreground: Color(0xFF855A08),
      icon: Icons.schedule_outlined,
    ),
    _ => const AttachmentScanVisual(
      label: 'Status scan tidak dikenal',
      background: Color(0xFFF0F2F4),
      foreground: Color(0xFF64707A),
      icon: Icons.help_outline,
    ),
  };
}
