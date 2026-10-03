import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../auth/application/app_access_controller.dart';
import '../../application/download_providers.dart';
import '../../domain/entities/download_status.dart';

/// The landing screen when the app is in [AppAccessMode.authenticatedOffline].
///
/// Rather than dropping an offline user into a normal Home whose every row
/// needs the network and fails, this says plainly what IS available offline
/// (their downloads) and offers a way back online. The router sends every
/// online-only route here while offline.
class OfflineHubScreen extends ConsumerWidget {
  const OfflineHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(downloadTasksProvider).valueOrNull ?? const [];
    final ready =
        tasks.where((t) => t.status == DownloadStatus.completed).length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.cloud_off_rounded,
                  size: 64, color: AppTheme.sage),
              const SizedBox(height: 18),
              const Text("You're offline", style: AppTheme.headline),
              const SizedBox(height: 10),
              Text(
                ready > 0
                    ? 'You can still play what you have downloaded. '
                        'Connect to the internet for everything else.'
                    : 'Connect to the internet to sign in and load your '
                        'content. Downloads you save play here offline.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontFamily: AppTheme.text,
                  fontSize: 15,
                  height: 1.5,
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              if (ready > 0) ...[
                _AvailableCard(count: ready),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => context.go('/downloads'),
                    icon: const Icon(Icons.download_done_rounded),
                    label: const Text('View downloads'),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () =>
                      ref.read(appAccessModeProvider.notifier).resolve(),
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Retry connection'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AvailableCard extends StatelessWidget {
  final int count;
  const _AvailableCard({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.glassSurface(),
      child: Row(
        children: [
          const Icon(Icons.headphones_rounded, color: AppTheme.sage),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count download${count == 1 ? '' : 's'} available offline',
              style: const TextStyle(
                fontFamily: AppTheme.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
