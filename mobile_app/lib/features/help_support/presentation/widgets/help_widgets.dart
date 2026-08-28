import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/help_entities.dart';

/// A section heading inside Help & Support.
class HelpSectionLabel extends StatelessWidget {
  const HelpSectionLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 4, 10),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontFamily: AppTheme.text,
          color: AppTheme.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.66,
        ),
      ),
    );
  }
}

/// A tappable row on the glass surface the rest of the app uses.
class HelpRow extends StatelessWidget {
  const HelpRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Color? iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppTheme.radiusRow),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: AppTheme.glassSurface(),
        child: Row(
          children: [
            Icon(icon, size: 20, color: iconColor ?? AppTheme.sageDark),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: AppTheme.text,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.15,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontFamily: AppTheme.text,
                        fontSize: 12.5,
                        height: 1.35,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppTheme.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// A ticket's status, as a small pill.
class TicketStatusChip extends StatelessWidget {
  const TicketStatusChip(this.status, {super.key});
  final TicketStatus status;

  @override
  Widget build(BuildContext context) {
    // "Waiting for you" is the one that should catch the eye: it is the
    // only status where nothing moves until the member does something.
    final (bg, fg) = switch (status) {
      TicketStatus.open => (const Color(0x1A6D28D9), AppTheme.sageDark),
      TicketStatus.inProgress => (const Color(0x1A6D28D9), AppTheme.sageDark),
      TicketStatus.waitingOnUser => (const Color(0x26D97706), Color(0xFF92400E)),
      TicketStatus.resolved => (AppTheme.well, AppTheme.textSecondary),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.label,
        style: TextStyle(
          fontFamily: AppTheme.text,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: fg,
        ),
      ),
    );
  }
}

/// "2 days ago" — enough for a support list, without pulling in intl.
String helpAgo(DateTime when) {
  final diff = DateTime.now().difference(when);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 30) return '${diff.inDays} days ago';
  return '${(diff.inDays / 30).floor()} months ago';
}
