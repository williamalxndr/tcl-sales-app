import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/di/providers.dart';
import '../../features/authentication/application/auth_controller.dart';
import '../../features/authentication/presentation/auth_loading_screen.dart';
import '../../features/authentication/presentation/authenticated_shell.dart';
import '../../features/authentication/presentation/login_screen.dart';
import '../../features/backoffice/presentation/backoffice_inbox_screen.dart';
import '../../features/backoffice/presentation/backoffice_detail_screen.dart';
import '../../features/service_status/presentation/workspace_screen.dart';
import '../../features/submissions/presentation/submission_detail_screen.dart';
import '../../features/submissions/presentation/submission_list_screen.dart';
import '../../features/submissions/presentation/submission_editor_screen.dart';

const _loginPath = '/login';
const _loadingPath = '/loading';

/// Routes redirect only from session state. Feature pages retain responsibility
/// for their own resource-level role checks when they are added.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(authRouterRefreshProvider);
  final router = GoRouter(
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = refresh.value;
      final path = state.uri.path;
      if (auth.status == AuthStatus.restoring) {
        return path == _loadingPath ? null : _loadingPath;
      }
      if (auth.status == AuthStatus.unauthenticated) {
        return path == _loginPath ? null : _loginPath;
      }
      if (path == _loginPath || path == _loadingPath) return '/';
      if (path == '/' && auth.user!.roles.contains('submitter')) {
        return '/submissions';
      }
      if (path == '/' && auth.user!.roles.any(_isReviewerRole)) {
        return '/backoffice';
      }
      return null;
    },
    routes: [
      GoRoute(path: _loadingPath, builder: (_, _) => const AuthLoadingScreen()),
      GoRoute(path: _loginPath, builder: (_, _) => const LoginScreen()),
      GoRoute(
        path: '/backoffice',
        builder: (_, _) =>
            const AuthenticatedShell(child: BackofficeInboxScreen()),
      ),
      GoRoute(
        path: '/backoffice/history',
        builder: (_, _) => const AuthenticatedShell(
          child: BackofficeInboxScreen(history: true),
        ),
      ),
      GoRoute(
        path: '/backoffice/submissions/:submissionId',
        builder: (_, state) => AuthenticatedShell(
          child: BackofficeDetailScreen(
            submissionId: state.pathParameters['submissionId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/submissions',
        builder: (_, _) =>
            const AuthenticatedShell(child: SubmissionListScreen()),
      ),
      GoRoute(
        path: '/submissions/:submissionId',
        builder: (context, state) => AuthenticatedShell(
          child: SubmissionDetailScreen(
            submissionId: state.pathParameters['submissionId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/submissions/:submissionId/edit',
        builder: (context, state) => AuthenticatedShell(
          child: SubmissionEditorScreen(
            submissionId: state.pathParameters['submissionId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) {
          return AuthenticatedShell(
            child: WorkspaceScreen(
              repository: ref.read(serviceStatusRepositoryProvider),
            ),
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

bool _isReviewerRole(String role) =>
    role == 'checker' || role == 'acknowledger' || role == 'approver';

final authRouterRefreshProvider = Provider<ValueNotifier<AuthState>>((ref) {
  final notifier = ValueNotifier(ref.read(authControllerProvider));
  ref.listen<AuthState>(
    authControllerProvider,
    (_, next) => notifier.value = next,
  );
  ref.onDispose(notifier.dispose);
  return notifier;
});
