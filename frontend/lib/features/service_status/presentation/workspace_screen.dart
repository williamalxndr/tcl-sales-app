import 'package:flutter/material.dart';

import '../data/service_status_repository.dart';

/// A minimal launch shell; business screens follow the supplied UI designs.
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
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Sales & Marketing',
                    style: Theme.of(context).textTheme.headlineMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Your sales workspace is being prepared.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  FutureBuilder<void>(
                    future: _availability,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return Semantics(
                          label: 'Connecting to the service',
                          child: const CircularProgressIndicator(),
                        );
                      }
                      if (snapshot.hasError) {
                        return Column(
                          children: [
                            const Text(
                              'We couldn’t connect to the service.',
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton(
                              onPressed: () => setState(() {
                                _availability = widget.repository
                                    .checkAvailability();
                              }),
                              child: const Text('Try again'),
                            ),
                          ],
                        );
                      }
                      return const Text('Service connected');
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
