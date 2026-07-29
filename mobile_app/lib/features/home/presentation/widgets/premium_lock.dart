import 'package:flutter/material.dart';

/// Small lock badge overlaid on a premium item's thumbnail for a free-tier
/// user, so locked content is discoverable without having to tap it first.
class PremiumLockBadge extends StatelessWidget {
  const PremiumLockBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 6,
      right: 6,
      child: Container(
        padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.lock, color: Colors.white, size: 14),
      ),
    );
  }
}

/// Shown when a free-tier user taps premium content. No purchase flow yet
/// (that's a later phase) — same contact-us pattern as the app's other
/// membership messaging.
void showPremiumLockedMessage(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Premium content'),
      content: const Text(
        'This content is available to members with active access.\n\n'
        'To unlock it, please contact us and our team will help you get '
        'access:\n\n'
        'Email: ar.happinessmovement@gmail.com',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}
