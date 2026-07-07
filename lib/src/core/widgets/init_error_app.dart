import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class InitErrorApp extends StatelessWidget {
  final Object error;

  const InitErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MyGlo - Initialization Error',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: context.colorScheme.surface,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  color: context.colorScheme.onSurface,
                  size: 80,
                ),
                SizedBox(height: 24),
                Text(
                  'App Initialization Failed',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: context.colorScheme.onSurface,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                const Text(
                  'A critical error occurred while starting MyGlo. Please check your internet connection and try restarting the app. If the issue persists, contact support.',
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
