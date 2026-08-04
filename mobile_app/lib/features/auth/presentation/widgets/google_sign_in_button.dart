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

/// Google's four-colour G.
///
/// The real mark, drawn from the outline data Google publishes — not an
/// approximation. A first attempt built it as four coloured arcs plus a
/// crossbar, which is roughly how the logo is constructed but not
/// actually its geometry: the arc weights, the angles where the colours
/// hand over, and the shape of the bar are all specific, and a version
/// that is nearly right reads as a cheap imitation of a logo everybody
/// has seen ten thousand times.
///
/// Still painted rather than shipped as a PNG, so it stays sharp at any
/// size and needs no density exports.
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
  /// Google's published brand values, each with the outline it fills.
  /// Authored against a 48×48 box and scaled to whatever is asked for.
  static const _viewBox = 48.0;

  static const _segments = <(Color, String)>[
    (
      Color(0xFFEA4335),
      'M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 '
          '14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z'
    ),
    (
      Color(0xFF4285F4),
      'M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 '
          '5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z'
    ),
    (
      Color(0xFFFBBC05),
      'M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C'
          '.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.55 10.78l7.98-6.19z'
    ),
    (
      Color(0xFF34A853),
      'M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 '
          '2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z'
    ),
  ];

  /// Parsed once for the whole app rather than on every paint. The
  /// outlines never change, and this widget appears on two screens that
  /// repaint on every keystroke.
  static final _outlines = [
    for (final (color, data) in _segments) (color, _parse(data)),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _viewBox, size.height / _viewBox);
    final paint = Paint()..isAntiAlias = true;
    for (final (color, outline) in _outlines) {
      paint.color = color;
      canvas.drawPath(outline, paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GooglePainter old) => false;

  /// A path-data reader covering exactly the commands the four outlines
  /// above use: M, L, H, V, C, S, Z and their relative forms, plus the
  /// implicit repeat where a command's arguments run on without the
  /// letter being written again.
  ///
  /// Deliberately not a general SVG parser. Arcs, quadratics and
  /// transforms are absent because nothing here needs them, and an
  /// unsupported command throws rather than being skipped — silently
  /// dropping a segment would leave a logo that is subtly wrong, which
  /// is the exact failure this replaced.
  static Path _parse(String d) {
    final tokens = _tokenPattern.allMatches(d).map((m) => m[0]!).toList();
    final path = Path();

    var i = 0;
    var command = '';
    var repeating = false;
    var cursor = Offset.zero;
    var subpathStart = Offset.zero;
    Offset? lastControl;

    double next() => double.parse(tokens[i++]);

    while (i < tokens.length) {
      final token = tokens[i];
      if (_letterPattern.hasMatch(token)) {
        command = token;
        repeating = false;
        i++;
        if (command == 'Z' || command == 'z') {
          path.close();
          cursor = subpathStart;
          lastControl = null;
          continue;
        }
      }

      // A second coordinate pair after M continues as a line, which is
      // what the spec says and what these outlines rely on.
      var effective = command;
      if (repeating && (command == 'M' || command == 'm')) {
        effective = command == 'M' ? 'L' : 'l';
      }
      final relative = effective.toLowerCase() == effective;
      final base = relative ? cursor : Offset.zero;

      switch (effective.toUpperCase()) {
        case 'M':
          cursor = base + Offset(next(), next());
          path.moveTo(cursor.dx, cursor.dy);
          subpathStart = cursor;
          lastControl = null;
        case 'L':
          cursor = base + Offset(next(), next());
          path.lineTo(cursor.dx, cursor.dy);
          lastControl = null;
        case 'H':
          cursor = Offset(base.dx + next(), cursor.dy);
          path.lineTo(cursor.dx, cursor.dy);
          lastControl = null;
        case 'V':
          cursor = Offset(cursor.dx, base.dy + next());
          path.lineTo(cursor.dx, cursor.dy);
          lastControl = null;
        case 'C':
          final c1 = base + Offset(next(), next());
          final c2 = base + Offset(next(), next());
          final end = base + Offset(next(), next());
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
          lastControl = c2;
          cursor = end;
        case 'S':
          // The first control point is the previous one reflected
          // through the current point — that reflection is the whole
          // meaning of a smooth curve, and dropping it would flatten
          // the yellow segment's shoulder.
          final c2 = base + Offset(next(), next());
          final end = base + Offset(next(), next());
          final c1 = lastControl == null ? cursor : cursor * 2 - lastControl;
          path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, end.dx, end.dy);
          lastControl = c2;
          cursor = end;
        default:
          throw UnsupportedError('Unsupported path command: $effective');
      }

      repeating = true;
    }

    return path;
  }

  static final _tokenPattern = RegExp(
    r'[MmLlHhVvCcSsZz]|[-+]?(?:\d*\.\d+|\d+)(?:[eE][-+]?\d+)?',
  );
  static final _letterPattern = RegExp(r'^[A-Za-z]$');
}
