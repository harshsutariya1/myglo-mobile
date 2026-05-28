import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_assets.dart';
import '../../../../core/theme/app_theme.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.peach.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(32),
                  ),
                  child: Center(
                    // Placeholder for the device mockup image
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Image.asset(
                        AppAssets.iconLogo3D_2,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(
                              Icons.phone_iphone,
                              size: 200,
                              color: AppTheme.white,
                            ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    context.push('/auth');
                  },
                  child: const Text('Get started'),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () {
                  context.go('/main');
                },
                child: const Text(
                  'Continue as guest',
                  style: TextStyle(
                    color: AppTheme.burntOrange,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
