import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/providers.dart';
import '../../features/service_status/presentation/workspace_screen.dart';

/// Route ownership lives above individual features. Authentication redirects and
/// role-aware destinations will be introduced with the session feature.
final appRouterProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          return WorkspaceScreen(
            repository: ref.read(serviceStatusRepositoryProvider),
          );
        },
      ),
    ],
    errorBuilder: (context, state) {
      return Scaffold(
        body: Center(
          child: Text(
            'Halaman yang Anda buka tidak tersedia. (${state.uri.path})',
            textAlign: TextAlign.center,
          ),
        ),
      );
    },
  );
  ref.onDispose(router.dispose);
  return router;
});
