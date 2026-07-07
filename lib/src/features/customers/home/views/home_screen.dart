import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'widgets/home_search_bar.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 16),
              RichText(
                text: TextSpan(
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: context.colorScheme.onSurface,
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
              HomeSearchBar(),
              SizedBox(height: 32),
              Text(
                'Near me',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: context.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 32),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off_outlined,
                        size: 64,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No service provider found near you',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
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
