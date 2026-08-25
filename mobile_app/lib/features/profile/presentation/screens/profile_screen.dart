import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/remote_image.dart';
import '../../../../core/config/purchase_config.dart';
import '../../../../core/device/device_info_service.dart';
import '../../../../core/errors/auth_failure.dart';
import '../../../access/application/access_providers.dart';
import '../../../access/domain/access_state.dart';
import '../../../auth/application/auth_providers.dart';
import '../../../downloads/application/download_providers.dart';
import '../../../lms/application/lms_providers.dart';
import '../../../lms/domain/entities/course_summary.dart';
import '../../application/profile_providers.dart';

/// The membership label always comes from live access, never from the
/// `subscriptions` row.
///
/// That row records what was bought and is never cleared when an admin
/// ends someone's access — so reading the plan name from it kept showing
/// "Rishi Mode Member" to accounts that had been revoked. Access state is
/// the only thing that knows whether the membership is currently real.
String _planLabelFor(UserTier? tier) {
  switch (tier) {
    case UserTier.admin:
      return 'Staff';
    case UserTier.retreat:
      return 'Rishi Mode';
    case UserTier.free:
    case null:
      return 'Free';
  }
}

const _kBg = AppTheme.background;
const _kSurface = AppTheme.surface;
const _kAccent = AppTheme.sage;
const _kText = AppTheme.textPrimary;
const _kSub = AppTheme.textSecondary;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileProvider);
    final subAsync = ref.watch(subscriptionSummaryProvider);
    final access = ref.watch(accessStateProvider).valueOrNull;
    // Courses are sold individually, so buying one makes someone a paying
    // customer even with no subscription. Reading this here is what lets
    // the header say "Premium Member" instead of "Free plan" for a buyer.
    final enrolled = (ref.watch(coursesProvider).valueOrNull ?? const [])
        .where((c) => c.owned)
        .toList();

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
              final hasMembership = access?.tier == UserTier.retreat ||
                  access?.tier == UserTier.admin;
              // The subscription row only names the plan; whether it counts
              // at all is decided by access above.
              final subPlan = hasMembership
                  ? (subAsync.valueOrNull?.planName ??
                      _planLabelFor(access?.tier))
                  : _planLabelFor(access?.tier);
              // "Free" describes someone who has paid for nothing at all —
              // not someone who owns courses but no subscription. Treating
              // a course buyer as free was showing them "Free plan" right
              // next to the course they'd just paid for.
              final isFree = !hasMembership && enrolled.isEmpty;
              // On iOS the chip states what the account can reach, not
              // what tier it is on. "Free plan" and "Premium Member" name a
              // paid tier that the app has no way to sell, which invites a
              // reviewer to look for the purchase path that 3.1.3(a) says
              // must not be there — and it was a subscription the last
              // rejection singled out.
              final memberLabel = !kEducationFramingEnabled
                  ? (isFree ? 'Free access' : 'Full access')
                  : hasMembership
                      ? '$subPlan Member'
                      : enrolled.isEmpty
                          ? 'Free plan'
                          : 'Premium Member';

              final name = profile.displayName?.trim().isNotEmpty == true
                  ? profile.displayName!.trim()
                  : profile.email;

              return ListView(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                children: [
                  const Text('Profile', style: AppTheme.displayLarge),
                  const SizedBox(height: 16),

                  // ── Who you are, and what you can reach ──
                  //
                  // One glass row rather than a centred portrait. The
                  // 112px avatar under a halo took a third of the screen
                  // to say something the initial says in 60, and pushed
                  // everything anyone came here to do below the fold.
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: AppTheme.glassSurface(),
                    child: Row(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: AppTheme.sageGradient,
                          ),
                          child: Center(
                            child: Text(
                              name.characters.first.toUpperCase(),
                              style: const TextStyle(
                                fontFamily: AppTheme.text,
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontFamily: AppTheme.text,
                                  color: _kText,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -0.17,
                                ),
                              ),
                              const SizedBox(height: 5),
                              // The plan as a chip rather than a line of
                              // text — it is a status, and a status reads
                              // as one when it has an edge around it.
                              Container(
                                height: 22,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 9),
                                decoration: BoxDecoration(
                                  color: AppTheme.sageSoft,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isFree
                                          ? Icons.spa_rounded
                                          : Icons.verified_rounded,
                                      size: 13,
                                      color: const Color(0xFF4C1D95),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      memberLabel,
                                      style: const TextStyle(
                                        fontFamily: AppTheme.text,
                                        color: Color(0xFF4C1D95),
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Achievements ──
                  Text('ACHIEVEMENTS', style: AppTheme.label),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Badge(
                        icon: Icons.emoji_events_rounded,
                        label: 'First play',
                        onTap: () => _showAchievement(
                            context,
                            Icons.emoji_events_rounded,
                            'First play',
                            'Awarded for playing your first session.'),
                      ),
                      _Badge(
                        icon: Icons.diamond_rounded,
                        label: kEducationFramingEnabled ? 'Premium' : 'Devoted',
                        // Dimmed rather than hidden: the badge is something
                        // to earn back, and a gap in the row would read as
                        // a layout bug.
                        earned: !isFree,
                        onTap: () => _showAchievement(
                          context,
                          Icons.diamond_rounded,
                          kEducationFramingEnabled ? 'Premium' : 'Devoted',
                          // The locked copy used to read "Unlock this by
                          // joining Rishi Mode for full access" — an
                          // instruction to go and buy something, inside a
                          // build whose whole claim is that it contains no
                          // such prompt. It describes the badge on iOS
                          // instead of telling anyone how to get it.
                          isFree
                              ? (kEducationFramingEnabled
                                  ? 'Unlock this by joining Rishi Mode for full access to all content.'
                                  : 'Awarded to accounts with full access to the library.')
                              : 'You have full access to the library.',
                        ),
                      ),
                      _Badge(
                        icon: Icons.local_fire_department_rounded,
                        label: '7 days',
                        onTap: () => _showAchievement(
                            context,
                            Icons.local_fire_department_rounded,
                            '7 days',
                            'Keep listening for 7 days to unlock this milestone.'),
                      ),
                      _Badge(
                        icon: Icons.spa_rounded,
                        label: 'Mindful',
                        onTap: () => _showAchievement(
                            context,
                            Icons.spa_rounded,
                            'Mindful',
                            'Complete sessions to grow your mindfulness.'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // ── Enrolled courses ──
                  // Only rendered when there's something to show: an empty
                  // "My Courses" heading on a brand-new account reads as a
                  // failed load rather than as "you haven't bought any".
                  if (enrolled.isNotEmpty) ...[
                    Text(
                      kEducationFramingEnabled ? 'MY COURSES' : 'MY VIDEOS',
                      style: AppTheme.label,
                    ),
                    const SizedBox(height: 8),
                    for (final course in enrolled) ...[
                      _EnrolledCourseCard(course: course),
                      const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 14),
                  ],

                  // ── Membership and settings ──
                  //
                  // One card holding both rows, divided by a hairline
                  // inset past the glyphs. Two separate 80px cards with a
                  // tinted disc each read as two more things to deal with;
                  // this reads as the settings list it is.
                  Container(
                    decoration: AppTheme.glassSurface(),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        _ListRow(
                          icon: Icons.workspace_premium_rounded,
                          title: kEducationFramingEnabled
                              ? 'Subscription'
                              : 'Membership',
                          // "Subscription" is Apple's own heading for
                          // Guideline 3.1.1, and a row carrying it with a
                          // chevron reads as the way in to buying one.
                          value: hasMembership
                              ? subPlan
                              : (kEducationFramingEnabled
                                  ? 'No active subscription'
                                  : 'Not active'),
                          onTap: () => _showSubscriptionDetails(
                            context,
                            hasMembership
                                ? subPlan
                                : (kEducationFramingEnabled
                                    ? 'No active subscription'
                                    : 'Not active'),
                            // Never pass the raw subscription row for an
                            // account without live access — it records what
                            // was once bought and is never cleared on
                            // revoke, so a free/revoked user would still
                            // see the old renewal date. hasMembership is
                            // the only thing that decides whether this row
                            // is current.
                            hasMembership ? subAsync.valueOrNull : null,
                            // This sheet is about the subscription
                            // specifically, so owning courses doesn't make
                            // it "Active" — only a live membership does.
                            !hasMembership,
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.only(left: 46),
                          child: Divider(height: 0.5, color: AppTheme.border),
                        ),
                        _ListRow(
                          icon: Icons.settings_rounded,
                          title: 'Settings',
                          onTap: () => _openSettings(context, ref),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                ],
              );
            },
        ),
      ),
    );
  }

  void _showAchievement(
    BuildContext context,
    IconData icon,
    String title,
    String description,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        title: Row(
          children: [
            Icon(icon, size: 24, color: _kAccent),
            const SizedBox(width: 10),
            Expanded(
              child: Text(title,
                  style: const TextStyle(
                      fontFamily: AppTheme.text,
                      color: _kText,
                      fontSize: 18,
                      fontWeight: FontWeight.w600)),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (_) => _SettingsSheet(ref: ref),
    );
  }

  void _showSubscriptionDetails(
    BuildContext context,
    String planName,
    dynamic subscription,
    bool isFree,
  ) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
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
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(kEducationFramingEnabled ? 'Subscription' : 'Membership',
                style: const TextStyle(
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
              _DetailRow(
                  label: 'Status',
                  value: isFree
                      ? (kEducationFramingEnabled ? 'No active plan' : 'Not active')
                      : 'Active'),
          ],
        ),
      ),
    );
  }
}

/// A course this account has paid for, with how far through it they are.
///
/// Tapping opens the course rather than the catalog entry — someone
/// looking at "My Courses" wants to carry on, not to be sold it again.
class _EnrolledCourseCard extends StatelessWidget {
  const _EnrolledCourseCard({required this.course});

  final CourseSummary course;

  @override
  Widget build(BuildContext context) {
    final done = course.completedLessonCount;
    final total = course.lessonCount;

    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.radiusRow),
      onTap: () => context.push('/course/${course.id}', extra: course.title),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: AppTheme.glassSurface(),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: SizedBox(
                width: 56,
                height: 56,
                child: RemoteImage(
                  url: course.coverImageUrl,
                  fallback: const _CourseThumbFallback(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    course.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.text,
                      color: _kText,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.16,
                    ),
                  ),
                  if (total > 0) ...[
                    const SizedBox(height: 7),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: course.progressFraction,
                        minHeight: 3,
                        backgroundColor: AppTheme.well,
                        valueColor:
                            const AlwaysStoppedAnimation<Color>(_kAccent),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '$done of $total ${kPartWord}s',
                      style: const TextStyle(
                        fontFamily: AppTheme.text,
                        color: _kSub,
                        fontSize: 12,
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 3),
                    Text(
                      kEducationFramingEnabled ? 'Enrolled' : 'Yours',
                      style: const TextStyle(
                        fontFamily: AppTheme.text,
                        color: _kSub,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, size: 20, color: _kSub),
          ],
        ),
      ),
    );
  }
}

class _CourseThumbFallback extends StatelessWidget {
  const _CourseThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.sageSoft,
      child: const Icon(Icons.play_arrow_rounded,
          size: 24, color: AppTheme.sageLight),
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
    required this.icon,
    required this.label,
    this.onTap,
    this.earned = true,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  /// Unearned badges render faded rather than being removed, so the row
  /// keeps its shape and the badge reads as something to work toward.
  final bool earned;

  @override
  Widget build(BuildContext context) {
    // Four equal glass tiles with a glyph and a word. The emoji in a
    // tinted disc, with a spark or a padlock pinned to its corner, put
    // four saturated colours and two extra symbols into a row whose job
    // is to be glanced at.
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Opacity(
          opacity: earned ? 1 : 0.42,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              decoration: AppTheme.glassSurface(radius: 14),
              child: Column(
                children: [
                  Icon(icon,
                      size: 22, color: earned ? AppTheme.sage : _kSub),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontFamily: AppTheme.text,
                      color: _kText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  const _ListRow({
    required this.icon,
    required this.title,
    this.value,
    this.onTap,
  });
  final IconData icon;
  final String title;

  /// The current setting, shown at the right-hand end of the row rather
  /// than as a subtitle under the title. A settings row is a label and a
  /// state on one line; stacking them made every row 80px tall.
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        height: 48,
        child: Row(
          children: [
            const SizedBox(width: 16),
            Icon(icon, size: 18, color: _kAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  fontFamily: AppTheme.text,
                  color: _kText,
                  fontSize: 16,
                  letterSpacing: -0.16,
                ),
              ),
            ),
            if (value != null)
              // Bounded so a long plan name ellipsises instead of
              // squeezing the title out of the row.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    fontFamily: AppTheme.text,
                    color: _kSub,
                    fontSize: 15,
                  ),
                ),
              ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded, size: 20, color: _kSub),
            const SizedBox(width: 12),
          ],
        ),
      ),
    );
  }
}

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
                color: AppTheme.border,
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
            iconColor: AppTheme.clay,
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
                // Capture the messenger before the await to avoid using
                // BuildContext across the async gap.
                final messenger = ScaffoldMessenger.of(context);
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
                  messenger.showSnackBar(
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
                gradient: AppTheme.clayFill(AppTheme.surfaceCream),
                borderRadius: BorderRadius.circular(10),
        boxShadow: AppTheme.cardShadow,
      ),
              child: Text(_deviceInfo!,
                  style:
                      const TextStyle(color: _kSub, fontSize: 12, height: 1.6)),
            ),
          ],

          const SizedBox(height: 20),
          const Divider(color: AppTheme.border),
          const SizedBox(height: 12),

          // ── Delete account ──
          // Required by App Store Guideline 5.1.1(v): an app that creates
          // accounts must let somebody delete theirs from inside it.
          // Directing them to an email address does not satisfy the rule,
          // and it is the wrong answer for the person as well.
          //
          // Last in the sheet and behind a divider — findable, not
          // adjacent to Logout, which somebody taps in a hurry.
          _SheetTile(
            icon: Icons.delete_forever_outlined,
            iconColor: AppTheme.danger,
            title: 'Delete my account',
            onTap: _confirmDelete,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _kSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        ),
        title: const Text('Delete your account?',
            style: TextStyle(
                color: _kText, fontSize: 19, fontWeight: FontWeight.w700)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This cannot be undone. Your account, your listening history '
              'and your downloads will be deleted, and any access you have '
              'paid for ends immediately.',
              style: TextStyle(color: _kSub, fontSize: 14, height: 1.5),
            ),
            SizedBox(height: 12),
            // Said plainly rather than buried in a policy page. Somebody
            // deleting an account is entitled to know what does not go,
            // and "we keep your payment records" is better heard now than
            // discovered later.
            Text(
              'Records of payments are kept, without your name attached, '
              'because the law requires it.',
              style: TextStyle(color: _kSub, fontSize: 13, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep my account',
                style: TextStyle(
                    color: _kAccent, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete',
                style: TextStyle(
                    color: AppTheme.danger, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    // Captured before the awaits: the sheet's own context is disposed the
    // moment it closes, and both of these outlive it.
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    Navigator.pop(context);

    try {
      // Local copies of paid audio are encrypted against this account and
      // are worthless once it is gone. Purged first so a failure here
      // cannot leave files behind that nothing will ever clean up.
      await ref.read(downloadRepositoryProvider).purgeAll();
    } catch (_) {
      // Not a reason to keep the account alive.
    }

    try {
      await ref.read(deleteAccountUseCaseProvider).call();
      router.go('/login');
      messenger.showSnackBar(
        const SnackBar(content: Text('Your account has been deleted.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is AuthFailure
                ? e.message
                : 'Could not delete your account. Please try again.',
          ),
        ),
      );
    }
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
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: AppTheme.clayFill(AppTheme.surfaceCream),
          borderRadius: BorderRadius.circular(20),
        boxShadow: AppTheme.cardShadow,
      ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.18),
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
