import 'package:flutter/material.dart';

import '../../../app/widgets/lotus_logo.dart';
import '../domain/access_state.dart';
import 'next_event_popup.dart';

const _kText = Colors.white;
const _kSub = Color(0xFFB0A8CC);
const _kAccent = Color(0xFF8B5CF6);

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
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _kText,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Thank you for being with us.\nWe look forward to seeing you at the next retreat.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: _kSub,
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
