import 'package:flutter/material.dart';

/// Breakpoints tuned for phone portrait/landscape and tablet, since the
/// app has no desktop target.
class Responsive {
  Responsive._();

  static bool isTablet(BuildContext context) =>
      MediaQuery.sizeOf(context).shortestSide >= 600;

  /// Poster card width for video/audio carousels: a bit under 1/3 of the
  /// screen on phones (so the next card peeks in) and ~1/5 on tablets.
  static double posterCardWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return isTablet(context) ? width / 5.2 : width / 2.8;
  }

  static double posterCardHeight(BuildContext context) =>
      posterCardWidth(context) * 1.5;

  static double squareCardWidth(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    return isTablet(context) ? width / 6 : width / 3.2;
  }

  static EdgeInsets pageHorizontalPadding(BuildContext context) =>
      EdgeInsets.symmetric(horizontal: isTablet(context) ? 32 : 16);
}
