import 'package:flutter/material.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/widgets/lotus_logo.dart';
import '../domain/access_state.dart';

/// Modal advertising the next retreat. Shown from the configured start date
/// while the user still has access — always closeable.
class NextEventPopup extends StatelessWidget {
  final AccessState access;
  const NextEventPopup({super.key, required this.access});

  static Future<void> show(BuildContext context, AccessState access) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.35),
      builder: (_) => NextEventPopup(access: access),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: _PopupCard(access: access, showClose: true),
    );
  }
}

class _PopupCard extends StatelessWidget {
  final AccessState access;
  final bool showClose;
  const _PopupCard({required this.access, required this.showClose});

  @override
  Widget build(BuildContext context) {
    final hasImage =
        access.popupImageUrl != null && access.popupImageUrl!.isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), AppTheme.sageSoft],
        ),
        borderRadius: BorderRadius.circular(24),
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
                    borderRadius: BorderRadius.circular(16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 320),
                      child: Image.network(
                        access.popupImageUrl!,
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
                  access.popupTitle?.isNotEmpty == true
                      ? access.popupTitle!
                      : 'Our Next Gathering',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (access.popupBody?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Text(
                    access.popupBody!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
                const SizedBox(height: 22),
                if (showClose)
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

/// The same card rendered inline (no close button) — used as the entire home
/// body once access has expired.
class NextEventInlineCard extends StatelessWidget {
  final AccessState access;
  const NextEventInlineCard({super.key, required this.access});

  @override
  Widget build(BuildContext context) {
    return _PopupCard(access: access, showClose: false);
  }
}
