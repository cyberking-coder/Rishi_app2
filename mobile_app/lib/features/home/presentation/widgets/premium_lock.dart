import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/config/checkout_config.dart';
import '../../../access/application/access_providers.dart';
import '../../../access/data/checkout_remote_datasource.dart';

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

/// Shown when a free-tier user taps premium content. "Get Access Now" opens
/// an external browser to the web checkout (never in-app — deliberately,
/// to stay outside Apple/Google's in-app purchase requirements for
/// digital content). Never says "buy"/"premium"/"subscribe" next to the
/// button, only "Get Access Now".
void showPremiumLockedMessage(BuildContext context, WidgetRef ref) {
  showDialog<void>(
    context: context,
    builder: (_) => const _PremiumLockedDialog(),
  );
}

class _PremiumLockedDialog extends ConsumerStatefulWidget {
  const _PremiumLockedDialog();

  @override
  ConsumerState<_PremiumLockedDialog> createState() =>
      _PremiumLockedDialogState();
}

class _PremiumLockedDialogState extends ConsumerState<_PremiumLockedDialog> {
  bool _loading = false;
  String? _error;

  static const _fallbackMessage =
      'Please contact us and our team will help you get access:\n\n'
      'Email: ar.happinessmovement@gmail.com';

  Future<void> _getAccess() async {
    if (!isCheckoutConfigured) {
      setState(() => _error = 'Checkout isn\'t set up yet.\n\n$_fallbackMessage');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final url =
          await ref.read(checkoutRemoteDataSourceProvider).getCheckoutUrl();
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('Could not open checkout');
      if (mounted) Navigator.pop(context);
    } on NoActivePlanException {
      // Distinct from a network or function failure, and fixable in a
      // completely different place: it means nothing in the admin's
      // Subscriptions page is marked active, so there is no price to
      // charge. Saying "something went wrong" sends whoever reports it
      // hunting through the app instead.
      if (mounted) {
        setState(() => _error =
            'No subscription plan is available right now.\n\n$_fallbackMessage');
      }
    } catch (e) {
      // Show what actually failed. The same blanket "something went
      // wrong" in the course purchase sheet hid an edge function that
      // had not been redeployed, behind a message that suggested
      // emailing support — that lesson was applied there and not here.
      if (mounted) {
        setState(() => _error = '$e\n\n$_fallbackMessage');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Premium content'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('This content is available to members with active access.'),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: _loading ? null : _getAccess,
          child: _loading
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Get Access Now'),
        ),
      ],
    );
  }
}
