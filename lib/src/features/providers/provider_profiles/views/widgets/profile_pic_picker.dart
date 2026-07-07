import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../../../core/theme/app_theme.dart';

class ProfilePicPicker extends StatelessWidget {
  final File? newProfilePic;
  final String? existingProfilePicUrl;
  final VoidCallback onPickImage;

  const ProfilePicPicker({
    super.key,
    required this.newProfilePic,
    required this.existingProfilePicUrl,
    required this.onPickImage,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPickImage,
      child: Stack(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[200],
            backgroundImage: newProfilePic != null
                ? FileImage(newProfilePic!) as ImageProvider
                : (existingProfilePicUrl != null &&
                  existingProfilePicUrl!.isNotEmpty
                      ? CachedNetworkImageProvider(existingProfilePicUrl!) as ImageProvider
                      : null),
            child:
                (newProfilePic == null &&
                    (existingProfilePicUrl == null ||
                        existingProfilePicUrl!.isEmpty))
                ? Icon(Icons.person, size: 50, color: Colors.grey)
                : null,
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: context.colorScheme.secondary,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.camera_alt,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
