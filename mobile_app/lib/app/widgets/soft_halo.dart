import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The luminous disc the lotus and the auth avatars sit inside.
///
/// A radial gradient rather than a blurred circle: same look, no filter
/// pass, and it stays crisp at any size.
///
/// This is what survives of the old botanical layer. The leaf sprigs,
/// misty hills and sparkles were part of the sage design and read as
/// clutter against the violet glass one, so they went; the halo stayed
/// because it is doing structural work — it is the only thing separating
/// the lotus from the page behind it.
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
