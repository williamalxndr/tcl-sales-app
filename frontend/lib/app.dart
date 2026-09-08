import 'package:flutter/material.dart';

import 'features/service_status/data/service_status_repository.dart';
import 'features/service_status/presentation/workspace_screen.dart';

class SalesApp extends StatelessWidget {
  const SalesApp({super.key, required this.repository});

  final ServiceStatusRepository repository;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sales & Marketing',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1F5876)),
        useMaterial3: true,
      ),
      home: WorkspaceScreen(repository: repository),
    );
  }
}
