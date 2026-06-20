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
              // Top-right rose glow.
              Positioned(
                top: -140,
                right: -110,
                child: _Blob(color: AppTheme.blobViolet, size: 340),
              ),
              // Top-left soft pink, balances the rose glow.
              Positioned(
                top: -90,
                left: -130,
                child: _Blob(color: AppTheme.blobPeach, size: 260),
              ),
              // Lower-right teal glow.
              Positioned(
                bottom: -170,
                right: -130,
                child: _Blob(color: AppTheme.blobMint, size: 380),
              ),
              // Lower-left teal, mirrors the bottom glow.
              Positioned(
                bottom: -140,
                left: -120,
                child: _Blob(color: AppTheme.blobMint, size: 280),
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
