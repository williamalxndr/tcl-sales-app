import 'package:flutter/material.dart';

import '../network/api_exception.dart';
import 'app_theme.dart';

class AppLoadingState extends StatelessWidget {
  const AppLoadingState({super.key, this.message = 'Memuat data…'});

  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: message,
    child: Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 13),
          Text(
            message,
            style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
          ),
        ],
      ),
    ),
  );
}

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '$title. $message',
    child: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.softNavy,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 26, color: AppColors.navy),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 13),
              OutlinedButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    ),
  );
}

class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.error,
    required this.fallbackMessage,
    required this.onRetry,
  });

  final Object? error;
  final String fallbackMessage;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final message = error is ApiException
        ? (error as ApiException).message
        : fallbackMessage;
    return Semantics(
      container: true,
      liveRegion: true,
      label: 'Terjadi kesalahan. $message',
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0ED),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sync_problem_outlined,
                  color: Color(0xFF9C4030),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'Data belum dapat ditampilkan',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12.5, color: AppColors.muted),
              ),
              const SizedBox(height: 13),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
