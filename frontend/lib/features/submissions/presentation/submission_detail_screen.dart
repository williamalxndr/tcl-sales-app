import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/platform/downloaded_file_saver.dart';
import '../domain/submission.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/async_state_panel.dart';
import '../../../core/ui/display_formatters.dart';
import 'submission_status_badge.dart';
import 'submission_attachment_list.dart';
import 'submission_review_progress.dart';

class SubmissionDetailScreen extends ConsumerStatefulWidget {
  const SubmissionDetailScreen({super.key, required this.submissionId});
  final String submissionId;

  @override
  ConsumerState<SubmissionDetailScreen> createState() =>
      _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState
    extends ConsumerState<SubmissionDetailScreen> {
  late Future<_SubmissionDetailData> _future;
  String? _downloadingAttachmentId;
  bool _downloadingPdf = false;
  bool _submitting = false;
  bool _cancelling = false;
  ApiException? _submitFailure;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_SubmissionDetailData> _load() async {
    final repository = ref.read(submissionRepositoryProvider);
    final submission = await repository.get(widget.submissionId);
    final policy = submission.status == 'draft'
        ? await repository.policy(widget.submissionId)
        : null;
    return _SubmissionDetailData(submission: submission, policy: policy);
  }

  Future<void> _downloadAttachment(SubmissionAttachment attachment) async {
    setState(() => _downloadingAttachmentId = attachment.id);
    try {
      final download = await ref
          .read(submissionRepositoryProvider)
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

  Future<void> _downloadPdf(Submission submission) async {
    setState(() => _downloadingPdf = true);
    try {
      final download = await ref
          .read(submissionRepositoryProvider)
          .downloadPdf(submission.id, submission.programNumber);
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
          const SnackBar(content: Text('PDF tidak dapat disimpan.')),
        );
      }
    } finally {
      if (mounted) setState(() => _downloadingPdf = false);
    }
  }

  Future<void> _submit(Submission submission) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Kirim pengajuan?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pengajuan ${submission.programNumber} akan dikirim ke checker dan tidak dapat diubah selama proses pemeriksaan.',
              style: const TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F9FA),
                border: Border.all(color: const Color(0xFFE9EDF1)),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  _SubmitSummaryRow(
                    label: 'Program',
                    value: submission.programName ?? 'Belum diisi',
                    emphasized: true,
                  ),
                  _SubmitSummaryRow(
                    label: 'Lokasi',
                    value: submission.locations.isEmpty
                        ? 'Belum dipilih'
                        : submission.locations.join(', '),
                  ),
                  _SubmitSummaryRow(
                    label: 'Checker',
                    value:
                        submission.reviewPlan.checker?.fullName ??
                        'Belum ditetapkan',
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Ya, kirim'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() {
      _submitting = true;
      _submitFailure = null;
    });
    try {
      final submitted = await ref
          .read(submissionRepositoryProvider)
          .submitDraft(submission.id, submission.version);
      if (!mounted) return;
      setState(() {
        _future = Future.value(_SubmissionDetailData(submission: submitted));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan berhasil dikirim.')),
      );
    } on ApiException catch (error) {
      if (mounted) {
        setState(() => _submitFailure = error);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _cancel(Submission submission) async {
    var reason = '';
    final confirmedReason = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Batalkan pengajuan?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${submission.programNumber} akan ditutup dan task pemeriksaan yang tersisa akan dibatalkan.',
                style: const TextStyle(color: AppColors.muted, height: 1.5),
              ),
              const SizedBox(height: 16),
              TextField(
                autofocus: true,
                minLines: 3,
                maxLines: 5,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Alasan pembatalan',
                  hintText: 'Jelaskan alasan pengajuan dibatalkan',
                  alignLabelWithHint: true,
                ),
                onChanged: (value) => setDialogState(() => reason = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Kembali'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF9C4030),
              ),
              onPressed: reason.trim().isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(reason.trim()),
              child: const Text('Batalkan pengajuan'),
            ),
          ],
        ),
      ),
    );
    if (confirmedReason == null || !mounted) return;

    setState(() {
      _cancelling = true;
      _submitFailure = null;
    });
    try {
      final cancelled = await ref
          .read(submissionRepositoryProvider)
          .cancelSubmission(
            submission.id,
            reason: confirmedReason,
            version: submission.version,
          );
      if (!mounted) return;
      setState(() {
        _future = Future.value(_SubmissionDetailData(submission: cancelled));
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pengajuan berhasil dibatalkan.')),
      );
    } on ApiException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 60),
          child: FutureBuilder<_SubmissionDetailData>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const AppLoadingState(
                  message: 'Memuat detail pengajuan…',
                );
              }
              if (snapshot.hasError) {
                return AppErrorState(
                  error: snapshot.error,
                  fallbackMessage: 'Detail pengajuan tidak dapat dimuat.',
                  onRetry: () => setState(() => _future = _load()),
                );
              }
              final result = snapshot.requireData;
              final item = result.submission;
              return ListView(
                children: [
                  TextButton.icon(
                    onPressed: () {
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/submissions');
                      }
                    },
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Kembali ke daftar'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      SubmissionStatusBadge(status: item.status),
                      const Spacer(),
                      OutlinedButton.icon(
                        onPressed:
                            item.allowedActions.contains('downloadPdf') &&
                                !_downloadingPdf &&
                                _downloadingAttachmentId == null &&
                                !_cancelling
                            ? () => _downloadPdf(item)
                            : null,
                        icon: _downloadingPdf
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(
                                Icons.picture_as_pdf_outlined,
                                size: 17,
                              ),
                        label: Text(
                          _downloadingPdf ? 'Menyiapkan PDF…' : 'Unduh PDF',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (result.policy != null) ...[
                    _PolicySummary(policy: result.policy!),
                    const SizedBox(height: 16),
                  ],
                  if (item.status != 'draft') ...[
                    SubmissionReviewProgress(submission: item),
                    const SizedBox(height: 16),
                  ],
                  if (_submitFailure case final ApiException error) ...[
                    _SubmitFailureCard(error: error),
                    const SizedBox(height: 16),
                  ],
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(4),
                      side: const BorderSide(color: Color(0xFFDFE4E9)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(34, 36, 34, 34),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 42,
                                height: 42,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: AppColors.navy,
                                  borderRadius: BorderRadius.circular(5),
                                ),
                                child: const Text(
                                  'P',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 19,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'PT TOTAL CHEMINDO LOKA',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: .2,
                                      ),
                                    ),
                                    Text(
                                      'Divisi Sales & Marketing',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const Divider(
                            height: 30,
                            thickness: 2,
                            color: AppColors.ink,
                          ),
                          const Center(
                            child: Column(
                              children: [
                                Text(
                                  'FORMULIR PENGAJUAN PROGRAM',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: .6,
                                    decoration: TextDecoration.underline,
                                  ),
                                ),
                                SizedBox(height: 7),
                              ],
                            ),
                          ),
                          Center(
                            child: Text(
                              'Nomor: ${item.programNumber}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                                fontFamily: 'monospace',
                              ),
                            ),
                          ),
                          const SizedBox(height: 28),
                          _DetailRow(
                            label: 'Nama Program',
                            value: item.programName ?? 'Belum diisi',
                            emphasis: true,
                          ),
                          _DetailRow(
                            label: 'Jenis program',
                            value: item.programType ?? 'Belum dipilih',
                          ),
                          _DetailRow(
                            label: 'Lokasi',
                            value: item.locations.isEmpty
                                ? 'Belum dipilih'
                                : item.locations.join(', '),
                          ),
                          _DetailRow(
                            label: 'Periode pelaksanaan',
                            value: item.periodLabel,
                          ),
                          _DetailRow(
                            label: 'Estimasi biaya',
                            value: item.estimatedCost == null
                                ? 'Belum diisi'
                                : 'Rp ${item.estimatedCost}',
                          ),
                          _DetailRow(
                            label: 'Tanggal pengajuan',
                            value: formatApiDateTime(
                              item.submittedAt,
                              fallback: 'Belum dikirim',
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Dengan ini kami mengajukan program di atas untuk mendapatkan pemeriksaan dan persetujuan sesuai ketentuan yang berlaku.',
                            style: TextStyle(
                              color: Color(0xFF2B3640),
                              height: 1.7,
                            ),
                          ),
                          const SizedBox(height: 28),
                          const Text(
                            'LAMPIRAN',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .6,
                              color: AppColors.faint,
                            ),
                          ),
                          const SizedBox(height: 9),
                          SubmissionAttachmentList(
                            attachments: item.attachments,
                            onDownload: _downloadingPdf || _cancelling
                                ? null
                                : _downloadAttachment,
                            downloadingAttachmentId: _downloadingAttachmentId,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (item.issues.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SubmissionBlockers(issues: item.issues),
                  ],
                  const SizedBox(height: 20),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      if (item.allowedActions.contains('update'))
                        OutlinedButton.icon(
                          onPressed: _submitting || _cancelling
                              ? null
                              : () =>
                                    context.go('/submissions/${item.id}/edit'),
                          icon: const Icon(Icons.edit_outlined),
                          label: const Text('Lengkapi draft'),
                        ),
                      if (item.allowedActions.contains('cancel'))
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF9C4030),
                            side: const BorderSide(color: Color(0xFFD7A59C)),
                          ),
                          onPressed: _cancelling || _submitting
                              ? null
                              : () => _cancel(item),
                          icon: _cancelling
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.block_outlined, size: 18),
                          label: Text(
                            _cancelling ? 'Membatalkan…' : 'Batalkan pengajuan',
                          ),
                        ),
                      if (item.allowedActions.contains('submit'))
                        FilledButton.icon(
                          onPressed: _submitting || _cancelling
                              ? null
                              : () => _submit(item),
                          icon: _submitting
                              ? const SizedBox(
                                  width: 17,
                                  height: 17,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.send_outlined, size: 18),
                          label: Text(
                            _submitting ? 'Mengirim…' : 'Kirim pengajuan',
                          ),
                        ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _SubmissionDetailData {
  const _SubmissionDetailData({required this.submission, this.policy});
  final Submission submission;
  final SubmissionPolicy? policy;
}

class _SubmitSummaryRow extends StatelessWidget {
  const _SubmitSummaryRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 82,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: emphasized ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    ),
  );
}

class _SubmitFailureCard extends StatelessWidget {
  const _SubmitFailureCard({required this.error});

  final ApiException error;

  @override
  Widget build(BuildContext context) {
    final details = error.details
        .map(
          (detail) => SubmissionIssue(
            field: detail.field,
            code: detail.code,
            message: detail.message,
          ),
        )
        .toList(growable: false);
    return Semantics(
      liveRegion: true,
      container: true,
      label: 'Pengajuan gagal dikirim. ${error.message}',
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 15),
        decoration: BoxDecoration(
          color: const Color(0xFFFFF7F5),
          border: Border.all(color: const Color(0xFFF0D2CC)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Row(
              children: [
                Icon(Icons.error_outline, size: 20, color: Color(0xFF9C4030)),
                SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Pengajuan belum dapat dikirim',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF843728),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 5),
            Text(
              error.message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.45,
                color: AppColors.muted,
              ),
            ),
            if (details.isNotEmpty) ...[
              const SizedBox(height: 10),
              ...details.map(
                (detail) => Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 6),
                        child: Icon(
                          Icons.circle,
                          size: 5,
                          color: Color(0xFF9C4030),
                        ),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: '${detail.fieldLabel}: ',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(text: detail.message),
                            ],
                          ),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SubmissionBlockers extends StatelessWidget {
  const _SubmissionBlockers({required this.issues});
  final List<SubmissionIssue> issues;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${issues.length} hal yang perlu dilengkapi sebelum pengajuan dikirim',
    child: Card(
      color: const Color(0xFFFFF8E8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.info_outline,
                  size: 19,
                  color: Color(0xFF855A08),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Belum siap dikirim',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                Text(
                  '${issues.length} blocker',
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF855A08),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Lengkapi ketentuan berikut sebelum pengajuan dapat diproses.',
              style: TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
            const SizedBox(height: 10),
            ...issues.map(
              (issue) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Icon(
                        Icons.circle,
                        size: 5,
                        color: Color(0xFF855A08),
                      ),
                    ),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            issue.fieldLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: .25,
                              color: Color(0xFF855A08),
                            ),
                          ),
                          Text(
                            issue.message,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _PolicySummary extends StatelessWidget {
  const _PolicySummary({required this.policy});
  final SubmissionPolicy policy;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'RUTE PEMERIKSAAN',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              letterSpacing: .6,
              color: AppColors.faint,
            ),
          ),
          const SizedBox(height: 11),
          _PolicyRow(
            label: 'Checker',
            value: policy.routingConfigured && policy.checker != null
                ? '${policy.checker!.fullName}${policy.checker!.jobTitle == null ? '' : ' · ${policy.checker!.jobTitle}'}'
                : 'Belum dikonfigurasi',
            alert: !policy.routingConfigured || policy.checker == null,
          ),
          _PolicyRow(
            label: 'Mengetahui',
            value:
                '${policy.minAcknowledgers}–${policy.maxAcknowledgers} orang',
          ),
          _PolicyRow(
            label: 'Persetujuan',
            value: '${policy.minApprovers}–${policy.maxApprovers} orang',
          ),
          _PolicyRow(
            label: 'Lampiran',
            value:
                '${policy.allowedAttachmentExtensions.join(', ')} · ${_megabytes(policy.maxAttachmentBytes)} MB maks.',
          ),
        ],
      ),
    ),
  );

  String _megabytes(int bytes) => (bytes / (1024 * 1024)).toStringAsFixed(
    bytes % (1024 * 1024) == 0 ? 0 : 1,
  );
}

class _PolicyRow extends StatelessWidget {
  const _PolicyRow({
    required this.label,
    required this.value,
    this.alert = false,
  });
  final String label;
  final String value;
  final bool alert;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 5),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: alert ? const Color(0xFF9C4030) : AppColors.ink,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.emphasis = false,
  });
  final String label;
  final String value;
  final bool emphasis;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 170,
          child: Text(label, style: const TextStyle(color: Color(0xFF5C6771))),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontWeight: emphasis ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ],
    ),
  );
}
