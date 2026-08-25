import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/remote_image.dart';
import '../../../app/widgets/lotus_logo.dart';
import '../domain/entities/app_popup.dart';

/// Modal advertising the next retreat. Shown from the configured start date
/// while the user still has access — always closeable.
class NextEventPopup extends StatelessWidget {
  final AppPopup popup;

  const NextEventPopup({super.key, required this.popup});

  static Future<void> show(BuildContext context, AppPopup popup) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => NextEventPopup(popup: popup),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: _PopupCard(popup: popup, showClose: true),
    );
  }
}

class _PopupCard extends StatelessWidget {
  final AppPopup popup;
  final bool showClose;

  const _PopupCard({required this.popup, required this.showClose});

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
                      child: RemoteImage(
                        url: popup.imageUrl,
                        fit: BoxFit.contain,
                        fallback: const SizedBox.shrink(),
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
                // The button sends people to the screen that owns the
                // thing being advertised, and the price and the paying
                // live there — next to the session, not on the advert.
                // The pop-up used to take payment itself, which meant a
                // fee here and an event elsewhere that had to be kept in
                // step by hand.
                if (popup.hasCta)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final route = popup.ctaRoute!;
                        Navigator.of(context).pop();
                        // go for the tabs, push for anything else. /watch
                        // is not wrapped in the shell, so replacing the
                        // stack with it would strand somebody on a screen
                        // with no navigation and nothing to go back to.
                        if (route == '/home' || route == '/courses') {
                          context.go(route);
                        } else {
                          context.push(route);
                        }
                      },
                      child: Text(popup.ctaText),
                    ),
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
