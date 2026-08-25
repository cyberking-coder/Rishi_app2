import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../app/widgets/lotus_logo.dart';
import '../../../../app/widgets/soft_halo.dart';
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
                  const SizedBox(
                    width: 260,
                    height: 260,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SoftHalo(size: 260),
                        LotusLogo(size: 120, color: AppTheme.sage),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // ── Small diamond accent ──
                  Transform.rotate(
                    angle: 0.785398,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: AppTheme.sand,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  // ── Wordmark ──
                  // AppTheme.display, whatever that currently is —
                  // the wordmark should never be the one place in the
                  // app running its own face.
                  const Text(
                    'Anurag Rishi',
                    style: TextStyle(
                      fontFamily: AppTheme.display,
                      color: AppTheme.textPrimary,
                      fontSize: 34,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Find Peace Within',
                    style: TextStyle(
                      fontFamily: AppTheme.text,
                      color: AppTheme.textSecondary,
                      fontSize: 15.5,
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
