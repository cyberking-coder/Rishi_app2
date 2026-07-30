import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A simple, scalable lotus mark drawn with a CustomPainter — no asset file
/// needed. Used in the app bar and anywhere the brand needs to appear.
class LotusLogo extends StatelessWidget {
  final double size;
  final Color? color;

  const LotusLogo({super.key, this.size = 28, this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LotusPainter(color ?? AppTheme.sage),
      ),
    );
  }
}

class _LotusPainter extends CustomPainter {
  final Color color;

  _LotusPainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    // Petals fan out from a point near the bottom-centre.
    final originX = w / 2;
    final originY = h * 0.80;
    final petalLen = h * 0.70;
    final petalWidth = w * 0.26;

    final fill = Paint()
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // angle (from vertical), length factor, shade toward accent.
    final petals = <List<double>>[
      [-0.95, 0.72, 0.50],
      [0.95, 0.72, 0.50],
      [-0.48, 0.90, 0.74],
      [0.48, 0.90, 0.74],
      [0.0, 1.0, 1.0],
    ];

    for (final p in petals) {
      final angle = p[0];
      final lenFactor = p[1];
      final shade = p[2];
      fill.color = Color.lerp(Colors.white, color, shade)!;

      canvas.save();
      canvas.translate(originX, originY);
      canvas.rotate(angle);
      _drawPetal(canvas, fill, petalLen * lenFactor, petalWidth * lenFactor);
      canvas.restore();
    }
  }

  /// Draws one upward teardrop petal rooted at the current origin.
  void _drawPetal(Canvas canvas, Paint paint, double length, double width) {
    final path = Path()
      ..moveTo(0, 0)
      ..cubicTo(-width, -length * 0.35, -width * 0.55, -length, 0, -length)
      ..cubicTo(width * 0.55, -length, width, -length * 0.35, 0, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_LotusPainter old) => old.color != color;
}
