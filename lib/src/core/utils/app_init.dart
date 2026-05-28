import 'dart:developer' as developer;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

Future<void> initializeApp({required void Function() appRunner}) async {
  SentryWidgetsFlutterBinding.ensureInitialized();

  developer.log('Starting app initialization...', name: 'initializeApp');

  // Load environment variables securely
  developer.log('Loading .env file...', name: 'initializeApp');
  await dotenv.load(fileName: ".env");
  developer.log('.env file loaded successfully.', name: 'initializeApp');

  final sentryDsn = dotenv.env['SENTRY_DSN'];

  Future<void> initRest() async {
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

    appRunner();
  }

  // Map out Sentry securely underneath framework
  if (sentryDsn != null && sentryDsn.isNotEmpty) {
    developer.log('Initializing Sentry...', name: 'initializeApp');
    await SentryFlutter.init((options) {
      options.enableFramesTracking = true;
      options.replay.sessionSampleRate = 1.0;
      options.replay.onErrorSampleRate = 1.0;
      options.dsn = sentryDsn;
      options.tracesSampleRate = 1.0;
    }, appRunner: initRest);
    developer.log('Sentry initialized successfully.', name: 'initializeApp');
  } else {
    developer.log(
      'SENTRY_DSN not found. Running without Sentry.',
      name: 'initializeApp',
    );
    await initRest();
  }
}
