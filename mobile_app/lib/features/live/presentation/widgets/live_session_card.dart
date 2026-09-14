import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/config/checkout_config.dart';
import '../../../../core/config/purchase_config.dart';
import '../../../access/application/access_providers.dart';
import '../../application/live_providers.dart';
import '../../domain/entities/live_session.dart';

/// Opens the meeting in Zoom (or the browser, if Zoom isn't installed).
///
/// externalApplication rather than an in-app webview: a meeting needs the
/// camera and microphone, and a webview would either fail at that or ask
/// for permissions the app has no other reason to hold.
///
/// The link is asked for at the moment of joining rather than read off
/// the session. A paid session carries no link on its row at all — the
/// database keeps it out of reach and hands it over only to somebody with
/// a paid seat, so a URL that has been sitting in app memory since the
/// list loaded is exactly the thing this must not rely on.
Future<void> joinSession(
  BuildContext context,
  WidgetRef ref,
  LiveSession session,
) async {
  String? url = session.joinUrl.isNotEmpty ? session.joinUrl : null;

  if (url == null) {
    try {
      url = await ref
          .read(liveSessionsDataSourceProvider)
          .getJoinUrl(session.id);
    } catch (_) {
      url = null;
    }
  }

  if (!context.mounted) return;

  if (url == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'The meeting link is not available yet. If you have just '
          'registered, give it a moment and try again.',
        ),
      ),
    );
    return;
  }

  final uri = Uri.tryParse(url);
  if (uri == null) return;

  final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open the meeting link.')),
    );
  }
}

/// Sends somebody to the external checkout for a seat.
///
/// A no-op on iOS, where a paid seat cannot be sold in-app at all — see
/// [kPurchaseUiEnabled]. The card hides the button there, so this guard
/// is only belt-and-braces against a future caller reaching it another
/// way; the cost of that being wrong is a rejected build.
Future<void> registerForSession(
  BuildContext context,
  WidgetRef ref,
  LiveSession session,
) async {
  if (!kPurchaseUiEnabled) return;

  if (!isCheckoutConfigured) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registration is not set up yet.')),
    );
    return;
  }

  try {
    final url = await ref
        .read(checkoutRemoteDataSourceProvider)
        .getSessionCheckoutUrl(session.id);

    final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!opened) throw Exception('Could not open checkout');
  } catch (e) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          e.toString().replaceFirst(RegExp(r'^Exception: '), ''),
        ),
      ),
    );
  }
}

/// The thumbnail the reminder is telling people to tap.
///
/// Everything on it exists to answer one question — can I join right now,
/// and if not, when? — so the countdown and the live badge are the two
/// loudest things on the card.
class LiveSessionCard extends ConsumerWidget {
  final LiveSession session;

  const LiveSessionCard({super.key, required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = session.isLiveNow;
    final over = session.isOver;
    final dimmed = session.isCancelled || over;

    // Absent while the registration list is still loading, which is why
    // this is read as a nullable rather than defaulting to false: showing
    // "Register • ₹499" to somebody who has already paid, for the half
    // second before the answer arrives, is the one wrong state here.
    final paid = ref.watch(paidSessionsProvider).valueOrNull;
    final registered = paid?.contains(session.id);
    final needsPayment = session.isPaid && registered == false;

    // On iOS a seat cannot be bought in the app, so the card stops at
    // saying the seat is held rather than offering one. The session
    // itself stays listed — a reader app may show what exists, it just
    // may not sell it.
    final showLockedNotice = needsPayment && !kPurchaseUiEnabled;

    return Opacity(
      opacity: dimmed ? 0.55 : 1,
      child: GestureDetector(
        onTap: dimmed
            ? null
            : showLockedNotice
                ? () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text(kLockedContentMessage)),
                    )
                : needsPayment
                    ? () => registerForSession(context, ref, session)
                    : () => joinSession(context, ref, session),
        child: Container(
          decoration: AppTheme.claySurface(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppTheme.radiusCard),
                ),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: Stack(fit: StackFit.expand, children: [
                    if (session.thumbnailUrl != null &&
                        session.thumbnailUrl!.isNotEmpty)
                      Image.network(
                        session.thumbnailUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const _PlainCover(),
                      )
                    else
                      const _PlainCover(),

                    // Scrim only under the badge, not across the whole
                    // frame: a full overlay flattens a photograph, and
                    // the badge only needs contrast where it sits.
                    const Positioned(
                      left: 0,
                      right: 0,
                      top: 0,
                      height: 72,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x59000000), Color(0x00000000)],
                          ),
                        ),
                      ),
                    ),

                    Positioned(
                      left: 12,
                      top: 12,
                      child: _Badge(
                        label: session.isCancelled
                            ? 'Cancelled'
                            : over
                                ? 'Finished'
                                : live
                                    ? 'Live now'
                                    : _countdown(session.startsAt),
                        colour: session.isCancelled
                            ? AppTheme.danger
                            : live
                                ? AppTheme.danger
                                : AppTheme.sageDark,
                        pulsing: live,
                      ),
                    ),

                    if (!dimmed)
                      Center(
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.92),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.videocam_rounded,
                              color: AppTheme.sageDark, size: 22),
                        ),
                      ),
                  ]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _whenLine(session),
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: AppTheme.textSecondary),
                    ),
                    if (session.description != null &&
                        session.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        session.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppTheme.textSecondary),
                      ),
                    ],
                    if (!dimmed) ...[
                      const SizedBox(height: 12),
                      if (session.isPaid && registered == null)
                        // The list has loaded but the registration has
                        // not. A disabled placeholder rather than a
                        // guessed label.
                        const SizedBox(
                          height: 48,
                          child: Center(
                            child: SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppTheme.sage,
                              ),
                            ),
                          ),
                        )
                      else if (showLockedNotice)
                        Row(children: [
                          const Icon(Icons.lock_rounded,
                              size: 16, color: AppTheme.clay),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Open to registered participants',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppTheme.clay,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ),
                        ])
                      else if (needsPayment)
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () =>
                                registerForSession(context, ref, session),
                            icon: const Icon(Icons.lock_open_rounded, size: 18),
                            label: Text(
                              // The fee on the button, never a screen
                              // later: nobody should discover the price
                              // after committing to the tap.
                              'Register  •  ${session.priceLabel}',
                            ),
                          ),
                        )
                      else ...[
                        if (session.isPaid) ...[
                          Row(children: [
                            const Icon(Icons.check_circle_rounded,
                                size: 16, color: AppTheme.sageDark),
                            const SizedBox(width: 6),
                            Text(
                              'You are registered',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppTheme.sageDark,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                          ]),
                          const SizedBox(height: 8),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => joinSession(context, ref, session),
                            icon:
                                const Icon(Icons.open_in_new_rounded, size: 18),
                            label: Text(live ? 'Join now' : 'Open meeting link'),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// "in 3 days" / "in 4 hours" / "in 25 min" / "starting soon".
///
/// Coarse on purpose. A live-to-the-second countdown would need a ticking
/// timer on a card that is usually off-screen, and "in 4 hours" tells
/// somebody everything they need at that distance.
String _countdown(DateTime startsAt) {
  final left = startsAt.difference(DateTime.now());
  if (left.isNegative) return 'starting soon';
  if (left.inDays >= 1) {
    return 'in ${left.inDays} day${left.inDays == 1 ? '' : 's'}';
  }
  if (left.inHours >= 1) {
    return 'in ${left.inHours} hour${left.inHours == 1 ? '' : 's'}';
  }
  if (left.inMinutes >= 1) return 'in ${left.inMinutes} min';
  return 'starting soon';
}

String _whenLine(LiveSession s) {
  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  final t = s.startsAt;
  final hour12 = t.hour % 12 == 0 ? 12 : t.hour % 12;
  final minute = t.minute.toString().padLeft(2, '0');
  final meridiem = t.hour < 12 ? 'am' : 'pm';
  return '${months[t.month - 1]} ${t.day} · $hour12:$minute $meridiem · '
      '${s.durationMinutes} min';
}

class _PlainCover extends StatelessWidget {
  const _PlainCover();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.sageGradient),
      child: const Center(
        child: Icon(Icons.videocam_rounded, color: Colors.white54, size: 34),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color colour;
  final bool pulsing;

  const _Badge({
    required this.label,
    required this.colour,
    this.pulsing = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.circular(AppTheme.radiusPill),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (pulsing) ...[
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.2,
          ),
        ),
      ]),
    );
  }
}
