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
              // Top-right violet glow.
              Positioned(
                top: -120,
                right: -90,
                child: _Blob(color: AppTheme.blobViolet, size: 300),
              ),
              // Top-left indigo glow.
              Positioned(
                top: -60,
                left: -110,
                child: _Blob(color: AppTheme.blobMint, size: 240),
              ),
              // Mid violet glow, gives the screen a luminous centre.
              Positioned(
                top: 260,
                left: 40,
                child: _Blob(color: AppTheme.blobViolet, size: 280),
              ),
              // Lower-right pink glow.
              Positioned(
                bottom: -150,
                right: -110,
                child: _Blob(color: AppTheme.blobPeach, size: 320),
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
