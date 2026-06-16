import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class ProfileStatTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;

  const ProfileStatTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
            ),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (onTap != null) ...[
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right, size: 18, color: AppTheme.textSecondary),
            ],
          ],
        ),
      ),
    );
  }
}
