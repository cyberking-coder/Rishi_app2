import 'package:flutter/material.dart';

/// Light, minimal wellness theme: warm off-white surfaces, soft lotus-violet
/// accent, generous spacing and rounded cards so content feels calm and
/// uncluttered.
class AppTheme {
  AppTheme._();

  // Warm, airy neutrals.
  static const Color background = Color(0xFFF7F5F2);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFEFEAE3);

  // Calming lotus-violet accent + a soft secondary.
  static const Color accent = Color(0xFF7C6BB0);
  static const Color accentSoft = Color(0xFFEDE7F6);

  // Text.
  static const Color textPrimary = Color(0xFF221C32);
  static const Color textSecondary = Color(0xFF7A7486);

  // Soft ambient backdrop — a calm wash used behind the home and player
  // screens. Present enough to feel crafted, low-saturation enough to stay
  // serene.
  static const Color washTop = Color(0xFFEDE6FA); // soft lavender
  static const Color washMid = Color(0xFFF7F4FB); // pale violet-white
  static const Color washBottom = Color(0xFFFDEFE7); // warm peach
  static const Color blobViolet = Color(0x4A9C8BD6); // lotus-violet glow
  static const Color blobPeach = Color(0x3DF3B79C); // warm peach glow
  static const Color blobMint = Color(0x2E9AD6C4); // faint mint, for depth

  static const LinearGradient ambientWash = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [washTop, washMid, washBottom],
    stops: [0.0, 0.5, 1.0],
  );

  // Warm welcome-card gradient (lotus-violet → soft rose).
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B79C4), Color(0xFFC79BC4), Color(0xFFE9B59E)],
    stops: [0.0, 0.6, 1.0],
  );

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.light,
        surface: surface,
        primary: accent,
        secondary: accent,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      iconTheme: const IconThemeData(color: textPrimary),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: Color(0xFFE3DEEC),
      ),
      dividerTheme: const DividerThemeData(color: Color(0x14221C32)),
      splashFactory: InkRipple.splashFactory,
    );
  }

  static ThemeData dark() {
    const bg = Color(0xFF12082E);
    const surface = Color(0xFF1C1040);
    const accent = Color(0xFF8B5CF6);
    const textPrimary = Colors.white;

    final base = ThemeData.dark(useMaterial3: true);
    return base.copyWith(
      scaffoldBackgroundColor: bg,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        surface: surface,
        primary: accent,
        secondary: accent,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      textTheme: base.textTheme.apply(
        bodyColor: textPrimary,
        displayColor: textPrimary,
      ),
      iconTheme: const IconThemeData(color: textPrimary),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: accent),
      dividerTheme: const DividerThemeData(color: Color(0x22FFFFFF)),
    );
  }
}
