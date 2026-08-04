import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_theme.dart';
import '../../application/auth_providers.dart';

/// "Continue with Google" — used on both the login and signup screens; the
/// underlying action is identical (native Google Sign-In, then Supabase
/// signInWithIdToken), since a first-time Google user is auto-provisioned
/// by the same `handle_new_user` trigger as an email/password sign up.
class GoogleSignInButton extends ConsumerWidget {
  final bool enabled;

  /// Login shows it as a raised card; signup as an outline, so it reads as
  /// the quieter of the two options next to the filled "Create account".
  final bool outlined;

  const GoogleSignInButton({
    super.key,
    this.enabled = true,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Opacity(
      opacity: enabled ? 1 : 0.5,
      child: GestureDetector(
        onTap: enabled
            ? () => ref.read(authControllerProvider.notifier).signInWithGoogle()
            : null,
        child: Container(
          height: 58,
          decoration: outlined
              ? BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(AppTheme.radiusRow),
                  border: Border.all(color: AppTheme.sageLight),
                )
              : AppTheme.claySurface(radius: AppTheme.radiusRow),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const GoogleGlyph(size: 22),
              const SizedBox(width: 12),
              Text(
                'Continue with Google',
                style: TextStyle(
                  fontFamily: AppTheme.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: outlined ? AppTheme.sageDark : AppTheme.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Google's four-colour G, drawn rather than shipped as an asset.
///
/// Built the way the mark itself is: one ring split into four coloured
/// arcs with a gap on the right, plus the blue crossbar. Painted because
/// a PNG would need three densities and would still be the wrong shade
/// against a cream card at 1x.
class GoogleGlyph extends StatelessWidget {
  final double size;

  const GoogleGlyph({super.key, this.size = 22});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _GooglePainter()),
    );
  }
}

class _GooglePainter extends CustomPainter {
  // Google's published brand values.
  static const _blue = Color(0xFF4285F4);
  static const _red = Color(0xFFEA4335);
  static const _yellow = Color(0xFFFBBC05);
  static const _green = Color(0xFF34A853);

  static double _rad(double degrees) => degrees * math.pi / 180;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.27;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..isAntiAlias = true;

    // Angles run clockwise from 3 o'clock. The ring is closed except
    // between 0° and 25°, which is the G's opening beneath the bar.
    void segment(Color color, double startDeg, double sweepDeg) {
      arc.color = color;
      canvas.drawArc(rect, _rad(startDeg), _rad(sweepDeg), false, arc);
    }

    segment(_green, 25, 110); // lower right round to bottom left
    segment(_yellow, 135, 65); // left
    segment(_red, 200, 110); // over the top
    segment(_blue, 310, 50); // upper right, down to the bar

    // The crossbar. Reaches just past the centre, which is what turns a
    // coloured ring into a G.
    final cy = size.height / 2;
    canvas.drawRect(
      Rect.fromLTRB(
        size.width * 0.46,
        cy - stroke / 2,
        size.width - stroke / 2,
        cy + stroke / 2,
      ),
      Paint()..color = _blue,
    );
  }

  @override
  bool shouldRepaint(_GooglePainter old) => false;
}
