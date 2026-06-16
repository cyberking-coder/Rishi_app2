import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../../../core/utils/responsive.dart';

class SectionError extends StatelessWidget {
  final VoidCallback onRetry;

  const SectionError({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: Responsive.pageHorizontalPadding(context),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Couldn\'t load this section.',
              style: TextStyle(color: AppTheme.textSecondary),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
