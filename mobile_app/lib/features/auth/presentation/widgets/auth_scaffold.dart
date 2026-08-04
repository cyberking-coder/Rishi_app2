import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/botanical.dart';

/// The frame every auth screen sits in: warm wash, leaves in the corners,
/// a scrolling body, and an optional deep-sage band closing the bottom.
///
/// One widget rather than three near-copies. The login, signup and
/// forgot-password screens differ only in their contents; when they each
/// owned their own Stack the three drifted apart within a single round of
/// edits.
class AuthScaffold extends StatelessWidget {
  final Widget child;

  /// The curved band at the very bottom. Null on the shorter screens,
  /// where a footer would sit halfway up an empty page.
  final Widget? footer;

  /// Shown as a circular back button over the top-left of the content.
  final String? title;

  const AuthScaffold({
    super.key,
    required this.child,
    this.footer,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      // The keyboard resizes the body, which is what lets the footer
      // ride out of view instead of covering the field being typed into.
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF7F6F0), AppTheme.background],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -10,
              right: -58,
              child: LeafSprig(size: 190, angle: -0.32, opacity: 0.45, flip: true),
            ),
            const Positioned(
              top: 90,
              left: -70,
              child: LeafSprig(size: 165, angle: 0.4, opacity: 0.4),
            ),
            const Positioned(
              bottom: 190,
              left: -74,
              child: LeafSprig(size: 175, angle: -0.5, opacity: 0.38, flip: true),
            ),
            const Positioned(
              bottom: 230,
              right: -76,
              child: LeafSprig(size: 170, angle: 0.45, opacity: 0.34),
            ),

            SafeArea(
              // A LayoutBuilder so the footer can be pushed to the bottom
              // of the *viewport* when the content is short, and simply
              // follow the content when it is long. A bottom-pinned Stack
              // child would have covered the fields the moment the
              // keyboard opened.
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (title != null) _TitleBar(title: title!),
                            Padding(
                              padding: EdgeInsets.fromLTRB(
                                20,
                                title == null ? 8 : 0,
                                20,
                                20,
                              ),
                              child: child,
                            ),
                            if (footer != null) ...[
                              const Expanded(child: SizedBox()),
                              footer!,
                            ] else
                              const Expanded(child: SizedBox()),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TitleBar extends StatelessWidget {
  final String title;

  const _TitleBar({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 20, 4),
      child: Row(
        children: [
          // A circular button rather than the bare arrow: on a page with
          // no app bar, an unbounded chevron floating over a leaf reads
          // as decoration and doesn't get tapped.
          Material(
            color: AppTheme.sageSoft,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => Navigator.of(context).maybePop(),
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Icon(Icons.arrow_back_rounded,
                    size: 21, color: AppTheme.textPrimary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontFamily: AppTheme.display,
              fontSize: 26,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// The deep-sage band that closes the login screen, curved along its top
/// edge so it reads as a horizon rather than as a toolbar.
class AuthFooterNote extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const AuthFooterNote({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return ClipPath(
      clipper: _CurvedTopClipper(),
      child: Container(
        width: double.infinity,
        color: AppTheme.sageDark,
        padding: const EdgeInsets.fromLTRB(24, 54, 24, 26),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(icon, size: 21, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: AppTheme.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    body,
                    style: TextStyle(
                      fontFamily: AppTheme.text,
                      fontSize: 13,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A single sweeping curve across the top edge. Deliberately shallow and
/// asymmetric — a symmetric arc reads as a speech bubble.
class _CurvedTopClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, size.height)
      ..lineTo(0, 52)
      ..cubicTo(
        size.width * 0.28, 4,
        size.width * 0.62, 46,
        size.width, 0,
      )
      ..lineTo(size.width, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_CurvedTopClipper old) => false;
}

/// The pale card carrying a standing note — the device lock on login, the
/// security line on signup.
class AuthInfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const AuthInfoCard({
    super.key,
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.sageSoft.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(AppTheme.radiusRow),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.sageDark,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontFamily: AppTheme.text,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: const TextStyle(
                    fontFamily: AppTheme.text,
                    fontSize: 13,
                    height: 1.42,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The "or" rule between the primary action and Google.
class AuthDivider extends StatelessWidget {
  const AuthDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppTheme.borderStrong)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'or',
            style: TextStyle(
              fontFamily: AppTheme.text,
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppTheme.borderStrong)),
      ],
    );
  }
}

/// The filled action on the auth screens: a deep sage gradient, tall
/// enough to be the obvious next step on the page.
///
/// Not a themed FilledButton, because the theme's button is a flat fill
/// and the gradient is the whole point of this one. Everything else about
/// it — disabled handling, the spinner while a request is in flight —
/// matches what the FilledButton did before.
class PrimaryGradientButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool loading;

  /// The circular arrow on the right, as on "Create account".
  final bool showArrow;

  const PrimaryGradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.showArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;

    return Opacity(
      opacity: enabled ? 1 : 0.65,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(AppTheme.radiusRow),
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF5B8B79), Color(0xFF2F5347)],
              ),
              borderRadius: BorderRadius.circular(AppTheme.radiusRow),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.sageDark.withValues(alpha: 0.32),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (loading)
                  const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                else
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: AppTheme.text,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                if (showArrow && !loading)
                  Positioned(
                    right: 16,
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.16),
                      ),
                      child: const Icon(Icons.arrow_forward_rounded,
                          size: 18, color: Colors.white),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
