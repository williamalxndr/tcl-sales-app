import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/ui/app_theme.dart';
import '../../../core/ui/async_state_panel.dart';
import '../../submissions/domain/submission.dart';
import '../../submissions/presentation/submission_status_badge.dart';
import '../domain/backoffice_submission.dart';

class BackofficeInboxScreen extends ConsumerStatefulWidget {
  const BackofficeInboxScreen({super.key, this.history = false});

  final bool history;

  @override
  ConsumerState<BackofficeInboxScreen> createState() =>
      _BackofficeInboxScreenState();
}

class _BackofficeInboxScreenState extends ConsumerState<BackofficeInboxScreen> {
  final _programNumber = TextEditingController();
  late Future<BackofficeSubmissionPage> _future;
  var _page = 1;
  String? _appliedProgramNumber;
  String? _selectedStatus;
  BackofficePersonField? _selectedRole;
  String? _appliedStatus;
  String? _selectedReviewerId;
  BackofficePersonField? _appliedReviewerField;
  String? _appliedReviewerId;
  Future<BackofficePeoplePage>? _peopleFuture;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  String? _appliedDateFrom;
  String? _appliedDateTo;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void dispose() {
    _programNumber.dispose();
    super.dispose();
  }

  Future<BackofficeSubmissionPage> _load() {
    final repository = ref.read(backofficeRepositoryProvider);
    final parameters = (
      page: _page,
      programNumber: _appliedProgramNumber,
      status: _appliedStatus,
      reviewerField: _appliedReviewerField,
      reviewerId: _appliedReviewerId,
      periodStartFrom: _appliedDateFrom,
      periodStartTo: _appliedDateTo,
    );
    return widget.history
        ? repository.listHistory(
            page: parameters.page,
            programNumber: parameters.programNumber,
            status: parameters.status,
            reviewerField: parameters.reviewerField,
            reviewerId: parameters.reviewerId,
            periodStartFrom: parameters.periodStartFrom,
            periodStartTo: parameters.periodStartTo,
          )
        : repository.listInbox(
            page: parameters.page,
            programNumber: parameters.programNumber,
            status: parameters.status,
            reviewerField: parameters.reviewerField,
            reviewerId: parameters.reviewerId,
            periodStartFrom: parameters.periodStartFrom,
            periodStartTo: parameters.periodStartTo,
          );
  }

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

  void _applyFilters() {
    _appliedProgramNumber = _programNumber.text.trim();
    _appliedStatus = _selectedRole?.submissionStatus ?? _selectedStatus;
    _appliedReviewerField = _selectedReviewerId == null ? null : _selectedRole;
    _appliedReviewerId = _selectedReviewerId;
    _appliedDateFrom = _apiDate(_dateFrom);
    _appliedDateTo = _apiDate(_dateTo);
    _reload(firstPage: true);
  }

  void _resetFilters() {
    _programNumber.clear();
    _selectedStatus = null;
    _selectedRole = null;
    _selectedReviewerId = null;
    _peopleFuture = null;
    _dateFrom = null;
    _dateTo = null;
    _appliedProgramNumber = null;
    _appliedStatus = null;
    _appliedReviewerField = null;
    _appliedReviewerId = null;
    _appliedDateFrom = null;
    _appliedDateTo = null;
    _reload(firstPage: true);
  }

  Future<void> _pickDate({required bool from}) async {
    final initial = from ? _dateFrom : _dateTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: from ? 'Pilih awal periode' : 'Pilih akhir periode',
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (from) {
        _dateFrom = picked;
        if (_dateTo != null && _dateTo!.isBefore(picked)) _dateTo = picked;
      } else {
        _dateTo = picked;
        if (_dateFrom != null && _dateFrom!.isAfter(picked)) {
          _dateFrom = picked;
        }
      }
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
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.history ? 'Riwayat Review' : 'Backoffice',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.inbox_outlined),
                        label: Text('Inbox'),
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.history),
                        label: Text('Riwayat'),
                      ),
                    ],
                    selected: {widget.history},
                    onSelectionChanged: (selection) {
                      context.go(
                        selection.single
                            ? '/backoffice/history'
                            : '/backoffice',
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                widget.history
                    ? 'Tugas pemeriksaan yang telah Anda selesaikan.'
                    : 'Pengajuan yang sedang menunggu tindakan Anda.',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Filter',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        widget.history
                            ? 'Hanya pengajuan dengan task yang telah Anda putuskan yang ditampilkan.'
                            : 'Hanya pengajuan yang sedang menjadi giliran Anda yang ditampilkan.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.faint,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 14,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.end,
                        children: [
                          SizedBox(
                            width: 210,
                            child: TextField(
                              controller: _programNumber,
                              onSubmitted: (_) => _applyFilters(),
                              decoration: const InputDecoration(
                                labelText: 'No. Program',
                                hintText: 'PRG-2026-0143',
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 210,
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedStatus,
                              decoration: const InputDecoration(
                                labelText: 'Status',
                              ),
                              hint: const Text('Semua status'),
                              items: const [
                                DropdownMenuItem(
                                  value: 'pendingChecker',
                                  child: Text('Menunggu Checker'),
                                ),
                                DropdownMenuItem(
                                  value: 'pendingAcknowledgement',
                                  child: Text('Menunggu Mengetahui'),
                                ),
                                DropdownMenuItem(
                                  value: 'pendingApproval',
                                  child: Text('Menunggu Persetujuan'),
                                ),
                                DropdownMenuItem(
                                  value: 'approved',
                                  child: Text('Disetujui'),
                                ),
                                DropdownMenuItem(
                                  value: 'rejected',
                                  child: Text('Ditolak'),
                                ),
                                DropdownMenuItem(
                                  value: 'cancelled',
                                  child: Text('Dibatalkan'),
                                ),
                              ],
                              onChanged: (value) => setState(() {
                                _selectedStatus = value;
                                if (value != null) _selectedRole = null;
                              }),
                            ),
                          ),
                          SizedBox(
                            width: 210,
                            child:
                                DropdownButtonFormField<BackofficePersonField>(
                                  initialValue: _selectedRole,
                                  decoration: const InputDecoration(
                                    labelText: 'Peran reviewer',
                                  ),
                                  hint: const Text('Semua peran'),
                                  items: BackofficePersonField.values
                                      .where(
                                        (field) =>
                                            field !=
                                            BackofficePersonField.owner,
                                      )
                                      .map(
                                        (role) => DropdownMenuItem(
                                          value: role,
                                          child: Text(role.label),
                                        ),
                                      )
                                      .toList(growable: false),
                                  onChanged: (value) => setState(() {
                                    _selectedRole = value;
                                    _selectedReviewerId = null;
                                    _peopleFuture = value == null
                                        ? null
                                        : ref
                                              .read(
                                                backofficeRepositoryProvider,
                                              )
                                              .listFilterPeople(
                                                field: value,
                                                scope: widget.history
                                                    ? 'history'
                                                    : 'inbox',
                                              );
                                    if (value != null) _selectedStatus = null;
                                  }),
                                ),
                          ),
                          SizedBox(
                            width: 230,
                            child: _ReviewerPersonFilter(
                              key: ValueKey(_selectedRole),
                              future: _peopleFuture,
                              value: _selectedReviewerId,
                              onChanged: (value) =>
                                  setState(() => _selectedReviewerId = value),
                            ),
                          ),
                          SizedBox(
                            width: 210,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Periode pelaksanaan',
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _pickDate(from: true),
                                      child: Text(
                                        _dateFrom == null
                                            ? 'Dari'
                                            : _apiDate(_dateFrom)!,
                                        style: TextStyle(
                                          color: _dateFrom == null
                                              ? AppColors.faint
                                              : AppColors.ink,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Text('—'),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: InkWell(
                                      onTap: () => _pickDate(from: false),
                                      child: Text(
                                        _dateTo == null
                                            ? 'Sampai'
                                            : _apiDate(_dateTo)!,
                                        style: TextStyle(
                                          color: _dateTo == null
                                              ? AppColors.faint
                                              : AppColors.ink,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.calendar_today_outlined,
                                    size: 15,
                                    color: AppColors.faint,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          FilledButton(
                            onPressed: _applyFilters,
                            child: const Text('Terapkan Filter'),
                          ),
                          OutlinedButton(
                            onPressed: _resetFilters,
                            child: const Text('Reset'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<BackofficeSubmissionPage>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return AppLoadingState(
                        message: widget.history
                            ? 'Memuat riwayat review…'
                            : 'Memuat inbox reviewer…',
                      );
                    }
                    if (snapshot.hasError) {
                      return AppErrorState(
                        error: snapshot.error,
                        fallbackMessage: widget.history
                            ? 'Riwayat review tidak dapat dimuat.'
                            : 'Inbox Backoffice tidak dapat dimuat.',
                        onRetry: () => _reload(),
                      );
                    }
                    final result = snapshot.requireData;
                    if (result.items.isEmpty) {
                      return AppEmptyState(
                        title: widget.history
                            ? 'Belum ada riwayat review'
                            : 'Inbox Anda sudah bersih',
                        message: widget.history
                            ? 'Tugas yang telah diputuskan akan tersimpan di halaman ini.'
                            : 'Tidak ada pengajuan yang sedang menunggu tindakan Anda.',
                        icon: widget.history ? Icons.history : Icons.task_alt,
                        actionLabel: 'Muat ulang',
                        onAction: () => _reload(),
                      );
                    }
                    return Column(
                      children: [
                        Expanded(
                          child: _InboxTable(
                            items: result.items,
                            history: widget.history,
                          ),
                        ),
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
  const _InboxTable({required this.items, required this.history});

  final List<BackofficeSubmissionSummary> items;
  final bool history;

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
              Text(
                history ? 'Riwayat reviewer' : 'Inbox reviewer',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
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
                      itemBuilder: (context, index) => _InboxRow(
                        item: items[index],
                        history: history,
                        onTap: () => context.push(
                          '/backoffice/submissions/'
                          '${items[index].submission.id}',
                        ),
                      ),
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
  const _InboxRow({
    required this.item,
    required this.history,
    required this.onTap,
  });

  final BackofficeSubmissionSummary item;
  final bool history;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final submission = item.submission;
    return InkWell(
      onTap: onTap,
      child: SizedBox(
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
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.faint,
                    ),
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
                      history ? 'Selesai' : _stageLabel(item.currentStage),
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

class _ReviewerPersonFilter extends StatelessWidget {
  const _ReviewerPersonFilter({
    super.key,
    required this.future,
    required this.value,
    required this.onChanged,
  });

  final Future<BackofficePeoplePage>? future;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    if (future == null) {
      return DropdownButtonFormField<String>(
        items: const [],
        onChanged: null,
        decoration: const InputDecoration(labelText: 'Orang reviewer'),
        hint: const Text('Pilih peran dahulu'),
      );
    }
    return FutureBuilder<BackofficePeoplePage>(
      future: future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return DropdownButtonFormField<String>(
            items: const [],
            onChanged: null,
            decoration: const InputDecoration(labelText: 'Orang reviewer'),
            hint: Text(
              snapshot.hasError ? 'Opsi gagal dimuat' : 'Memuat opsi…',
            ),
          );
        }
        return DropdownButtonFormField<String>(
          initialValue: value,
          decoration: const InputDecoration(labelText: 'Orang reviewer'),
          hint: const Text('Semua orang'),
          items: snapshot.requireData.items
              .map(
                (person) => DropdownMenuItem(
                  value: person.id,
                  child: Text(
                    _personLabel(person),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(growable: false),
          onChanged: onChanged,
        );
      },
    );
  }
}

String _personLabel(PolicyPerson person) => person.jobTitle == null
    ? person.fullName
    : '${person.fullName} · ${person.jobTitle}';

String? _apiDate(DateTime? date) {
  if (date == null) return null;
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
