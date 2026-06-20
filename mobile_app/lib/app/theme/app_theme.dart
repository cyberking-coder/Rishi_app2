import 'package:flutter/material.dart';

/// Deep, calming night-sky theme: indigo/violet surfaces, a luminous violet
/// accent and soft glows — matching the Anurag Rishi meditation design.
class AppTheme {
  AppTheme._();

  // Night-sky surfaces.
  static const Color canvas = Color(0xFF0B0A1E); // deepest backdrop
  static const Color background = Color(0xFF14102E); // deep indigo screen
  static const Color surface = Color(0xFF221B46); // card
  static const Color surfaceElevated = Color(0xFF2A2150); // raised card

  // Luminous violet accent + soft secondary, plus a pink chakra accent.
  static const Color accent = Color(0xFF8B5CF6); // violet
  static const Color accentBright = Color(0xFFA78BFA); // lighter violet
  static const Color accentSoft = Color(0xFF2B2358); // muted violet fill
  static const Color accentPink = Color(0xFFEC4899); // pink
  static const Color accentPinkSoft = Color(0xFF3A2150); // muted pink fill
  static const Color indigo = Color(0xFF6366F1);

  // Text on the dark canvas.
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFB9B3D9);
  static const Color textDim = Color(0xFF7F79A3);

  // Hairline divider/border on dark surfaces.
  static const Color line = Color(0x14FFFFFF);

  // Ambient backdrop — a deep indigo wash that the glow blobs sit on.
  static const Color washTop = Color(0xFF1C1640);
  static const Color washMid = Color(0xFF14102E);
  static const Color washBottom = Color(0xFF120E26);
  static const Color blobViolet = Color(0x4F8B5CF6); // violet glow
  static const Color blobPeach = Color(0x33EC4899); // pink glow
  static const Color blobMint = Color(0x3D6366F1); // indigo glow

  static const LinearGradient ambientWash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [washTop, washMid, washBottom],
    stops: [0.0, 0.55, 1.0],
  );

  // Hero / CTA gradient (violet → deep violet) — the signature button look.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFF6D44E0)],
  );

  // Conic spectrum used behind the now-playing disc.
  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFF6D44E0)],
  );

  static ThemeData light() {
    final base = ThemeData.dark(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.dark,
        surface: surface,
        primary: accent,
        secondary: accentBright,
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
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.06),
        hintStyle: const TextStyle(color: textDim),
        labelStyle: const TextStyle(color: textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: accent),
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accent,
        linearTrackColor: Color(0x1FFFFFFF),
      ),
      dividerTheme: const DividerThemeData(color: line),
      splashFactory: InkRipple.splashFactory,
    );
  }

  /// Kept for any callers still referencing the old name; returns the single
  /// shared (dark) theme.
  static ThemeData dark() => light();
}
