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

  /// Locked / premium invitation. NOT destructive — see [danger].
  static const Color clay = Color(0xFFC97B5A);

  /// Destructive only: delete, revoke, payment failed.
  ///
  /// Split from [clay] deliberately. A premium invitation and a delete
  /// warning wearing the same colour makes every "Get Access Now" read
  /// faintly like a threat.
  static const Color danger = Color(0xFFB23A2E);

  /// Certificate seals only. A deeper [sand] — the pale original doesn't
  /// read as an award against cream.
  static const Color gold = Color(0xFFD6B36B);

  // ── Text ────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF25332C);
  static const Color textSecondary = Color(0xFF7C8A83);
  static const Color textOnSage = Color(0xFFFFFFFF);

  // ── Lines ───────────────────────────────────────────────────────────
  /// textPrimary at 8%.
  static const Color border = Color(0x1425332C);

  /// textPrimary at 14%, for edges that must survive on cream.
  static const Color borderStrong = Color(0x2425332C);

  // ── Shape ───────────────────────────────────────────────────────────
  static const double radiusCard = 20;
  static const double radiusRow = 16;

  /// Inner tiles: lesson leads, avatars, icon chips.
  static const double radiusTile = 12;
  static const double radiusPill = 999;

  // ── Type ────────────────────────────────────────────────────────────
  /// Display serif. Latin only — Devanagari falls back, which is why
  /// display text that may be Hindi uses [text] at w600 instead.
  static const String display = 'Fraunces';

  /// Text family for everything else. Covers Latin AND Devanagari, so
  /// Hinglish sits in one family rather than switching mid-sentence.
  static const String text = 'Mukta';

  /// Greetings, now-playing title, the recipient's name. 27/32 w500.
  static const TextStyle displayLarge = TextStyle(
    fontFamily: display,
    fontSize: 27,
    height: 32 / 27,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.27,
    color: textPrimary,
  );

  /// Screen and cover titles. 22/26 w500.
  static const TextStyle headline = TextStyle(
    fontFamily: display,
    fontSize: 22,
    height: 26 / 22,
    fontWeight: FontWeight.w500,
    color: textPrimary,
  );

  /// Card and course titles. Two-line clamp at the call site.
  static const TextStyle title = TextStyle(
    fontFamily: text,
    fontSize: 16,
    height: 20 / 16,
    fontWeight: FontWeight.w600,
    color: textPrimary,
  );

  static const TextStyle body = TextStyle(
    fontFamily: text,
    fontSize: 15,
    height: 24 / 15,
    fontWeight: FontWeight.w400,
    color: textPrimary,
  );

  /// Section eyebrows. Uppercase at the call site, not here — a style
  /// that transforms its own text hides the real string from search.
  static const TextStyle label = TextStyle(
    fontFamily: text,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.44,
    color: textSecondary,
  );

  /// Meta rows: duration, author, counts.
  static const TextStyle caption = TextStyle(
    fontFamily: text,
    fontSize: 13,
    fontWeight: FontWeight.w500,
    color: textSecondary,
  );

  static const TextStyle button = TextStyle(
    fontFamily: text,
    fontSize: 15.5,
    fontWeight: FontWeight.w600,
  );

  /// Soft lift for cards. Kept low-opacity and wide so cards feel like
  /// they rest on the page rather than float above it.
  /// One soft down-light, never a stack of glows: the design's single
  /// light source is what keeps cards resting on the page instead of
  /// floating above it.
  static List<BoxShadow> get cardShadow => const [
        BoxShadow(
          color: Color(0x0A25332C),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x3825332C),
          blurRadius: 28,
          spreadRadius: -16,
          offset: Offset(0, 14),
        ),
      ];

  /// The same light, closer in — for rows and chips.
  static List<BoxShadow> get rowShadow => const [
        BoxShadow(
          color: Color(0x0D25332C),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x3325332C),
          blurRadius: 14,
          spreadRadius: -10,
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

  /// Maps the design's ramp onto Material's slots so a widget that asks
  /// for `titleMedium` gets the same type as one styled by hand.
  static TextTheme _textTheme(TextTheme base, Color onSurface) {
    // Order matters. apply() sets the family on EVERY slot, so it has to
    // run first — putting it last would overwrite the Fraunces on the
    // display slots below and silently render the whole app in Mukta.
    // The ramp is layered on top, and only it ever names Fraunces.
    return base
        .apply(
          fontFamily: text,
          bodyColor: onSurface,
          displayColor: onSurface,
        )
        .copyWith(
          displayLarge: displayLarge,
          displayMedium: displayLarge,
          headlineLarge: headline,
          headlineMedium: headline,
          headlineSmall: headline,
          titleLarge: title.copyWith(fontSize: 18, height: 22 / 18),
          titleMedium: title,
          titleSmall: title.copyWith(fontSize: 14, height: 18 / 14),
          bodyLarge: body,
          bodyMedium: body.copyWith(fontSize: 14, height: 21 / 14),
          bodySmall: caption,
          labelLarge: button,
          labelMedium: label,
          labelSmall: label.copyWith(fontSize: 11),
        );
  }

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
          fontFamily: display,
          color: textPrimary,
          fontSize: 22,
          height: 26 / 22,
          fontWeight: FontWeight.w500,
        ),
        iconTheme: IconThemeData(color: textPrimary),
      ),
      // The family is applied to the text theme rather than passed as
      // ThemeData.fontFamily — that parameter exists on the constructor,
      // not on copyWith. Applying it here has the same effect: an
      // unstyled Text reads bodyMedium off this theme, so it is never
      // the odd one out.
      textTheme: _textTheme(base.textTheme, textPrimary),
      iconTheme: const IconThemeData(color: textPrimary),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: sage,
          foregroundColor: textOnSage,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
          textStyle: button,
          // Buttons take the row radius, not the pill: the design's one
          // structural motif is the soft-cornered rectangle, and a
          // stadium button next to a 16px card reads as a stray widget.
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusRow),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: sage,
          side: const BorderSide(color: sageLight),
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 22),
          textStyle: button,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusRow),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: sage, textStyle: button),
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
