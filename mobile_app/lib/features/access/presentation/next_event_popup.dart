import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/lotus_logo.dart';
import '../../../core/config/checkout_config.dart';
import '../application/access_providers.dart';
import '../domain/entities/app_popup.dart';

/// Modal advertising the next retreat. Shown from the configured start date
/// while the user still has access — always closeable.
class NextEventPopup extends StatelessWidget {
  final AppPopup popup;

  /// True when this person has already paid for the workshop, so the card
  /// confirms their place instead of offering to charge them again.
  final bool alreadyRegistered;

  const NextEventPopup({
    super.key,
    required this.popup,
    this.alreadyRegistered = false,
  });

  static Future<void> show(
    BuildContext context,
    AppPopup popup, {
    bool alreadyRegistered = false,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => NextEventPopup(
        popup: popup,
        alreadyRegistered: alreadyRegistered,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: _PopupCard(
        popup: popup,
        showClose: true,
        alreadyRegistered: alreadyRegistered,
      ),
    );
  }
}

class _PopupCard extends StatelessWidget {
  final AppPopup popup;
  final bool showClose;
  final bool alreadyRegistered;

  const _PopupCard({
    required this.popup,
    required this.showClose,
    this.alreadyRegistered = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasImage =
        popup.imageUrl != null && popup.imageUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), AppTheme.sageSoft],
        ),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: AppTheme.sage.withValues(alpha: 0.18),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.8,
            ),
            child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (hasImage)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(22),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: Image.network(
                        popup.imageUrl!,
                        width: double.infinity,
                        fit: BoxFit.contain,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  )
                else
                  const LotusLogo(size: 56),
                const SizedBox(height: 18),
                Text(
                  popup.title?.isNotEmpty == true
                      ? popup.title!
                      : 'Our Next Gathering',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (popup.body?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    popup.body!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                if (popup.isPaidWorkshop)
                  _RegisterButton(
                    popup: popup,
                    alreadyRegistered: alreadyRegistered,
                  )
                else if (showClose)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
              ],
            ),
            ),
          ),
          if (showClose)
            Positioned(
              top: 6,
              right: 6,
              child: IconButton(
                icon: const Icon(Icons.close, color: AppTheme.textSecondary),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
        ],
      ),
    );
  }
}

/// "Register Now — ₹499", and everything that has to be true before a
/// tap on it can take money.
///
/// Payment happens on the external web checkout, never in the app: the
/// same page the courses and the membership already use, and the same
/// server-side webhook confirms it. Nothing here grants a place — this
/// only opens the door.
class _RegisterButton extends ConsumerStatefulWidget {
  final AppPopup popup;
  final bool alreadyRegistered;

  const _RegisterButton({
    required this.popup,
    required this.alreadyRegistered,
  });

  @override
  ConsumerState<_RegisterButton> createState() => _RegisterButtonState();
}

class _RegisterButtonState extends ConsumerState<_RegisterButton> {
  bool _loading = false;
  String? _error;

  Future<void> _register() async {
    if (!isCheckoutConfigured) {
      setState(() => _error =
          'Registration isn\'t set up yet. Please contact us to book a place.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final url = await ref
          .read(checkoutRemoteDataSourceProvider)
          .getWorkshopCheckoutUrl(widget.popup.id);

      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened) throw Exception('Could not open checkout');

      // Closed on the way out, not on the way back. Payment finishes in a
      // browser and is confirmed server-side, so there is no result to
      // wait here for — and a dialog still sitting behind the browser is
      // what greets them on return.
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e
          .toString()
          .replaceFirst('Exception: ', '')
          .replaceFirst(RegExp(r'^Registration failed \(\d+\): '), ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.alreadyRegistered) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.sageSoft,
          borderRadius: BorderRadius.circular(AppTheme.radiusRow),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.check_circle_rounded,
                size: 19, color: AppTheme.sageDark),
            SizedBox(width: 8),
            Text(
              'You are registered',
              style: TextStyle(
                fontFamily: AppTheme.text,
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.sageDark,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: _loading ? null : _register,
            child: _loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    // The fee on the button rather than only in the body
                    // text. Somebody tapping "Register Now" should never
                    // discover the price on the next screen.
                    '${widget.popup.ctaText}  •  ${widget.popup.priceLabel}',
                  ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: AppTheme.text,
              fontSize: 12.5,
              height: 1.4,
              color: AppTheme.danger,
            ),
          ),
        ],
      ],
    );
  }
}
