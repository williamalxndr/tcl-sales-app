import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_exception.dart';
import '../domain/submission.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/async_state_panel.dart';
import 'submission_status_badge.dart';

class SubmissionListScreen extends ConsumerStatefulWidget {
  const SubmissionListScreen({super.key});

  @override
  ConsumerState<SubmissionListScreen> createState() =>
      _SubmissionListScreenState();
}

class _SubmissionListScreenState extends ConsumerState<SubmissionListScreen> {
  final _search = TextEditingController();
  late Future<SubmissionPage> _future;
  var _page = 1;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<SubmissionPage> _load() => ref
      .read(submissionRepositoryProvider)
      .list(query: _search.text, page: _page);

  void _reload() => setState(() {
    _page = 1;
    _future = _load();
  });

  void _goToPage(int page, int totalPages) {
    if (page < 1 || page > totalPages || page == _page) return;
    setState(() {
      _page = page;
      _future = _load();
    });
  }

  Future<void> _createDraft() async {
    setState(() => _creating = true);
    try {
      final draft = await ref
          .read(submissionRepositoryProvider)
          .createEmptyDraft();
      if (!mounted) return;
      setState(() => _creating = false);
      context.push('/submissions/${draft.id}').then((_) {
        if (mounted) _reload();
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted && _creating) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 26, 24, 60),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.end,
                  runSpacing: 12,
                  children: [
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pengajuan Saya',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Semua pengajuan program yang Anda buat.',
                          style: TextStyle(color: Color(0xFF5C6771)),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      onPressed: _creating ? null : _createDraft,
                      icon: _creating
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add),
                      label: const Text('Pengajuan Baru'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 320,
                  child: TextField(
                    controller: _search,
                    onSubmitted: (_) => _reload(),
                    decoration: InputDecoration(
                      hintText: 'Cari nomor atau nama program',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        tooltip: 'Cari',
                        onPressed: _reload,
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Expanded(
                  child: FutureBuilder<SubmissionPage>(
                    future: _future,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const AppLoadingState(
                          message: 'Memuat daftar pengajuan…',
                        );
                      }
                      if (snapshot.hasError) {
                        return AppErrorState(
                          error: snapshot.error,
                          fallbackMessage: 'Pengajuan tidak dapat dimuat.',
                          onRetry: _reload,
                        );
                      }
                      final result = snapshot.requireData;
                      final items = result.items;
                      if (items.isEmpty) {
                        return const AppEmptyState(
                          title: 'Belum ada pengajuan',
                          message:
                              'Buat pengajuan program pertama untuk memulai alur pemeriksaan.',
                          icon: Icons.description_outlined,
                        );
                      }
                      return Column(
                        children: [
                          Expanded(child: _SubmissionTable(items: items)),
                          const SizedBox(height: 12),
                          _Pagination(
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
}

class _Pagination extends StatelessWidget {
  const _Pagination({
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
  Widget build(BuildContext context) {
    if (totalPages <= 1) {
      return Align(
        alignment: Alignment.centerRight,
        child: Text(
          '$totalItems pengajuan',
          style: const TextStyle(fontSize: 12, color: AppColors.faint),
        ),
      );
    }
    return Row(
      children: [
        Text(
          '$totalItems pengajuan · Halaman $page dari $totalPages',
          style: const TextStyle(fontSize: 12, color: AppColors.faint),
        ),
        const Spacer(),
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
}

class _SubmissionTable extends StatelessWidget {
  const _SubmissionTable({required this.items});
  final List<SubmissionSummary> items;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: 920,
          child: Column(
            children: [
              const _TableHeader(),
              Expanded(
                child: ListView.separated(
                  itemCount: items.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: Color(0xFFF2F4F6)),
                  itemBuilder: (context, index) =>
                      _TableRow(item: items[index]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();
  @override
  Widget build(BuildContext context) => Container(
    color: const Color(0xFFF9FBFC),
    padding: const EdgeInsets.symmetric(horizontal: 20),
    height: 36,
    child: const Row(
      children: [
        SizedBox(width: 130, child: _ColumnLabel('NO.')),
        Expanded(flex: 19, child: _ColumnLabel('PROGRAM')),
        Expanded(flex: 9, child: _ColumnLabel('JENIS')),
        Expanded(flex: 11, child: _ColumnLabel('LOKASI')),
        SizedBox(
          width: 110,
          child: _ColumnLabel('BIAYA', align: TextAlign.right),
        ),
        SizedBox(width: 160, child: _ColumnLabel('STATUS')),
      ],
    ),
  );
}

class _ColumnLabel extends StatelessWidget {
  const _ColumnLabel(this.text, {this.align = TextAlign.left});
  final String text;
  final TextAlign align;
  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: align,
    style: const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w700,
      letterSpacing: .35,
      color: Color(0xFF8B929A),
    ),
  );
}

class _TableRow extends StatelessWidget {
  const _TableRow({required this.item});
  final SubmissionSummary item;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: () => context.go('/submissions/${item.id}'),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(
              item.programNumber,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6F7981),
                fontFamily: 'monospace',
              ),
            ),
          ),
          Expanded(
            flex: 19,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.programName ?? 'Pengajuan belum diberi nama',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy,
                  ),
                ),
                Text(
                  item.periodLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF8B929A),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 9,
            child: Text(
              item.programType ?? '—',
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          Expanded(
            flex: 11,
            child: Text(
              item.locations.isEmpty ? '—' : item.locations.join(', '),
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.muted),
            ),
          ),
          SizedBox(
            width: 110,
            child: Text(
              item.estimatedCost == null ? '—' : 'Rp ${item.estimatedCost}',
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
            ),
          ),
          SizedBox(
            width: 160,
            child: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: SubmissionStatusBadge(status: item.status, compact: true),
            ),
          ),
        ],
      ),
    ),
  );
}
