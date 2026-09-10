import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/di/providers.dart';
import '../../../core/network/api_exception.dart';
import '../domain/submission.dart';
import '../../../core/ui/app_theme.dart';

class SubmissionEditorScreen extends ConsumerStatefulWidget {
  const SubmissionEditorScreen({super.key, required this.submissionId});
  final String submissionId;

  @override
  ConsumerState<SubmissionEditorScreen> createState() =>
      _SubmissionEditorScreenState();
}

class _SubmissionEditorScreenState
    extends ConsumerState<SubmissionEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _cost = TextEditingController();
  Submission? _draft;
  SubmissionPolicy? _policy;
  List<MasterOption> _locations = const [];
  List<MasterOption> _types = const [];
  List<ReviewerOption> _acknowledgementOptions = const [];
  List<PolicyPerson> _acknowledgers = const [];
  final Set<String> _locationIds = {};
  String? _typeId;
  DateTime? _start;
  DateTime? _end;
  Object? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final repo = ref.read(submissionRepositoryProvider);
      final values = await Future.wait([
        repo.get(widget.submissionId),
        repo.policy(widget.submissionId),
        repo.locations(),
        repo.programTypes(),
        repo.reviewerOptions(
          widget.submissionId,
          stage: ReviewerStage.acknowledgement,
        ),
      ]);
      final draft = values[0] as Submission;
      if (!mounted) return;
      setState(() {
        _draft = draft;
        _policy = values[1] as SubmissionPolicy;
        _locations = values[2] as List<MasterOption>;
        _types = values[3] as List<MasterOption>;
        _acknowledgementOptions = (values[4] as ReviewerPage).items;
        _acknowledgers = draft.reviewPlan.acknowledgers;
        _name.text = draft.programName ?? '';
        _cost.text = draft.estimatedCost ?? '';
        _locationIds.addAll(draft.locationIds);
        _typeId = draft.programTypeId;
        _start = _date(draft.periodStart);
        _end = _date(draft.periodEnd);
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  DateTime? _date(String? value) =>
      value == null ? null : DateTime.tryParse(value);
  String _dateText(DateTime? value) => value == null
      ? 'Pilih tanggal'
      : '${value.year}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';
  Future<void> _chooseDate(bool start) async {
    final value = await showDatePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      initialDate: (start ? _start : _end) ?? DateTime.now(),
    );
    if (value != null) {
      setState(() {
        if (start) {
          _start = value;
        } else {
          _end = value;
        }
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _draft == null) return;
    if (_start != null && _end != null && _start!.isAfter(_end!)) {
      setState(
        () => _error = const ApiException(
          code: 'VALIDATION_FAILED',
          message: 'Tanggal mulai tidak boleh setelah tanggal selesai.',
        ),
      );
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final fields = <String, dynamic>{
        'programName': _name.text.trim(),
        'locationIds': _locationIds.toList(),
        'periodStart': _start == null ? null : _dateText(_start),
        'periodEnd': _end == null ? null : _dateText(_end),
        'acknowledgerIds': _acknowledgers.map((person) => person.id).toList(),
        'programTypeId': _typeId,
        'estimatedCost': _cost.text.trim().isEmpty
            ? null
            : {'currency': 'IDR', 'amount': _cost.text.trim()},
      };
      final saved = await ref
          .read(submissionRepositoryProvider)
          .updateDraft(widget.submissionId, fields, _draft!.version);
      if (mounted) context.go('/submissions/${saved.id}');
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_draft == null) {
      return SafeArea(
        child: Center(
          child: _error == null
              ? const CircularProgressIndicator()
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Draft tidak dapat dimuat.'),
                    OutlinedButton(
                      onPressed: _load,
                      child: const Text('Coba lagi'),
                    ),
                  ],
                ),
        ),
      );
    }
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(
            padding: const EdgeInsets.all(24),
            children: [
              TextButton.icon(
                onPressed: () =>
                    context.go('/submissions/${widget.submissionId}'),
                icon: const Icon(Icons.arrow_back),
                label: const Text('Kembali ke detail'),
              ),
              Text(
                'Form Pengajuan Program',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                '${_draft!.programNumber} · Draft',
                style: const TextStyle(color: Color(0xFF5C6771)),
              ),
              const SizedBox(height: 20),
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error case final ApiException error)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          error.message,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    _FormSection(
                      number: '01',
                      title: 'Informasi program',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _InputLabel('Nama program'),
                          TextFormField(
                            controller: _name,
                            maxLength: 200,
                            decoration: const InputDecoration(
                              labelText: 'Nama program',
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Nama program wajib diisi.'
                                : null,
                          ),
                          const SizedBox(height: 14),
                          const _InputLabel('Jenis program'),
                          DropdownButtonFormField<String>(
                            initialValue: _typeId,
                            decoration: const InputDecoration(
                              labelText: 'Jenis program',
                            ),
                            items: _types
                                .map(
                                  (item) => DropdownMenuItem(
                                    value: item.id,
                                    child: Text(item.name),
                                  ),
                                )
                                .toList(),
                            onChanged: (value) =>
                                setState(() => _typeId = value),
                          ),
                          const SizedBox(height: 16),
                          const _InputLabel('Lokasi'),
                          Wrap(
                            spacing: 8,
                            children: _locations
                                .map(
                                  (item) => FilterChip(
                                    label: Text(item.name),
                                    selected: _locationIds.contains(item.id),
                                    onSelected: (yes) => setState(
                                      () => yes
                                          ? _locationIds.add(item.id)
                                          : _locationIds.remove(item.id),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _FormSection(
                      number: '02',
                      title: 'Periode & biaya',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const _InputLabel('Periode pelaksanaan'),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _chooseDate(true),
                                  child: Text('Mulai: ${_dateText(_start)}'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _chooseDate(false),
                                  child: Text('Selesai: ${_dateText(_end)}'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          const _InputLabel('Estimasi biaya'),
                          TextFormField(
                            controller: _cost,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Estimasi biaya (IDR)',
                              prefixText: 'Rp ',
                            ),
                            validator: (v) =>
                                v != null &&
                                    v.isNotEmpty &&
                                    !RegExp(
                                      r'^(0|[1-9][0-9]{0,13})\.[0-9]{2}$',
                                    ).hasMatch(v)
                                ? 'Gunakan format 42000000.00.'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _FormSection(
                      number: '03',
                      title: 'Rute pemeriksaan',
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _CheckerAssignment(policy: _policy),
                          const SizedBox(height: 20),
                          _AcknowledgementSelector(
                            selected: _acknowledgers,
                            options: _acknowledgementOptions,
                            min: _policy?.minAcknowledgers ?? 1,
                            max: _policy?.maxAcknowledgers ?? 2,
                            onChanged: (people) =>
                                setState(() => _acknowledgers = people),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Menyimpan…' : 'Simpan Draft'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AcknowledgementSelector extends StatelessWidget {
  const _AcknowledgementSelector({
    required this.selected,
    required this.options,
    required this.min,
    required this.max,
    required this.onChanged,
  });
  final List<PolicyPerson> selected;
  final List<ReviewerOption> options;
  final int min;
  final int max;
  final ValueChanged<List<PolicyPerson>> onChanged;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _InputLabel('Reviewer Mengetahui · pilih $min–$max orang'),
      const Text(
        'Urutan pada daftar ini menjadi urutan pemeriksaan.',
        style: TextStyle(fontSize: 12, color: AppColors.muted),
      ),
      const SizedBox(height: 10),
      if (selected.isEmpty)
        const _EmptyReviewerSelection()
      else
        ...selected.indexed.map(
          (entry) => _SelectedReviewerRow(
            position: entry.$1,
            person: entry.$2,
            total: selected.length,
            onMove: (offset) => _move(entry.$1, offset),
            onRemove: () => onChanged([...selected]..removeAt(entry.$1)),
          ),
        ),
      const SizedBox(height: 10),
      OutlinedButton.icon(
        onPressed: selected.length >= max ? null : () => _choose(context),
        icon: const Icon(Icons.person_add_alt_1_outlined, size: 17),
        label: const Text('Tambah reviewer'),
      ),
    ],
  );

  void _move(int from, int offset) {
    final to = from + offset;
    if (to < 0 || to >= selected.length) return;
    final reordered = [...selected];
    final person = reordered.removeAt(from);
    reordered.insert(to, person);
    onChanged(reordered);
  }

  Future<void> _choose(BuildContext context) async {
    final selectedIds = selected.map((person) => person.id).toSet();
    final person = await showDialog<PolicyPerson>(
      context: context,
      builder: (_) => _ReviewerChoiceDialog(
        options: options
            .where((option) => !selectedIds.contains(option.person.id))
            .toList(),
      ),
    );
    if (person != null) onChanged([...selected, person]);
  }
}

class _EmptyReviewerSelection extends StatelessWidget {
  const _EmptyReviewerSelection();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFF9FBFC),
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(7),
    ),
    child: const Text(
      'Belum ada reviewer dipilih.',
      style: TextStyle(fontSize: 12.5, color: AppColors.muted),
    ),
  );
}

class _SelectedReviewerRow extends StatelessWidget {
  const _SelectedReviewerRow({
    required this.position,
    required this.person,
    required this.total,
    required this.onMove,
    required this.onRemove,
  });
  final int position;
  final PolicyPerson person;
  final int total;
  final ValueChanged<int> onMove;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 7),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      border: Border.all(color: AppColors.line),
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: AppColors.softNavy,
            shape: BoxShape.circle,
          ),
          child: Text(
            '${position + 1}',
            style: const TextStyle(
              fontSize: 10.5,
              color: AppColors.navy,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                person.fullName,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (person.jobTitle != null)
                Text(
                  person.jobTitle!,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.muted,
                  ),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Naikkan urutan',
          onPressed: position > 0 ? () => onMove(-1) : null,
          icon: const Icon(Icons.keyboard_arrow_up, size: 19),
        ),
        IconButton(
          tooltip: 'Turunkan urutan',
          onPressed: position < total - 1 ? () => onMove(1) : null,
          icon: const Icon(Icons.keyboard_arrow_down, size: 19),
        ),
        IconButton(
          tooltip: 'Hapus reviewer',
          onPressed: onRemove,
          color: const Color(0xFF9C4030),
          icon: const Icon(Icons.close, size: 18),
        ),
      ],
    ),
  );
}

class _ReviewerChoiceDialog extends StatelessWidget {
  const _ReviewerChoiceDialog({required this.options});
  final List<ReviewerOption> options;
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Pilih reviewer Mengetahui'),
    content: SizedBox(
      width: 420,
      child: options.isEmpty
          ? const Text('Tidak ada reviewer eligible yang tersedia.')
          : ListView.separated(
              shrinkWrap: true,
              itemCount: options.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final person = options[index].person;
                return ListTile(
                  onTap: () => Navigator.pop(context, person),
                  title: Text(person.fullName),
                  subtitle: person.jobTitle == null
                      ? null
                      : Text(person.jobTitle!),
                  trailing: const Icon(
                    Icons.add_circle_outline,
                    size: 19,
                    color: AppColors.navy,
                  ),
                );
              },
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
    ],
  );
}

class _CheckerAssignment extends StatelessWidget {
  const _CheckerAssignment({required this.policy});
  final SubmissionPolicy? policy;

  @override
  Widget build(BuildContext context) {
    final checker = policy?.checker;
    final configured = policy?.routingConfigured == true && checker != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _InputLabel('Checker'),
        DecoratedBox(
          decoration: BoxDecoration(
            color: configured ? AppColors.softNavy : const Color(0xFFFFF1F0),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: configured
                  ? const Color(0xFFD7E3E9)
                  : const Color(0xFFF1C4C0),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: configured
                      ? Colors.white
                      : const Color(0xFFFFE2DF),
                  foregroundColor: configured
                      ? AppColors.navy
                      : const Color(0xFF9C4030),
                  child: Text(
                    configured ? _initials(checker.fullName) : '!',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        configured
                            ? checker.fullName
                            : 'Checker belum dikonfigurasi',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        configured
                            ? checker.jobTitle ?? 'Checker'
                            : 'Hubungi administrator untuk menetapkan Checker.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.lock_outline,
                  size: 17,
                  color: AppColors.faint,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Checker ditetapkan dari relasi karyawan dan tidak dapat diubah dari pengajuan.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      ],
    );
  }

  String _initials(String name) => name
      .trim()
      .split(RegExp(r'\s+'))
      .where((part) => part.isNotEmpty)
      .take(2)
      .map((part) => part[0].toUpperCase())
      .join();
}

class _FormSection extends StatelessWidget {
  const _FormSection({
    required this.number,
    required this.title,
    required this.child,
  });
  final String number;
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.softNavy,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Text(
                  number,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 11,
                    color: AppColors.navy,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    ),
  );
}

class _InputLabel extends StatelessWidget {
  const _InputLabel(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.muted,
      ),
    ),
  );
}
