import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/category_summary.dart';

class CategoryChip extends StatelessWidget {
  final CategorySummary category;
  final VoidCallback onTap;

  const CategoryChip({super.key, required this.category, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.35)),
        ),
        child: Text(
          category.name,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            color: AppTheme.accentBright,
          ),
        ),
      ),
    );
  }
}
