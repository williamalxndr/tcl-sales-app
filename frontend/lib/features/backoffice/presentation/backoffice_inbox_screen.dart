import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_exception.dart';
import '../../../core/ui/app_theme.dart';
import '../../submissions/presentation/submission_status_badge.dart';
import '../domain/backoffice_submission.dart';

class BackofficeInboxScreen extends ConsumerStatefulWidget {
  const BackofficeInboxScreen({super.key});

  @override
  ConsumerState<BackofficeInboxScreen> createState() =>
      _BackofficeInboxScreenState();
}

class _BackofficeInboxScreenState extends ConsumerState<BackofficeInboxScreen> {
  late Future<BackofficeSubmissionPage> _future;
  var _page = 1;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<BackofficeSubmissionPage> _load() =>
      ref.read(backofficeRepositoryProvider).listInbox(page: _page);

  void _reload({bool firstPage = false}) => setState(() {
    if (firstPage) _page = 1;
    _future = _load();
  });

  void _goToPage(int page, int totalPages) {
    if (page < 1 || page > totalPages || page == _page) return;
    setState(() {
      _page = page;
      _future = _load();
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1360),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 26, 28, 60),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Backoffice',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              const Text(
                'Pengajuan yang sedang menunggu tindakan Anda.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: FutureBuilder<BackofficeSubmissionPage>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _InboxError(
                        error: snapshot.error,
                        onRetry: () => _reload(),
                      );
                    }
                    final result = snapshot.requireData;
                    if (result.items.isEmpty) {
                      return _EmptyInbox(onRefresh: () => _reload());
                    }
                    return Column(
                      children: [
                        Expanded(child: _InboxTable(items: result.items)),
                        const SizedBox(height: 12),
                        _InboxPagination(
                          page: result.page,
                          totalPages: result.totalPages,
                          totalItems: result.totalItems,
                          onPageSelected: (page) =>
                              _goToPage(page, result.totalPages),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _InboxTable extends StatelessWidget {
  const _InboxTable({required this.items});

  final List<BackofficeSubmissionSummary> items;

  @override
  Widget build(BuildContext context) => Card(
    clipBehavior: Clip.antiAlias,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
          child: Row(
            children: [
              const Text(
                'Inbox reviewer',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 10),
              Text(
                '${items.length} ditampilkan',
                style: const TextStyle(fontSize: 12, color: AppColors.faint),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: 1180,
              child: Column(
                children: [
                  const _InboxHeader(),
                  Expanded(
                    child: ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (_, index) => _InboxRow(item: items[index]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

const _columns = <int>[120, 280, 120, 130, 170, 130, 130, 100];

class _InboxHeader extends StatelessWidget {
  const _InboxHeader();

  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFF9FBFC),
    height: 38,
    child: const Row(
      children: [
        _Cell(width: 120, child: _HeaderText('No.')),
        _Cell(width: 280, child: _HeaderText('Program')),
        _Cell(width: 120, child: _HeaderText('Jenis')),
        _Cell(width: 130, child: _HeaderText('Lokasi')),
        _Cell(width: 170, child: _HeaderText('Pengaju')),
        _Cell(width: 130, child: _HeaderText('Biaya', alignRight: true)),
        _Cell(width: 130, child: _HeaderText('Peran saya')),
        _Cell(width: 100, child: _HeaderText('Status')),
      ],
    ),
  );
}

class _InboxRow extends StatelessWidget {
  const _InboxRow({required this.item});

  final BackofficeSubmissionSummary item;

  @override
  Widget build(BuildContext context) {
    final submission = item.submission;
    return SizedBox(
      height: 68,
      child: Row(
        children: [
          _Cell(
            width: _columns[0].toDouble(),
            child: Text(
              submission.programNumber,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.muted,
                fontFamily: 'monospace',
              ),
            ),
          ),
          _Cell(
            width: _columns[1].toDouble(),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  submission.programName ?? 'Nama program belum tersedia',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.navy,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  submission.periodLabel,
                  style: const TextStyle(fontSize: 12, color: AppColors.faint),
                ),
              ],
            ),
          ),
          _Cell(
            width: _columns[2].toDouble(),
            child: Text(submission.programType ?? '—'),
          ),
          _Cell(
            width: _columns[3].toDouble(),
            child: Text(submission.locations.join(', ')),
          ),
          _Cell(
            width: _columns[4].toDouble(),
            child: Text(item.owner.fullName),
          ),
          _Cell(
            width: _columns[5].toDouble(),
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(_costLabel(submission.estimatedCost)),
            ),
          ),
          _Cell(
            width: _columns[6].toDouble(),
            child: Align(
              alignment: Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: const Color(0xFFEEF3F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  child: Text(
                    _stageLabel(item.currentStage),
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColors.navy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          _Cell(
            width: _columns[7].toDouble(),
            child: SubmissionStatusBadge(status: submission.status),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.width, required this.child});

  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: child,
    ),
  );
}

class _HeaderText extends StatelessWidget {
  const _HeaderText(this.text, {this.alignRight = false});

  final String text;
  final bool alignRight;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
    child: Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: .3,
        color: AppColors.faint,
        fontWeight: FontWeight.w700,
      ),
    ),
  );
}

class _InboxPagination extends StatelessWidget {
  const _InboxPagination({
    required this.page,
    required this.totalPages,
    required this.totalItems,
    required this.onPageSelected,
  });

  final int page;
  final int totalPages;
  final int totalItems;
  final ValueChanged<int> onPageSelected;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          '$totalItems pengajuan · Halaman $page dari $totalPages',
          style: const TextStyle(fontSize: 12, color: AppColors.faint),
        ),
      ),
      OutlinedButton.icon(
        onPressed: page > 1 ? () => onPageSelected(page - 1) : null,
        icon: const Icon(Icons.chevron_left, size: 18),
        label: const Text('Sebelumnya'),
      ),
      const SizedBox(width: 8),
      OutlinedButton.icon(
        onPressed: page < totalPages ? () => onPageSelected(page + 1) : null,
        icon: const Icon(Icons.chevron_right, size: 18),
        label: const Text('Berikutnya'),
      ),
    ],
  );
}

class _EmptyInbox extends StatelessWidget {
  const _EmptyInbox({required this.onRefresh});

  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.task_alt, size: 38, color: AppColors.navy),
        const SizedBox(height: 12),
        const Text(
          'Tidak ada pengajuan yang menunggu Anda.',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: onRefresh, child: const Text('Muat ulang')),
      ],
    ),
  );
}

class _InboxError extends StatelessWidget {
  const _InboxError({required this.error, required this.onRetry});

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
              : 'Inbox Backoffice tidak dapat dimuat.',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 10),
        FilledButton(onPressed: onRetry, child: const Text('Coba lagi')),
      ],
    ),
  );
}

String _stageLabel(String? stage) => switch (stage) {
  'checker' => 'Checker',
  'acknowledgement' => 'Mengetahui',
  'approval' => 'Menyetujui',
  _ => 'Reviewer',
};

String _costLabel(String? amount) {
  if (amount == null) return '—';
  final integer = amount.split('.').first;
  final grouped = integer.replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => '.',
  );
  return 'Rp $grouped';
}
