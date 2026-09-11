import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/platform/downloaded_file_saver.dart';
import '../../../core/ui/app_theme.dart';
import '../../submissions/domain/submission.dart';
import '../../submissions/presentation/submission_status_badge.dart';
import '../../submissions/presentation/submission_review_progress.dart';
import '../domain/backoffice_submission.dart';

class BackofficeDetailScreen extends ConsumerStatefulWidget {
  const BackofficeDetailScreen({super.key, required this.submissionId});

  final String submissionId;

  @override
  ConsumerState<BackofficeDetailScreen> createState() =>
      _BackofficeDetailScreenState();
}

class _BackofficeDetailScreenState
    extends ConsumerState<BackofficeDetailScreen> {
  late Future<BackofficeSubmissionDetail> _future;
  String? _downloadingAttachmentId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<BackofficeSubmissionDetail> _load() =>
      ref.read(backofficeRepositoryProvider).getSubmission(widget.submissionId);

  void _reload() => setState(() => _future = _load());

  Future<void> _downloadAttachment(SubmissionAttachment attachment) async {
    setState(() => _downloadingAttachmentId = attachment.id);
    try {
      final download = await ref
          .read(backofficeRepositoryProvider)
          .downloadAttachment(widget.submissionId, attachment);
      await const DownloadedFileSaver().save(
        bytes: download.bytes,
        fileName: download.fileName,
        contentType: download.contentType,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${download.fileName} berhasil diunduh.')),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lampiran tidak dapat disimpan.')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingAttachmentId = null);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FutureBuilder<BackofficeSubmissionDetail>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _DetailError(error: snapshot.error, onRetry: _reload);
        }
        return _DetailDocument(
          detail: snapshot.requireData,
          downloadingAttachmentId: _downloadingAttachmentId,
          onDownloadAttachment: _downloadAttachment,
        );
      },
    ),
  );
}

class _DetailDocument extends StatelessWidget {
  const _DetailDocument({
    required this.detail,
    required this.downloadingAttachmentId,
    required this.onDownloadAttachment,
  });

  final BackofficeSubmissionDetail detail;
  final String? downloadingAttachmentId;
  final ValueChanged<SubmissionAttachment> onDownloadAttachment;

  @override
  Widget build(BuildContext context) {
    final item = detail.submission;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 60),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: context.pop,
                      icon: const Icon(Icons.arrow_back, size: 17),
                      label: const Text('Kembali ke daftar'),
                    ),
                    const Spacer(),
                    SubmissionStatusBadge(status: item.status),
                  ],
                ),
                const SizedBox(height: 16),
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                    side: const BorderSide(color: AppColors.line),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(48, 42, 48, 38),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'PT TOTAL CHEMINDO LOKA',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .2,
                          ),
                        ),
                        const Text(
                          'Divisi Sales & Marketing',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        const SizedBox(height: 14),
                        const Divider(thickness: 2, color: AppColors.ink),
                        const SizedBox(height: 24),
                        const Text(
                          'FORMULIR PENGAJUAN PROGRAM',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: .8,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          'Nomor: ${item.programNumber}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 30),
                        _DetailFields(detail: detail),
                        if (item.attachments.isNotEmpty) ...[
                          const SizedBox(height: 28),
                          const Text(
                            'LAMPIRAN',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .7,
                              color: AppColors.faint,
                            ),
                          ),
                          const SizedBox(height: 9),
                          ...item.attachments.map(
                            (attachment) => _AttachmentMetadata(
                              attachment,
                              downloading:
                                  downloadingAttachmentId == attachment.id,
                              onDownload:
                                  attachment.scanStatus == 'clean' &&
                                      downloadingAttachmentId == null
                                  ? () => onDownloadAttachment(attachment)
                                  : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (item.reviewTasks.isNotEmpty) ...[
                  const SizedBox(height: 18),
                  const Text(
                    'Alur pemeriksaan',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  SubmissionReviewProgress(submission: item),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DetailFields extends StatelessWidget {
  const _DetailFields({required this.detail});

  final BackofficeSubmissionDetail detail;

  @override
  Widget build(BuildContext context) {
    final item = detail.submission;
    final fields = <(String, String)>[
      ('Nama Program', item.programName ?? '—'),
      ('Jenis Program', item.programType ?? '—'),
      ('Lokasi', item.locations.isEmpty ? '—' : item.locations.join(', ')),
      ('Periode Pelaksanaan', item.periodLabel),
      ('Estimasi Biaya', _costLabel(item.estimatedCost)),
      ('Pengaju', detail.owner.fullName),
      ('Tanggal Pengajuan', detail.submittedAt ?? '—'),
    ];
    return Column(
      children: fields
          .map(
            (field) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 170,
                    child: Text(
                      field.$1,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                  const Text(':  '),
                  Expanded(
                    child: Text(
                      field.$2,
                      style: TextStyle(
                        fontWeight: field.$1 == 'Nama Program'
                            ? FontWeight.w600
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(growable: false),
    );
  }
}

class _AttachmentMetadata extends StatelessWidget {
  const _AttachmentMetadata(
    this.attachment, {
    required this.downloading,
    required this.onDownload,
  });

  final SubmissionAttachment attachment;
  final bool downloading;
  final VoidCallback? onDownload;

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 7),
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
            color: AppColors.softNavy,
            borderRadius: BorderRadius.circular(5),
          ),
          child: Text(
            attachment.extension,
            style: const TextStyle(
              fontSize: 9,
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
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
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              Text(
                '${_fileSize(attachment.sizeBytes)} · ${attachment.scanStatus}',
                style: const TextStyle(fontSize: 11.5, color: AppColors.faint),
              ),
            ],
          ),
        ),
        TextButton.icon(
          onPressed: onDownload,
          icon: downloading
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.download_outlined, size: 17),
          label: Text(downloading ? 'Mengunduh…' : 'Unduh'),
        ),
      ],
    ),
  );
}

class _DetailError extends StatelessWidget {
  const _DetailError({required this.error, required this.onRetry});

  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          error is ApiException
              ? (error as ApiException).message
              : 'Detail pengajuan tidak dapat dimuat.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
      ],
    ),
  );
}

String _costLabel(String? amount) {
  if (amount == null) return '—';
  final integer = amount.split('.').first;
  return 'Rp ${integer.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.')}';
}

String _fileSize(int bytes) {
  if (bytes >= 1048576) return '${(bytes / 1048576).toStringAsFixed(1)} MB';
  if (bytes >= 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '$bytes B';
}
