import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/lotus_logo.dart';
import '../../application/auth_providers.dart';

/// The branded opening screen: a soft sage wash behind the lotus mark and
/// the "Anurag Rishi — Find Peace Within" wordmark. Holds for a moment, then
/// routes to /home or /login depending on whether a session is active.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _scale;
  Timer? _navTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _scale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    _controller.forward();

    // Hold the splash briefly, then route based on the auth session.
    _navTimer = Timer(const Duration(milliseconds: 2600), _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    final loggedIn = ref.read(authRepositoryProvider).currentUser != null;
    context.go(loggedIn ? '/home' : '/login');
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.25),
            radius: 0.95,
            colors: [
              Color(0xFFFFFFFF), // light core behind the mark
              AppTheme.sageSoft, // mid
              AppTheme.background, // warm edges
            ],
            stops: [0.0, 0.55, 1.0],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fade,
            child: ScaleTransition(
              scale: _scale,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Glowing lotus ──
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.sage.withValues(alpha: 0.22),
                          blurRadius: 60,
                          spreadRadius: 12,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: LotusLogo(size: 96, color: AppTheme.sage),
                    ),
                  ),
                  const SizedBox(height: 36),
                  // ── Small diamond accent ──
                  Transform.rotate(
                    angle: 0.785398,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: AppTheme.sand,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // ── Wordmark ──
                  const Text(
                    'Anurag Rishi',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find Peace Within',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
