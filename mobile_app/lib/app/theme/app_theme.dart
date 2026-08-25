import 'package:flutter/material.dart';

/// Purple glass: a light theme on a violet palette running light to
/// dark — lavender canvas, mid-violet accent, deep-purple player — with
/// frosted surfaces for cards, bars and the tab bar.
///
/// Replaces the sage-on-cream system. The token NAMES are deliberately
/// unchanged: 32 files read from this class, and renaming `sage` to
/// `violet` would have meant touching every one of them to change what
/// colour comes out of it. The names describe roles here — [sage] is
/// "the primary action colour", whatever hue that currently is — which
/// is what let this palette land in one file.
///
/// Screens should read from here rather than declaring their own
/// constants — the old per-screen colour blocks are what let the app
/// drift into two different visual languages at once.
class AppTheme {
  AppTheme._();

  // ── Core palette ────────────────────────────────────────────────────
  /// Page background. Lavender canvas — the tint is what makes the
  /// frosted white surfaces above it read as glass rather than as
  /// plain cards.
  static const Color background = Color(0xFFF5F2FC);

  /// Cards and sheets that sit on [background].
  static const Color surface = Color(0xFFFFFFFF);

  /// Secondary surface for list rows. The palest violet, so stacked
  /// rows separate from [surface] without borders.
  static const Color surfaceCream = Color(0xFFF5F3FF);

  /// Frosted card fill: white at 60%, over [background]. Pair with a
  /// BackdropFilter where the thing behind it is worth blurring;
  /// on a flat background the translucency alone carries it.
  static const Color glass = Color(0x99FFFFFF);

  /// The deep end of the ramp — the player, and anything that should
  /// read as a surface you are inside rather than on.
  static const Color deep = Color(0xFF2A1650);
  static const Color deepest = Color(0xFF1E1830);

  /// Primary brand + every primary action.
  static const Color sage = Color(0xFF7C3AED);
  static const Color sageDark = Color(0xFF6D28D9);
  static const Color sageLight = Color(0xFFA78BFA);

  /// Tinted fills for pills, badges and icon chips.
  static const Color sageSoft = Color(0xFFEDE9FE);

  /// Secondary accent, used sparingly — highlights, "new" flags.
  static const Color sand = Color(0xFFC4B5FD);
  static const Color sandSoft = Color(0xFFEDE9FE);

  /// Locked / members-only. NOT destructive — see [danger].
  static const Color clay = Color(0xFF6D28D9);

  /// Destructive only: delete, revoke, payment failed.
  ///
  /// Split from [clay] deliberately. A premium invitation and a delete
  /// warning wearing the same colour makes every "Get Access Now" read
  /// faintly like a threat.
  static const Color danger = Color(0xFFB23A2E);

  /// Kept for the certificate seal, which iOS no longer renders and
  /// Android still can. A deeper [sand].
  static const Color gold = Color(0xFF8B5CF6);

  // ── Text ────────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF1E1830);
  static const Color textSecondary = Color(0xFF7D7395);
  static const Color textOnSage = Color(0xFFFFFFFF);

  // ── Lines ───────────────────────────────────────────────────────────
  /// textPrimary at 9%.
  static const Color border = Color(0x171E1830);

  /// textPrimary at 16%, for edges that must survive on a tinted canvas.
  static const Color borderStrong = Color(0x291E1830);

  // ── Shape ───────────────────────────────────────────────────────────
  // Claymorphism reads as a soft solid you could press a thumb into.
  // That needs corners well past the flat-card scale — at 16 a "clay"
  // card just looks like a card with an odd shadow — and it needs the
  // radius to stay proportional as surfaces shrink, so a chip is as
  // rounded relative to its size as a card is.
  static const double radiusCard = 24;
  static const double radiusRow = 16;

  /// Inner tiles: episode leads, avatars, icon chips.
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
  /// Clay lift: a dark shadow low-right and a light one high-left.
  ///
  /// The pair is what makes a surface read as a soft solid rather than a
  /// card floating over a page. Purple glass throws a single soft shadow
  /// a long way down rather than the two-light clay model this replaced —
  /// the surface is meant to read as translucent and hovering, not as a
  /// solid you could press a thumb into.
  static List<BoxShadow> get cardShadow => const [
        BoxShadow(
          color: Color(0x291E1830),
          blurRadius: 60,
          offset: Offset(0, 24),
        ),
        BoxShadow(
          color: Color(0x0F1E1830),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ];

  /// Barely there — for rows, chips and small tiles, where the long
  /// throw of [cardShadow] would muddy a stack.
  static List<BoxShadow> get rowShadow => const [
        BoxShadow(
          color: Color(0x0D1E1830),
          blurRadius: 2,
          offset: Offset(0, 1),
        ),
        BoxShadow(
          color: Color(0x0A1E1830),
          blurRadius: 0,
          spreadRadius: 0.5,
        ),
      ];

  /// The frosted fill: a translucent white that lets the lavender canvas
  /// through, brightest at the top edge where a glass panel catches the
  /// light. Kept subtle — pushed harder it stops reading as glass and
  /// starts reading as a grey card.
  ///
  /// Still called clayFill because 32 files call it. The name is wrong
  /// for what it now draws and renaming it would be a rename commit
  /// across the whole app, which is not what a restyle should cost.
  static LinearGradient clayFill([Color? base]) {
    final c = base ?? glass;
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.alphaBlend(const Color(0x40FFFFFF), c),
        c,
        Color.alphaBlend(const Color(0x0D1E1830), c),
      ],
      stops: const [0, 0.5, 1],
    );
  }

  /// One clay surface. Named claySurface, not clay, because [clay] is
  /// already the colour — brand vocabulary that predates this and is used
  /// across the app, so the newcomer yields.
  ///
  /// Every raised container in the app should use this
  /// rather than assembling a colour, a radius and a shadow by hand —
  /// three surfaces that each got it slightly differently is exactly how
  /// a soft-UI style stops looking deliberate.
  static BoxDecoration claySurface({
    Color? color,
    double? radius,
    bool small = false,
  }) {
    return BoxDecoration(
      gradient: clayFill(color),
      borderRadius: BorderRadius.circular(radius ?? radiusCard),
      boxShadow: small ? rowShadow : cardShadow,
    );
  }

  /// A recessed well: search fields, progress tracks, empty slots. A
  /// flat violet tint rather than a carved one — on glass there is no
  /// depth to carve into.
  static BoxDecoration clayInset({Color? color, double? radius}) {
    final c = color ?? sageSoft;
    return BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.alphaBlend(const Color(0x141E1830), c),
          c,
          Color.alphaBlend(const Color(0x14FFFFFF), c),
        ],
        stops: const [0, 0.5, 1],
      ),
      borderRadius: BorderRadius.circular(radius ?? radiusRow),
    );
  }

  static List<BoxShadow> get navShadow => const [
        BoxShadow(
          color: Color(0x1F1E1830),
          blurRadius: 40,
          offset: Offset(0, -8),
        ),
      ];

  /// Hero gradient for the home banner and covers with no image.
  static const LinearGradient sageGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFF4C1D95)],
  );

  /// The deep end of the ramp, for the player. Dark enough that artwork
  /// and white controls sit on it without a scrim.
  static const LinearGradient deepGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF2A1650), Color(0xFF1E1830)],
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
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          textStyle: button,
          // A clay button has to look like something you could press
          // into. Flutter gives one shadow colour here rather than the
          // dark/light pair, so the dark half carries it and the fill
          // does the rest.
          elevation: 6,
          shadowColor: const Color(0x5544675C),
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
