import 'package:flutter/material.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_theme.dart';

class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Image.asset(
          AppAssets.iconLogo3D_2,
          height: 80,
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.star, size: 80, color: AppTheme.peach),
        ),
        const SizedBox(height: 16),
        const Text(
          'Welcome to MyGlo',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppTheme.darkRed,
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Enter your email to log in or create an account.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.black54),
        ),
      ],
    );
  }
}
