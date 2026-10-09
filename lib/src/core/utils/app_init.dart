import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../firebase_options.dart';
import '../network/connectivity_aware_client.dart';
import 'app_logger.dart';

/// Initialises services, then calls [appRunner] with the device preferences
/// (loaded up front so the router can read them synchronously).
Future<void> initializeApp({required void Function(SharedPreferences preferences) appRunner}) async {
  final initWatch = Stopwatch()..start();
  SentryWidgetsFlutterBinding.ensureInitialized();

  AppLogger.i('🚀 Starting application initialization...', tag: 'Init');

  // Load environment variables securely
  AppLogger.d('Loading environment variables from .env...', tag: 'Init');
  await dotenv.load(fileName: ".env");
  AppLogger.i('✅ .env file loaded successfully', tag: 'Init');

  final sentryDsn = dotenv.env['SENTRY_DSN'];

  Future<void> initRest() async {
    AppLogger.d('Initializing Firebase...', tag: 'Init');
    final firebaseWatch = Stopwatch()..start();
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    firebaseWatch.stop();
    AppLogger.i('✅ Firebase initialized in ${firebaseWatch.elapsedMilliseconds}ms', tag: 'Init');

    final supabaseUrl = dotenv.env['SUPABASE_URL'];
    final supabaseAnonKey = dotenv.env['SUPABASE_ANON_KEY'];

    // Check key availability before initialization to fail-fast in production
    AppLogger.d('Validating Supabase credentials...', tag: 'Init');
    if (supabaseUrl == null || supabaseUrl.isEmpty) {
      AppLogger.e('SUPABASE_URL is missing or empty in .env file', tag: 'Init');
      throw Exception('SUPABASE_URL is missing or empty in .env file');
    }
    if (supabaseAnonKey == null || supabaseAnonKey.isEmpty) {
      AppLogger.e('SUPABASE_ANON_KEY is missing or empty in .env file', tag: 'Init');
      throw Exception('SUPABASE_ANON_KEY is missing or empty in .env file');
    }

    AppLogger.d('Initializing Supabase client ($supabaseUrl)...', tag: 'Init');
    final supabaseWatch = Stopwatch()..start();
    await Supabase.initialize(
      url: supabaseUrl,
      anonKey: supabaseAnonKey,
      httpClient: ConnectivityAwareHttpClient(),
    );
    supabaseWatch.stop();
    AppLogger.i('✅ Supabase initialized in ${supabaseWatch.elapsedMilliseconds}ms', tag: 'Init');

    final preferences = await SharedPreferences.getInstance();

    initWatch.stop();
    AppLogger.i('🎉 App initialization complete in ${initWatch.elapsedMilliseconds}ms', tag: 'Init');

    appRunner(preferences);
  }

  // Map out Sentry securely underneath framework
  if (sentryDsn != null && sentryDsn.isNotEmpty) {
    AppLogger.d('Initializing Sentry error monitoring...', tag: 'Init');
    await SentryFlutter.init((options) {
      options.enableFramesTracking = true;
      options.replay.sessionSampleRate = 1.0;
      options.replay.onErrorSampleRate = 1.0;
      options.dsn = sentryDsn;
      options.tracesSampleRate = 1.0;
    }, appRunner: initRest);
    AppLogger.i('✅ Sentry initialized successfully', tag: 'Init');
  } else {
    AppLogger.w('SENTRY_DSN not found. Running without Sentry.', tag: 'Init');
    await initRest();
  }
}
