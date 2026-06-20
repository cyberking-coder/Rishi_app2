import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/soft_background.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/profile_providers.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
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
                        child: CircularProgressIndicator(color: AppTheme.accent)),
                    error: (e, _) => Center(
                      child: Text('Could not load profile.\n$e',
                          textAlign: TextAlign.center,
                          style:
                              const TextStyle(color: AppTheme.textSecondary)),
                    ),
                    data: (profile) {
                      final name =
                          profile.displayName?.isNotEmpty == true
                              ? profile.displayName!
                              : profile.email;
                      final initial = name.isEmpty
                          ? '?'
                          : name.substring(0, 1).toUpperCase();

                      return RefreshIndicator(
                        color: AppTheme.accent,
                        onRefresh: () async {
                          ref.invalidate(userProfileProvider);
                        },
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            const SizedBox(height: 12),
                            // ── Avatar ──
                            Center(
                              child: Container(
                                width: 94,
                                height: 94,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                      color: AppTheme.accentBright
                                          .withValues(alpha: 0.6),
                                      width: 3),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppTheme.accent
                                          .withValues(alpha: 0.4),
                                      blurRadius: 28,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: profile.avatarUrl != null
                                      ? Image.network(profile.avatarUrl!,
                                          fit: BoxFit.cover)
                                      : Container(
                                          color: AppTheme.surfaceElevated,
                                          child: Center(
                                            child: Text(initial,
                                                style: const TextStyle(
                                                    fontSize: 36,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.white)),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 14),
                            // ── Name ──
                            Center(
                              child: Text(
                                  profile.displayName?.isNotEmpty == true
                                      ? profile.displayName!
                                      : 'Member',
                                  style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700)),
                            ),
                            const SizedBox(height: 4),
                            const Center(
                              child: Text('👑 Premium Member',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.accentBright)),
                            ),
                            const SizedBox(height: 20),
                            // ── Stats row ──
                            Row(children: [
                              _StatCard(value: '0', label: 'Day Streak'),
                              const SizedBox(width: 10),
                              _StatCard(value: '$downloadsCount', label: 'Downloads'),
                              const SizedBox(width: 10),
                              _StatCard(value: '0', label: 'Sessions'),
                            ]),
                            const SizedBox(height: 22),
                            // ── Achievements ──
                            const Text('Achievements',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                _Badge(emoji: '🏆',
                                    color: const Color(0xFF1E3A8A)),
                                _Badge(emoji: '💎',
                                    color: const Color(0xFF831843)),
                                _Badge(emoji: '🔥',
                                    color: const Color(0xFF92400E)),
                                _Badge(emoji: '🌿',
                                    color: const Color(0xFF14532D)),
                              ],
                            ),
                            const SizedBox(height: 22),
                            // ── List rows ──
                            _ListRow(
                              iconEmoji: '⭐',
                              iconBg: const Color(0xFF2D1F6E),
                              title: 'Subscription',
                              subtitle: 'Anurag Rishi Premium',
                              onTap: () {},
                            ),
                            const SizedBox(height: 10),
                            _ListRow(
                              iconEmoji: '⚙️',
                              iconBg: const Color(0xFF1E1B4B),
                              title: 'Settings',
                              onTap: () {},
                            ),
                            const SizedBox(height: 24),
                          ],
                        ),
                      );
                    },
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
              if (context.mounted) ctx.mounted; // satisfy lint
              if (context.mounted) context.go('/login');
            },
            child: const Text('Log out',
                style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  const _StatCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.line),
        ),
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Colors.white)),
            const SizedBox(height: 4),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String emoji;
  final Color color;
  const _Badge({required this.emoji, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 54,
      height: 54,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(child: Text(emoji, style: const TextStyle(fontSize: 24))),
    );
  }
}

class _ListRow extends StatelessWidget {
  final String iconEmoji;
  final Color iconBg;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  const _ListRow({
    required this.iconEmoji,
    required this.iconBg,
    required this.title,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.line),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(12)),
              child: Center(
                  child: Text(iconEmoji,
                      style: const TextStyle(fontSize: 18))),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: const TextStyle(
                            fontSize: 11, color: AppTheme.accentBright)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppTheme.textDim, size: 20),
          ],
        ),
      ),
    );
  }
}
