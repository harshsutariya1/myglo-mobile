import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../authentication/application/user_profile_provider.dart';

class ProfileHeader extends StatelessWidget {
  final AppUserProfile appUser;

  const ProfileHeader({super.key, required this.appUser});

  @override
  Widget build(BuildContext context) {
    final displayName = appUser.displayName;
    final subtitle = appUser.displaySubtitle;
    final profilePicUrl = appUser.allUser.profilePic;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CircleAvatar(
          radius: 50,
          backgroundColor: AppTheme.peach,
          backgroundImage: profilePicUrl != null
              ? NetworkImage(profilePicUrl)
              : null,
          child: profilePicUrl == null
              ? const Icon(Icons.person, size: 50, color: AppTheme.white)
              : null,
        ),
        const SizedBox(height: 16),
        Text(
          displayName,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkRed,
          ),
        ),
        if (subtitle != null && subtitle.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 16, color: Colors.black54),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          appUser.rawUser.email ?? '',
          style: const TextStyle(fontSize: 16, color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.burntOrange.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            appUser.role.name.toUpperCase(),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.burntOrange,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}
