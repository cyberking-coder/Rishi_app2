import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/profile_providers.dart';
import '../widgets/device_tile.dart';
import '../widgets/profile_header.dart';
import '../widgets/profile_section_card.dart';
import '../widgets/profile_stat_tile.dart';
import '../widgets/subscription_status_badge.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        backgroundColor: AppTheme.background,
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Log out',
            icon: const Icon(Icons.logout),
            onPressed: () => _confirmLogout(context, ref),
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Could not load profile.\n$e',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
          ),
        ),
        data: (profile) => RefreshIndicator(
          color: AppTheme.accent,
          onRefresh: () async {
            ref.invalidate(userProfileProvider);
            ref.invalidate(subscriptionSummaryProvider);
            ref.invalidate(registeredDevicesProvider);
          },
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              ProfileHeader(profile: profile),
              const SizedBox(height: 24),
              const _SubscriptionSection(),
              const SizedBox(height: 16),
              const _DevicesSection(),
              const SizedBox(height: 16),
              const _StatsSection(),
            ],
          ),
        ),
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
            child: const Text('Log out', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _SubscriptionSection extends ConsumerWidget {
  const _SubscriptionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(subscriptionSummaryProvider);

    return ProfileSectionCard(
      title: 'SUBSCRIPTION',
      child: async.when(
        loading: () => const SizedBox(
          height: 40,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, __) => const Text(
          'Could not load subscription status.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        data: (sub) => SubscriptionStatusBadge(subscription: sub),
      ),
    );
  }
}

class _DevicesSection extends ConsumerWidget {
  const _DevicesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final devicesAsync = ref.watch(registeredDevicesProvider);
    final fingerprintAsync = ref.watch(currentDeviceFingerprintProvider);

    return ProfileSectionCard(
      title: 'REGISTERED DEVICE',
      child: devicesAsync.when(
        loading: () => const SizedBox(
          height: 40,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (_, __) => const Text(
          'Could not load devices.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        data: (devices) {
          if (devices.isEmpty) {
            return const Text(
              'No device registered yet.',
              style: TextStyle(color: AppTheme.textSecondary),
            );
          }

          final currentFingerprint = fingerprintAsync.valueOrNull;

          return Column(
            children: [
              for (final device in devices)
                DeviceTile(
                  device: device,
                  isCurrentDevice: device.deviceFingerprint == currentFingerprint,
                ),
            ],
          );
        },
      ),
    );
  }
}

class _StatsSection extends ConsumerWidget {
  const _StatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloadsCount = ref.watch(downloadsCountProvider);

    return ProfileSectionCard(
      child: ProfileStatTile(
        icon: Icons.download_done,
        label: 'Downloads',
        value: '$downloadsCount',
        onTap: () => context.push('/downloads'),
      ),
    );
  }
}
