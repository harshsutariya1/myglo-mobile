import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'widgets/home_search_bar.dart';
import 'widgets/category_list.dart';
import 'widgets/provider_item.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.white,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              RichText(
                text: const TextSpan(
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.darkRed,
                  ),
                  children: [
                    TextSpan(text: 'Welcome '),
                    TextSpan(
                      text: 'back',
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 24),
                child: Image.asset(
                  'assets/graphics/Underline.png',
                  width: 120,
                  fit: BoxFit.contain,
                ),
              ),
              const HomeSearchBar(),
              const SizedBox(height: 32),
              const CategoryList(),
              const SizedBox(height: 32),
              const Text(
                'Near me',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.darkRed,
                ),
              ),
              const SizedBox(height: 16),
              const ProviderItem(
                initials: 'LL',
                color: AppTheme.primaryPink,
                category: 'LASHES',
                name: 'Lily Lashes',
                location: 'Melbourne CBD • 2km',
              ),
              const SizedBox(height: 16),
              ProviderItem(
                initials: 'KB',
                color: AppTheme.primaryPink.withValues(alpha: 0.8),
                category: 'EYELASHES',
                name: 'Lily Lashes',
                location: 'Melbourne CBD • 2km',
              ),
              const SizedBox(height: 16),
              const ProviderItemWithImage(
                category: 'NAILS',
                name: 'Pure Pamper',
                location: 'Melbourne CBD • 2km',
                status: 'Available today',
                statusColor: Colors.green,
              ),
              // Padding at the bottom for the navigation bar
              const SizedBox(height: 100),
            ],
          ),
        ),
      ),
    );
  }
}
