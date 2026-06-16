import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';
import '../../domain/entities/user_profile.dart';

/// Avatar + name + email block at the top of the profile screen.
class ProfileHeader extends StatelessWidget {
  final UserProfile profile;

  const ProfileHeader({super.key, required this.profile});

  @override
  Widget build(BuildContext context) {
    final name = profile.displayName?.isNotEmpty == true
        ? profile.displayName!
        : profile.email;
    final initial = name.isEmpty ? '?' : name.substring(0, 1).toUpperCase();

    return Row(
      children: [
        CircleAvatar(
          radius: 32,
          backgroundColor: AppTheme.surfaceElevated,
          backgroundImage:
              profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
          child: profile.avatarUrl == null
              ? Text(
                  initial,
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                )
              : null,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.displayName?.isNotEmpty == true
                    ? profile.displayName!
                    : 'OTT Member',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                profile.email,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
