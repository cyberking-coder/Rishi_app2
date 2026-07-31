import 'package:flutter/material.dart';

/// Calm learning theme: sage green on warm cream. Sage carries every
/// interactive affordance, cream carries content surfaces, and the two
/// stay far enough apart in luminance that text never needs a shadow to
/// stay readable.
///
/// Screens should read from here rather than declaring their own
/// constants — the old per-screen colour blocks are what let the app
/// drift into two different visual languages at once.
class AppTheme {
  AppTheme._();

  // ── Core palette ────────────────────────────────────────────────────
  /// Page background. Warm off-white, never pure white — pure white next
  /// to the cream cards reads as a rendering bug rather than a choice.
  static const Color background = Color(0xFFF2F2EF);

  /// Cards and sheets that sit on [background].
  static const Color surface = Color(0xFFFFFFFF);

  /// Secondary surface for list rows — the cream tone from the reference
  /// lesson list. Warmer than [surface] so stacked rows separate without
  /// borders.
  static const Color surfaceCream = Color(0xFFFBF7EC);

  /// Primary brand + every primary action.
  static const Color sage = Color(0xFF5F8D7E);
  static const Color sageDark = Color(0xFF44675C);
  static const Color sageLight = Color(0xFF8FB3A6);

  /// Tinted fills for pills, badges and icon chips.
  static const Color sageSoft = Color(0xFFE3EDE8);

  /// Warm accent, used sparingly — bookmarks, highlights, "new" flags.
  static const Color sand = Color(0xFFEFD9A8);
  static const Color sandSoft = Color(0xFFFAF0DA);

  /// Locked/premium and destructive states.
  static const Color clay = Color(0xFFC97B5A);

  // ── Text ────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF25332C);
  static const Color textSecondary = Color(0xFF7C8A83);
  static const Color textOnSage = Color(0xFFFFFFFF);

  // ── Lines ───────────────────────────────────────────────────────────
  static const Color border = Color(0x1425332C);

  // ── Shape ───────────────────────────────────────────────────────────
  static const double radiusCard = 20;
  static const double radiusRow = 16;
  static const double radiusPill = 999;

  /// Soft lift for cards. Kept low-opacity and wide so cards feel like
  /// they rest on the page rather than float above it.
  static List<BoxShadow> get cardShadow => const [
        BoxShadow(
          color: Color(0x0F25332C),
          blurRadius: 18,
          offset: Offset(0, 6),
        ),
      ];

  static List<BoxShadow> get navShadow => const [
        BoxShadow(
          color: Color(0x1425332C),
          blurRadius: 24,
          offset: Offset(0, -2),
        ),
      ];

  /// Hero gradient for the home banner and course covers with no image.
  static const LinearGradient sageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF6E9A8B), Color(0xFF4E7A6C)],
  );

  static ThemeData light() {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: background,
      colorScheme: base.colorScheme.copyWith(
        brightness: Brightness.light,
        surface: surface,
        primary: sage,
        secondary: sand,
        onPrimary: textOnSage,
        onSurface: textPrimary,
        error: clay,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: textPrimary,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
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
          backgroundColor: sage,
          foregroundColor: textOnSage,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: sage,
          side: const BorderSide(color: sageLight),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusPill),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: sage),
      ),
      // No cardTheme: nothing in the app uses the Material Card widget
      // (every card here is a styled Container), and the CardTheme ->
      // CardThemeData rename across Flutter versions makes declaring one
      // a portability cost for no benefit.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        hintStyle: const TextStyle(color: textSecondary, fontSize: 14),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusRow),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusRow),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusRow),
          borderSide: const BorderSide(color: sage, width: 1.5),
        ),
      ),
      chipTheme: base.chipTheme.copyWith(
        backgroundColor: sageSoft,
        labelStyle: const TextStyle(
          color: textPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        side: BorderSide.none,
        shape: const StadiumBorder(),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: sage,
        linearTrackColor: sageSoft,
      ),
      dividerTheme: const DividerThemeData(color: border, thickness: 1),
      splashFactory: InkRipple.splashFactory,
    );
  }

  /// The app ships light-only now. This stays so `MaterialApp.darkTheme`
  /// and any saved "dark" preference resolve to the same visual language
  /// instead of dropping the user into the retired purple theme.
  static ThemeData dark() => light();
}
