import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'src/core/routing/app_router.dart';
import 'src/core/theme/app_theme.dart';

Future<void> _initializeApp() async {
  WidgetsFlutterBinding.ensureInitialized();

  developer.log('Starting app initialization...', name: 'initializeApp');

  // Load environment variables securely
  developer.log('Loading .env file...', name: 'initializeApp');
  await dotenv.load(fileName: ".env");
  developer.log('.env file loaded successfully.', name: 'initializeApp');

  final supabaseUrl = dotenv.env['SUPABASE_URL'];
  final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

  // Check key availability before initialization to fail-fast in production
  developer.log('Validating Supabase credentials...', name: 'initializeApp');
  if (supabaseUrl == null || supabaseUrl.isEmpty) {
    developer.log(
      'SUPABASE_URL is missing or empty.',
      level: 1000,
      name: 'initializeApp',
    );
    throw Exception('SUPABASE_URL is missing or empty in .env file');
  }
  if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
    developer.log(
      'SUPABASE_ANON_KEY is missing or empty.',
      level: 1000,
      name: 'initializeApp',
    );
    throw Exception('SUPABASE_ANON_KEY is missing or empty in .env file');
  }
  developer.log('Supabase credentials validated.', name: 'initializeApp');

  developer.log('Initializing Supabase client...', name: 'initializeApp');
  await Supabase.initialize(url: supabaseUrl, anonKey: supabaseAnonKey);
  developer.log('Supabase client initialized.', name: 'initializeApp');
}

void main() async {
  await _initializeApp()
      .then((_) {
        developer.log(
          'App initialization completed successfully.',
          name: 'main',
        );
        developer.log('Running app...', name: 'main');
        runApp(const ProviderScope(child: MyApp()));
      })
      .catchError((error) {
        developer.log(
          'App initialization failed: $error',
          level: 1000,
          name: 'main',
        );
      });
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'MyGlo',
      theme: AppTheme.lightTheme,
      routerConfig: router,
      debugShowCheckedModeBanner: false,
    );
  }
}
