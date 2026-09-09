import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/di/providers.dart';
import '../domain/user_profile.dart';

class AuthenticatedShell extends ConsumerWidget {
  const AuthenticatedShell({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final user = auth.user!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('PT Total Chemindo Loka'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: _UserIdentity(user: user),
          ),
          IconButton(
            tooltip: 'Keluar',
            onPressed: auth.isSubmitting
                ? null
                : () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: child,
    );
  }
}

class _UserIdentity extends StatelessWidget {
  const _UserIdentity({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Masuk sebagai ${user.fullName}, ${user.primaryRole}',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (MediaQuery.sizeOf(context).width >= 520)
            Padding(
              padding: const EdgeInsets.only(right: 9),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    user.fullName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    user.jobTitle ?? user.primaryRole,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7C8791),
                    ),
                  ),
                ],
              ),
            ),
          CircleAvatar(
            radius: 14,
            backgroundColor: const Color(0xFFEEF3F6),
            foregroundColor: const Color(0xFF1F5876),
            child: Text(
              user.initials.isEmpty ? '?' : user.initials,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
