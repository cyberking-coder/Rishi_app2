import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../application/auth_providers.dart';

/// "Continue with Apple" — shown on iOS only.
///
/// Required by App Store Guideline 4.8: an app offering a third-party
/// login must offer this one alongside it, and Apple's Human Interface
/// Guidelines ask that it be no less prominent than the alternatives.
/// Hence the same height, the same corner radius and the same position
/// in the stack as the Google button, not a smaller afterthought below
/// it.
///
/// Hidden on Android, where it would be a button with nothing behind it:
/// the plugin can fall back to a web flow there, but that means a
/// password prompt in a browser to satisfy a rule Android does not have.
class AppleSignInButton extends ConsumerWidget {
  final bool enabled;

  const AppleSignInButton({super.key, this.enabled = true});

  /// Whether this platform should show it at all. Guarded on kIsWeb
  /// first because Platform.isIOS throws on web rather than returning
  /// false.
  static bool get isSupported => !kIsWeb && Platform.isIOS;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!isSupported) return const SizedBox.shrink();

    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled
            ? () => ref.read(authControllerProvider.notifier).signInWithApple()
            : null,
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            // Apple's own black button, not a themed one. The mark and
            // its background are prescribed, and a sage-tinted version
            // is the kind of thing review sends back.
            color: Colors.black,
            borderRadius: BorderRadius.circular(AppTheme.radiusRow),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // The system glyph, so it matches whatever the platform
              // draws elsewhere rather than a hand-copied outline.
              Icon(Icons.apple, color: Colors.white, size: 26),
              SizedBox(width: 10),
              Text(
                'Continue with Apple',
                style: TextStyle(
                  fontFamily: AppTheme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
