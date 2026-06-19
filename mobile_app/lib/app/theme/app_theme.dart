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
