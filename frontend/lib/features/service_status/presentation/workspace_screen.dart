import 'package:flutter/material.dart';

import '../../../core/ui/app_theme.dart';
import '../data/service_status_repository.dart';

/// Backoffice landing screen for roles without the submitter workspace.
class WorkspaceScreen extends StatefulWidget {
  const WorkspaceScreen({super.key, required this.repository});
  final ServiceStatusRepository repository;
  @override
  State<WorkspaceScreen> createState() => _WorkspaceScreenState();
}

class _WorkspaceScreenState extends State<WorkspaceScreen> {
  late Future<void> _availability;
  @override
  void initState() {
    super.initState();
    _availability = widget.repository.checkAvailability();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1180),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 26, 24, 60),
          child: ListView(
            children: [
              const Text(
                'Backoffice',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -.4,
                ),
              ),
              const SizedBox(height: 3),
              const Text(
                'Pengajuan yang memerlukan tindakan Anda.',
                style: TextStyle(fontSize: 13, color: AppColors.muted),
              ),
              const SizedBox(height: 18),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Wrap(
                    spacing: 14,
                    runSpacing: 12,
                    crossAxisAlignment: WrapCrossAlignment.end,
                    children: [
                      const SizedBox(
                        width: 230,
                        child: _Filter(
                          label: 'No. Program',
                          hint: 'contoh: PRG-2026-0143',
                        ),
                      ),
                      const SizedBox(
                        width: 210,
                        child: _Filter(label: 'Status', hint: 'Semua status'),
                      ),
                      const SizedBox(
                        width: 210,
                        child: _Filter(
                          label: 'Peran saya',
                          hint: 'Semua peran',
                        ),
                      ),
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.filter_alt_outlined, size: 17),
                        label: const Text('Terapkan filter'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FutureBuilder<void>(
                future: _availability,
                builder: (context, snapshot) {
                  if (snapshot.connectionState != ConnectionState.done) {
                    return const Padding(
                      padding: EdgeInsets.all(36),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return _ServiceIssue(
                      onRetry: () => setState(() {
                        _availability = widget.repository.checkAvailability();
                      }),
                    );
                  }
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 54,
                      ),
                      child: Column(
                        children: const [
                          Icon(
                            Icons.inbox_outlined,
                            size: 42,
                            color: AppColors.faint,
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Belum ada pengajuan yang perlu ditindaklanjuti.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Pengajuan akan muncul setelah masuk ke tahap peran Anda.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.muted,
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(
                            'Service connected',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF2F6B48),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Filter extends StatelessWidget {
  const _Filter({required this.label, required this.hint});
  final String label;
  final String hint;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
        ),
      ),
      const SizedBox(height: 6),
      TextField(decoration: InputDecoration(hintText: hint)),
    ],
  );
}

class _ServiceIssue extends StatelessWidget {
  const _ServiceIssue({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        children: [
          const Text('Backoffice tidak dapat dimuat.'),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
