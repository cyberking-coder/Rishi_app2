import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/soft_background.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/profile_providers.dart';
import '../widgets/device_tile.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_section_card.dart';
import '../widgets/subscription_status_badge.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final subscriptionAsync = ref.watch(subscriptionSummaryProvider);
    final devicesAsync = ref.watch(registeredDevicesProvider);
    final currentFpAsync = ref.watch(currentDeviceFingerprintProvider);
    final downloadsCount = ref.watch(downloadsCountProvider);

    return Scaffold(
      backgroundColor: AppTheme.canvas,
      body: Stack(
        children: [
          const SoftBackground(),
          SafeArea(
            child: Column(
              children: [
                // AppBar row
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back_ios, size: 18),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      const Expanded(
                        child: Text('Profile',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontSize: 16, fontWeight: FontWeight.w600)),
                      ),
                      IconButton(
                        icon: const Icon(Icons.logout, size: 20),
                        onPressed: () => _confirmLogout(context, ref),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: profileAsync.when(
                    loading: () => const Center(
                        child:
                            CircularProgressIndicator(color: AppTheme.accent)),
                    error: (e, _) => Center(
                      child: Text('Could not load profile.\n$e',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: AppTheme.textSecondary)),
                    ),
                    data: (profile) => RefreshIndicator(
                      color: AppTheme.accent,
                      onRefresh: () async {
                        ref.invalidate(userProfileProvider);
                        ref.invalidate(subscriptionSummaryProvider);
                        ref.invalidate(registeredDevicesProvider);
                      },
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                        children: [
                          ProfileHeader(profile: profile),
                          const SizedBox(height: 20),
                          // ── Subscription ──
                          _SubscriptionSection(
                              subscriptionAsync: subscriptionAsync),
                          const SizedBox(height: 16),
                          // ── Devices ──
                          _DevicesSection(
                            devicesAsync: devicesAsync,
                            currentFpAsync: currentFpAsync,
                          ),
                          const SizedBox(height: 16),
                          // ── Stats ──
                          _StatsSection(downloadsCount: downloadsCount),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surfaceElevated,
        title: const Text('Log out?'),
        content: const Text('You can log back in any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
            child:
                const Text('Log out', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionSection extends StatelessWidget {
  final AsyncValue subscriptionAsync;
  const _SubscriptionSection({required this.subscriptionAsync});

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'SUBSCRIPTION',
      child: subscriptionAsync.when(
        loading: () => const CircularProgressIndicator(color: AppTheme.accent),
        error: (_, __) => const Text('Could not load subscription.',
            style: TextStyle(color: AppTheme.textSecondary)),
        data: (sub) => SubscriptionStatusBadge(subscription: sub),
      ),
    );
  }
}

class _DevicesSection extends ConsumerWidget {
  final AsyncValue devicesAsync;
  final AsyncValue<String> currentFpAsync;
  const _DevicesSection(
      {required this.devicesAsync, required this.currentFpAsync});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ProfileSectionCard(
      title: 'REGISTERED DEVICES',
      child: devicesAsync.when(
        loading: () => const CircularProgressIndicator(color: AppTheme.accent),
        error: (_, __) => const Text('Could not load devices.',
            style: TextStyle(color: AppTheme.textSecondary)),
        data: (devices) {
          if (devices.isEmpty) {
            return const Text('No registered devices.',
                style: TextStyle(color: AppTheme.textSecondary));
          }
          final currentFp = currentFpAsync.valueOrNull ?? '';
          return Column(
            children: devices
                .map((d) => DeviceTile(
                      device: d,
                      isCurrentDevice: d.fingerprint == currentFp,
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}

class _StatsSection extends StatelessWidget {
  final int downloadsCount;
  const _StatsSection({required this.downloadsCount});

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'STATS',
      child: Row(
        children: [
          const Icon(Icons.download_done_rounded,
              color: AppTheme.accentBright, size: 20),
          const SizedBox(width: 10),
          Text(
            '$downloadsCount downloaded',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
