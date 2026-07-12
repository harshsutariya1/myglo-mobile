import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../../../core/theme/app_theme.dart';
import '../../../models/user_role.dart';

class ProfilePictureStep extends StatelessWidget {
  final UserRole role;
  final File? profileImage;
  final VoidCallback onPickImage;

  const ProfilePictureStep({
    super.key,
    required this.role,
    required this.profileImage,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    final description = role == UserRole.provider
        ? 'Add your business\' logo so your clients can recognise you'
        : 'Add a profile picture so your providers can recognise you';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Profile picture',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: context.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          description,
          style: TextStyle(
            fontSize: 16,
            color: context.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        const SizedBox(height: 48),
        Center(
          child: GestureDetector(
            onTap: onPickImage,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 70,
                  backgroundColor: context.colorScheme.secondary.withValues(
                    alpha: 0.2,
                  ),
                  backgroundImage: profileImage != null
                      ? FileImage(profileImage!)
                      : null,
                  child: profileImage == null
                      ? Icon(
                          Icons.person_outline,
                          size: 60,
                          color: context.colorScheme.secondary,
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.colorScheme.tertiary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.edit,
                      size: 20,
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
