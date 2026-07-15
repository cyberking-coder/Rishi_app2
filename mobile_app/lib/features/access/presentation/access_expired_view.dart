import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/widgets/lotus_logo.dart';
import '../../auth/application/auth_providers.dart';
import '../domain/access_state.dart';
import 'next_event_popup.dart';

const _kText = Colors.white;
const _kSub = Color(0xFFB0A8CC);
const _kAccent = Color(0xFF8B5CF6);

/// Shown in place of the home content once the user's access window has
/// lapsed: no audio, just a gentle "access ended" message, a log-out action,
/// and — if one is configured — the next-event card.
class AccessExpiredView extends ConsumerWidget {
  final AccessState access;
  const AccessExpiredView({super.key, required this.access});

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    await ref.read(authControllerProvider.notifier).logout();
    if (context.mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasRetreatCard = access.shouldShowPopup ||
        (access.popupTitle?.isNotEmpty ?? false);

    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Always show a clear "access ended" message first, so the user
              // understands why there is no audio — whether or not a next-event
              // card is configured.
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _kAccent.withOpacity(0.15),
                  boxShadow: [
                    BoxShadow(
                      color: _kAccent.withOpacity(0.35),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Center(
                  child: LotusLogo(size: 56, color: _kText),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Your access has ended',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _kText,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Your subscription period is over, so the audio library is no '
                'longer available. Thank you for being with us — please contact '
                'us to renew your access.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.5,
                  color: _kSub,
                ),
              ),
              // If the admin configured a next-retreat announcement, show it
              // below the access-ended message.
              if (hasRetreatCard) ...[
                const SizedBox(height: 28),
                NextEventInlineCard(access: access),
              ],
              const SizedBox(height: 32),
              // Always let an expired user log out (the normal Profile route
              // is not reachable from this screen).
              OutlinedButton.icon(
                onPressed: () => _logout(context, ref),
                icon: const Icon(Icons.logout, color: _kText, size: 18),
                label: const Text('Log Out',
                    style: TextStyle(color: _kText, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: _kAccent.withOpacity(0.6)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 28, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
