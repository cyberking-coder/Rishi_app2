import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/lotus_logo.dart';
import '../domain/access_state.dart';
import 'next_event_popup.dart';

/// Shown in place of the home content once the user's access window has
/// lapsed: no audio, just a gentle "access ended" message and — if one is
/// configured — the next-event card.
class AccessExpiredView extends StatelessWidget {
  final AccessState access;
  const AccessExpiredView({super.key, required this.access});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (access.shouldShowPopup ||
                  (access.popupTitle?.isNotEmpty ?? false))
                NextEventInlineCard(access: access)
              else ...[
                const LotusLogo(size: 64),
                const SizedBox(height: 24),
                const Text(
                  'Your access has ended',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Thank you for being with us.\nWe look forward to seeing you at the next retreat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
