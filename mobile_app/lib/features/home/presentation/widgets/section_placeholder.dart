import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';

/// Pulsing grey blocks shown while a section's data is loading, so the
/// page never pops in abruptly.
class SectionPlaceholder extends StatefulWidget {
  final bool square;

  const SectionPlaceholder({super.key, this.square = false});

  @override
  State<SectionPlaceholder> createState() => _SectionPlaceholderState();
}

class _SectionPlaceholderState extends State<SectionPlaceholder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final width = widget.square
        ? Responsive.squareCardWidth(context)
        : Responsive.posterCardWidth(context);
    final height = widget.square
        ? Responsive.squareCardWidth(context)
        : Responsive.posterCardHeight(context);

    return SizedBox(
      height: height + 28,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: Responsive.pageHorizontalPadding(context),
        itemCount: 6,
        itemBuilder: (context, index) {
          return FadeTransition(
            opacity: Tween(begin: 0.35, end: 0.7).animate(_controller),
            child: Container(
              width: width,
              height: height,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        },
      ),
    );
  }
}
