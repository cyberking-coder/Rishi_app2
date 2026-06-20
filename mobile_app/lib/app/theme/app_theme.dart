import 'package:flutter/material.dart';

/// Light, minimal wellness theme: warm off-white surfaces, soft lotus-violet
/// accent, generous spacing and rounded cards so content feels calm and
/// uncluttered.
class AppTheme {
  AppTheme._();

  // Soft, airy aqua neutrals — the pale spa background from the design.
  static const Color background = Color(0xFFE6F2F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceElevated = Color(0xFFDDEEEB);

  // Calming teal accent (primary) + a soft rose secondary — the two signature
  // colours of the meditation palette.
  static const Color accent = Color(0xFF5FBFC2); // teal
  static const Color accentSoft = Color(0xFFDDF0EF); // pale teal
  static const Color accentPink = Color(0xFFF2A7BF); // rose
  static const Color accentPinkSoft = Color(0xFFFBDDE6); // pale rose

  // Text.
  static const Color textPrimary = Color(0xFF2C3F44);
  static const Color textSecondary = Color(0xFF7E9498);

  // Soft ambient backdrop — a calm wash used behind the home and player
  // screens. Pink at the top fading through white to aqua at the bottom,
  // echoing the reference welcome cards.
  static const Color washTop = Color(0xFFFCE6EC); // pale rose
  static const Color washMid = Color(0xFFF4FAF9); // near-white aqua
  static const Color washBottom = Color(0xFFE0F1EE); // pale aqua
  static const Color blobViolet = Color(0x4FF2A7BF); // rose glow
  static const Color blobPeach = Color(0x40F6B6C8); // soft pink glow
  static const Color blobMint = Color(0x4A8FD8D6); // teal glow

  static const LinearGradient ambientWash = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [washTop, washMid, washBottom],
    stops: [0.0, 0.5, 1.0],
  );

  // Welcome-card gradient (rose → teal), the hero look of the design.
  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF7B7CB), Color(0xFFF2A7BF), Color(0xFF6FC8C9)],
    stops: [0.0, 0.45, 1.0],
  );

  // Teal pill gradient used on primary call-to-action buttons.
  static const LinearGradient tealGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF74CDCE), Color(0xFF52B6BA)],
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
