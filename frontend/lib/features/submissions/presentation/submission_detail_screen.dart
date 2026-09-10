import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../domain/submission.dart';
import '../../../core/ui/app_theme.dart';
import 'submission_status_badge.dart';

class SubmissionDetailScreen extends ConsumerStatefulWidget {
  const SubmissionDetailScreen({super.key, required this.submissionId});
  final String submissionId;

  @override
  ConsumerState<SubmissionDetailScreen> createState() =>
      _SubmissionDetailScreenState();
}

class _SubmissionDetailScreenState
    extends ConsumerState<SubmissionDetailScreen> {
  late Future<Submission> _future;
  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Submission> _load() =>
      ref.read(submissionRepositoryProvider).get(widget.submissionId);

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 60),
          child: FutureBuilder<Submission>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Pengajuan tidak dapat dimuat.'),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () => setState(() => _future = _load()),
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ),
                );
              }
              final item = snapshot.requireData;
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
                        onPressed: null,
                        icon: const Icon(
                          Icons.picture_as_pdf_outlined,
                          size: 17,
                        ),
                        label: const Text('Unduh PDF'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
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
                          const _AttachmentPlaceholder(),
                        ],
                      ),
                    ),
                  ),
                  if (item.issues.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Yang perlu dilengkapi',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    ...item.issues.map(
                      (issue) => Card(
                        elevation: 0,
                        color: const Color(0xFFFFF8E8),
                        child: ListTile(
                          leading: const Icon(Icons.info_outline),
                          title: Text(issue.message),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (item.allowedActions.contains('update'))
                    FilledButton.icon(
                      onPressed: () =>
                          context.go('/submissions/${item.id}/edit'),
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Lengkapi draft'),
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

class _AttachmentPlaceholder extends StatelessWidget {
  const _AttachmentPlaceholder();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
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
            borderRadius: BorderRadius.all(Radius.circular(5)),
          ),
          child: Text(
            'PDF',
            style: TextStyle(
              fontSize: 9,
              fontFamily: 'monospace',
              color: AppColors.navy,
            ),
          ),
        ),
        SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dokumen pendukung',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              Text(
                'Lampiran akan tersedia setelah diunggah.',
                style: TextStyle(fontSize: 11.5, color: Color(0xFF8B929A)),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
