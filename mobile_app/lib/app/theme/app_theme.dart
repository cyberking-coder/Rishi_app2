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

  // Soft ambient backdrop — gentle, low-saturation wash used behind the
  // home and player screens. Three barely-there tints that blend into the
  // warm neutral so nothing competes with the content.
  static const Color washTop = Color(0xFFF3EEFB); // faint lavender
  static const Color washMid = Color(0xFFF7F5F2); // warm neutral
  static const Color washBottom = Color(0xFFFDF1EC); // faint peach
  static const Color blobViolet = Color(0x267C6BB0); // 15% lotus-violet
  static const Color blobPeach = Color(0x22F0A98E); // ~13% peach

  static const LinearGradient ambientWash = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [washTop, washMid, washBottom],
    stops: [0.0, 0.55, 1.0],
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

  /// Kept for any callers still referencing the old name; returns the light
  /// theme so the whole app shares one look.
  static ThemeData dark() => light();
}
