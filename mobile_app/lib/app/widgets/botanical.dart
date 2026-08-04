import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The botanical layer the design rests on: leaf sprigs in the corners,
/// misty hills along the bottom, a soft halo behind the brand mark.
///
/// Painted rather than shipped as artwork. Four reasons, in order of how
/// much they mattered: it scales to every screen size without a set of
/// @2x/@3x exports; it costs no download and no app size; it recolours
/// with the theme instead of baking a palette into a PNG; and a sprig can
/// be placed at any angle and scale without a new file. The trade is that
/// these read as clean botanical line-and-wash rather than as painted
/// watercolour — closer to the design's structure than to its brushwork.
///
/// Everything here is decoration and nothing here is interactive. All of
/// it sits under [IgnorePointer] so it can never eat a tap meant for the
/// content above.

// ── Leaves ───────────────────────────────────────────────────────────

/// A stem with leaves along it, drawn from the origin outwards.
///
/// The parameters are the ones that actually change between placements —
/// how long, how many, which way, how strong. Everything else is fixed so
/// twelve sprigs across the app can't drift into twelve different plants.
class LeafSprig extends StatelessWidget {
  final double size;

  /// Rotation in radians. 0 points the stem to the right.
  final double angle;

  /// 0–1. The design keeps these very faint; above about 0.5 they stop
  /// being a backdrop and start competing with the content.
  final double opacity;

  final Color color;

  /// Leaves per side. Three or four reads as a sprig; more reads as a
  /// fern, which is a different plant and a different design.
  final int leaves;

  /// Mirrors the sprig. Two sprigs of the same handedness facing each
  /// other across a screen look like a repeated stamp.
  final bool flip;

  const LeafSprig({
    super.key,
    this.size = 160,
    this.angle = 0,
    this.opacity = 0.5,
    this.color = AppTheme.sageLight,
    this.leaves = 4,
    this.flip = false,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Transform.rotate(
        angle: angle,
        child: Transform.scale(
          scaleY: flip ? -1 : 1,
          child: SizedBox(
            width: size,
            height: size * 0.62,
            child: CustomPaint(
              painter: _SprigPainter(
                color: color,
                opacity: opacity,
                leafCount: leaves,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SprigPainter extends CustomPainter {
  final Color color;
  final double opacity;
  final int leafCount;

  _SprigPainter({
    required this.color,
    required this.opacity,
    required this.leafCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // The stem is one long curve; leaves are placed along it by walking
    // the same curve with a metric, so a leaf never floats off the stem
    // when the size changes.
    final stem = Path()
      ..moveTo(0, h * 0.5)
      ..quadraticBezierTo(w * 0.45, h * 0.34, w, h * 0.10);

    canvas.drawPath(
      stem,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(1.0, w * 0.007)
        ..strokeCap = StrokeCap.round
        ..color = color.withValues(alpha: opacity * 0.55)
        ..isAntiAlias = true,
    );

    final metric = stem.computeMetrics().first;
    final fill = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    final vein = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    for (var i = 0; i < leafCount; i++) {
      // Start a third of the way along: leaves crowding the base make the
      // sprig look cut off rather than growing out of frame.
      final t = 0.30 + (i / leafCount) * 0.68;
      final pos = metric.getTangentForOffset(metric.length * t);
      if (pos == null) continue;

      // Leaves shrink towards the tip, which is what makes a stem read as
      // having a direction at all.
      final scale = 1 - (i / leafCount) * 0.34;
      final leafLen = w * 0.30 * scale;
      final leafWidth = leafLen * 0.42;

      final stemAngle = math.atan2(pos.vector.dy, pos.vector.dx);

      // A pair per node, angled off the stem in both directions, with the
      // pair alternating slightly so the sprig isn't perfectly symmetric.
      for (final side in [-1.0, 1.0]) {
        final spread = 0.62 + (i.isEven ? 0.10 : -0.10);
        canvas.save();
        canvas.translate(pos.position.dx, pos.position.dy);
        canvas.rotate(stemAngle + side * spread);

        fill.color = color.withValues(
          // Alternating weight per node stops the sprig reading as a
          // stencil — real leaves catch the light unevenly.
          alpha: opacity * (i.isEven ? 0.85 : 0.62),
        );
        final leaf = _leafPath(leafLen, leafWidth);
        canvas.drawPath(leaf, fill);

        vein
          ..strokeWidth = math.max(0.6, leafLen * 0.02)
          ..color = color.withValues(alpha: opacity * 0.5);
        canvas.drawLine(Offset.zero, Offset(leafLen * 0.88, 0), vein);

        canvas.restore();
      }
    }
  }

  /// One leaf, pointing along +x from the origin. Two mirrored cubics
  /// give the asymmetric almond shape; a true ellipse reads as a seed.
  Path _leafPath(double length, double width) {
    return Path()
      ..moveTo(0, 0)
      ..cubicTo(
        length * 0.32, -width,
        length * 0.74, -width * 0.82,
        length, 0,
      )
      ..cubicTo(
        length * 0.74, width * 0.82,
        length * 0.32, width,
        0, 0,
      )
      ..close();
  }

  @override
  bool shouldRepaint(_SprigPainter old) =>
      old.color != color ||
      old.opacity != opacity ||
      old.leafCount != leafCount;
}

// ── Hills ────────────────────────────────────────────────────────────

/// The layered misty landscape that closes the bottom of the full-bleed
/// screens (splash, downloads, profile).
///
/// Three overlapping ridges, each paler than the one in front, plus a
/// still-water sheen at the base. Depth here comes from opacity alone —
/// no blur — because a blurred layer this size costs a real shader pass
/// on every frame for something the eye reads as haze either way.
class MistyHills extends StatelessWidget {
  final double height;
  final Color color;

  const MistyHills({super.key, this.height = 220, this.color = AppTheme.sage});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(painter: _HillsPainter(color)),
      ),
    );
  }
}

class _HillsPainter extends CustomPainter {
  final Color color;

  _HillsPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()..isAntiAlias = true;

    // Back to front: each ridge sits lower and reads stronger.
    const ridges = <_Ridge>[
      _Ridge(top: 0.30, peak: 0.10, alpha: 0.10, from: 0.10, to: 0.62),
      _Ridge(top: 0.48, peak: 0.26, alpha: 0.14, from: 0.55, to: 1.05),
      _Ridge(top: 0.62, peak: 0.44, alpha: 0.18, from: -0.05, to: 0.45),
    ];

    for (final r in ridges) {
      final path = Path()..moveTo(0, h);
      path.lineTo(0, h * r.top);
      // Two control points per ridge give an asymmetric silhouette; a
      // single quadratic makes every hill the same dome.
      path.cubicTo(
        w * r.from, h * r.peak,
        w * r.to, h * (r.peak + 0.18),
        w, h * (r.top - 0.06),
      );
      path.lineTo(w, h);
      path.close();

      paint.color = color.withValues(alpha: r.alpha);
      canvas.drawPath(path, paint);
    }

    // Water: a pale band with a brighter centre line, which is what makes
    // the base read as a still surface rather than as more hillside.
    final waterTop = h * 0.80;
    canvas.drawRect(
      Rect.fromLTRB(0, waterTop, w, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withValues(alpha: 0.06),
            color.withValues(alpha: 0.13),
          ],
        ).createShader(Rect.fromLTRB(0, waterTop, w, h)),
    );

    canvas.drawRect(
      Rect.fromLTRB(w * 0.34, waterTop, w * 0.66, h),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withValues(alpha: 0.42),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTRB(w * 0.34, waterTop, w * 0.66, h)),
    );
  }

  @override
  bool shouldRepaint(_HillsPainter old) => old.color != color;
}

class _Ridge {
  final double top;
  final double peak;
  final double alpha;
  final double from;
  final double to;

  const _Ridge({
    required this.top,
    required this.peak,
    required this.alpha,
    required this.from,
    required this.to,
  });
}

// ── Halo ─────────────────────────────────────────────────────────────

/// The luminous disc the lotus and the auth avatars sit inside.
///
/// A radial gradient rather than a blurred circle: same look, no filter
/// pass, and it stays crisp at any size.
class SoftHalo extends StatelessWidget {
  final double size;
  final Widget? child;
  final Color color;

  const SoftHalo({
    super.key,
    required this.size,
    this.child,
    this.color = AppTheme.sageSoft,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.95),
            color.withValues(alpha: 0.55),
            color.withValues(alpha: 0.0),
          ],
          stops: const [0.0, 0.62, 1.0],
        ),
      ),
      child: child == null ? null : Center(child: child),
    );
  }
}

/// Four small four-pointed sparkles, the ones scattered around the lotus
/// and the achievement tiles. Positions are fractions of the box so the
/// same widget works at 60px and at 300px.
class Sparkles extends StatelessWidget {
  final double size;
  final Color color;

  const Sparkles({
    super.key,
    required this.size,
    this.color = AppTheme.sand,
  });

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: _SparklePainter(color)),
      ),
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Color color;

  _SparklePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    // x, y, radius and alpha as fractions — deliberately irregular, since
    // four sparkles on a grid read as a loading indicator.
    const spots = <List<double>>[
      [0.16, 0.26, 0.055, 0.9],
      [0.82, 0.18, 0.038, 0.7],
      [0.72, 0.80, 0.030, 0.55],
      [0.28, 0.86, 0.042, 0.75],
    ];

    for (final s in spots) {
      final centre = Offset(size.width * s[0], size.height * s[1]);
      final r = size.width * s[2];
      // A four-pointed star: two cubics pinched at the waist, which is
      // what gives the concave sides. A rotated square would not.
      final path = Path()
        ..moveTo(centre.dx, centre.dy - r)
        ..quadraticBezierTo(centre.dx, centre.dy, centre.dx + r, centre.dy)
        ..quadraticBezierTo(centre.dx, centre.dy, centre.dx, centre.dy + r)
        ..quadraticBezierTo(centre.dx, centre.dy, centre.dx - r, centre.dy)
        ..quadraticBezierTo(centre.dx, centre.dy, centre.dx, centre.dy - r)
        ..close();

      canvas.drawPath(
        path,
        Paint()
          ..color = color.withValues(alpha: s[3])
          ..isAntiAlias = true,
      );
    }
  }

  @override
  bool shouldRepaint(_SparklePainter old) => old.color != color;
}

// Sprig placement is left to each screen rather than wrapped in a
// helper. An earlier BotanicalFrame with topLeft/topRight/bottomLeft
// flags turned out to be the wrong abstraction: every screen wanted a
// different size, angle and offset, so the flags were never enough and
// the Positioned values ended up back at the call site anyway.
