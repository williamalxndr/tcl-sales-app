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
  List<MasterOption> _locations = const [];
  List<MasterOption> _types = const [];
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
        repo.locations(),
        repo.programTypes(),
      ]);
      final draft = values[0] as Submission;
      if (!mounted) return;
      setState(() {
        _draft = draft;
        _locations = values[1] as List<MasterOption>;
        _types = values[2] as List<MasterOption>;
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
