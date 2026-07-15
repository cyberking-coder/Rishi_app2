import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/device/device_info_service.dart';
import '../../../auth/application/auth_providers.dart';
import '../../application/profile_providers.dart';

const _kBg = Color(0xFF12082E);
const _kSurface = Color(0xFF1C1040);
const _kAccent = Color(0xFF8B5CF6);
const _kPink = Color(0xFFEC4899);
const _kText = Colors.white;
const _kSub = Color(0xFFB0A8CC);

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final subAsync = ref.watch(subscriptionSummaryProvider);

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: profileAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator(color: _kAccent)),
          error: (e, _) => Center(
            child: Text('Could not load profile.\n$e',
                textAlign: TextAlign.center,
                style: const TextStyle(color: _kSub)),
          ),
          data: (profile) {
            final subPlan = subAsync.valueOrNull?.planName ?? 'Premium';

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                // ── Avatar + name ──
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFF7C3AED), Color(0xFFEC4899)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _kAccent.withOpacity(0.45),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const Icon(Icons.person,
                            size: 52, color: Colors.white),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        profile.displayName ?? profile.email,
                        style: const TextStyle(
                          color: _kText,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('👑 ',
                              style: TextStyle(fontSize: 14)),
                          Text(
                            '$subPlan Member',
                            style: const TextStyle(
                              color: _kPink,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                // ── Achievements ──
                const Text(
                  'Achievements',
                  style: TextStyle(
                    color: _kText,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _Badge(
                      emoji: '🏆',
                      color: const Color(0xFF3B82F6),
                      label: 'First Play',
                      onTap: () => _showAchievement(context, '🏆', 'First Play',
                          'Awarded for playing your first meditation session.'),
                    ),
                    _Badge(
                      emoji: '💎',
                      color: const Color(0xFFEC4899),
                      label: 'Premium',
                      onTap: () => _showAchievement(context, '💎', 'Premium',
                          'You are a premium member with full access to all content.'),
                    ),
                    _Badge(
                      emoji: '🔥',
                      color: const Color(0xFFF97316),
                      label: '7 Days',
                      onTap: () => _showAchievement(context, '🔥', '7 Days',
                          'Keep listening for 7 days to unlock this milestone.'),
                    ),
                    _Badge(
                      emoji: '🌿',
                      color: const Color(0xFF22C55E),
                      label: 'Mindful',
                      onTap: () => _showAchievement(context, '🌿', 'Mindful',
                          'Complete meditation sessions to grow your mindfulness.'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // ── Subscription row ──
                _ListRow(
                  icon: Icons.workspace_premium_rounded,
                  iconColor: _kPink,
                  title: 'Subscription',
                  subtitle: subPlan,
                  onTap: () => _showSubscriptionDetails(
                    context,
                    subPlan,
                    subAsync.valueOrNull,
                  ),
                ),
                const SizedBox(height: 12),

                // ── Settings button ──
                _ListRow(
                  icon: Icons.settings_outlined,
                  iconColor: _kAccent,
                  title: 'Settings',
                  onTap: () => _openSettings(context, ref),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showAchievement(
    BuildContext context,
    String emoji,
    String title,
    String description,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        title: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: _kText,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        content: Text(description,
            style: const TextStyle(color: _kSub, fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Got it',
                style: TextStyle(color: _kAccent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  void _openSettings(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _SettingsSheet(ref: ref),
    );
  }

  void _showSubscriptionDetails(
    BuildContext context,
    String planName,
    dynamic subscription,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: const Color(0x55FFFFFF),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text('Subscription',
                style: TextStyle(
                    color: _kText,
                    fontSize: 20,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 20),
            _DetailRow(label: 'Plan', value: planName),
            if (subscription != null) ...[
              _DetailRow(
                  label: 'Status',
                  value: subscription.status.toString()),
              if (subscription.currentPeriodEnd != null)
                _DetailRow(
                  label: 'Renews / Expires',
                  value: subscription.currentPeriodEnd
                      .toString()
                      .split(' ')
                      .first,
                ),
            ] else
              const _DetailRow(label: 'Status', value: 'Active'),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: _kSub, fontSize: 14)),
          Text(value,
              style: const TextStyle(
                  color: _kText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _Badge extends StatelessWidget {
  const _Badge({
    required this.emoji,
    required this.color,
    required this.label,
    this.onTap,
  });
  final String emoji;
  final Color color;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color.withOpacity(0.18),
              shape: BoxShape.circle,
              border: Border.all(color: color.withOpacity(0.5), width: 2),
            ),
            child: Center(
              child: Text(emoji, style: const TextStyle(fontSize: 26)),
            ),
          ),
          const SizedBox(height: 6),
          Text(label,
              style: const TextStyle(color: _kSub, fontSize: 11)),
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.onTap,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _kSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                          color: _kText,
                          fontSize: 15,
                          fontWeight: FontWeight.w600)),
                  if (subtitle != null)
                    Text(subtitle!,
                        style: const TextStyle(color: _kSub, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: _kSub),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────

class _SettingsSheet extends ConsumerStatefulWidget {
  const _SettingsSheet({required this.ref});
  final WidgetRef ref;

  @override
  ConsumerState<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends ConsumerState<_SettingsSheet> {
  String? _deviceInfo;
  bool _showDeviceInfo = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0x55FFFFFF),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('Settings',
              style: TextStyle(
                  color: _kText, fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),

          // ── Logout ──
          _SheetTile(
            icon: Icons.logout,
            iconColor: Colors.redAccent,
            title: 'Logout',
            onTap: () async {
              Navigator.pop(context);
              await ref.read(authControllerProvider.notifier).logout();
              if (context.mounted) context.go('/login');
            },
          ),
          const SizedBox(height: 12),

          // ── Device Info ──
          _SheetTile(
            icon: Icons.phone_android,
            iconColor: _kAccent,
            title: 'Device Info',
            onTap: () async {
              if (_deviceInfo == null) {
                try {
                  final svc = ref.read(deviceInfoServiceProvider);
                  final profile = await svc.getDeviceProfile();
                  if (!mounted) return;
                  setState(() {
                    _deviceInfo =
                        'Name: ${profile.name}\nPlatform: ${profile.platform}\nFingerprint: ${profile.fingerprint}';
                    _showDeviceInfo = true;
                  });
                } catch (_) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Could not load device info.')),
                  );
                }
              } else {
                setState(() => _showDeviceInfo = !_showDeviceInfo);
              }
            },
          ),
          if (_showDeviceInfo && _deviceInfo != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF120830),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_deviceInfo!,
                  style:
                      const TextStyle(color: _kSub, fontSize: 12, height: 1.6)),
            ),
          ],
        ],
      ),
    );
  }
}

class _SheetTile extends StatelessWidget {
  const _SheetTile(
      {required this.icon,
      required this.iconColor,
      required this.title,
      required this.onTap});
  final IconData icon;
  final Color iconColor;
  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF120830),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      color: _kText,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
            ),
            const Icon(Icons.chevron_right, color: _kSub),
          ],
        ),
      ),
    );
  }
}
