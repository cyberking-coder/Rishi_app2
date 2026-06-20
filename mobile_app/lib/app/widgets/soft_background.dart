import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A calm, decorative backdrop: a gentle vertical wash plus two large,
/// heavily-blurred colour blobs that give the screen depth without
/// distracting from the content. Drop it as the bottom layer of a Stack.
class SoftBackground extends StatelessWidget {
  const SoftBackground({super.key});

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: const BoxDecoration(gradient: AppTheme.ambientWash),
          child: Stack(
            children: [
              // Top-right lotus-violet glow.
              Positioned(
                top: -130,
                right: -100,
                child: _Blob(color: AppTheme.blobViolet, size: 320),
              ),
              // Mid-left faint mint, adds depth between the two main glows.
              Positioned(
                top: 220,
                left: -140,
                child: _Blob(color: AppTheme.blobMint, size: 260),
              ),
              // Lower-right warm peach glow.
              Positioned(
                bottom: -160,
                right: -120,
                child: _Blob(color: AppTheme.blobPeach, size: 360),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  final Color color;
  final double size;
  const _Blob({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color, color.withValues(alpha: 0)],
        ),
      ),
    );
  }
}
