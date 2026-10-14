import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../firebase_options.dart';
import '../config/app_config.dart';
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
    _bindSentryUser(Supabase.instance.client);

    final preferences = await SharedPreferences.getInstance();

    initWatch.stop();
    AppLogger.i('🎉 App initialization complete in ${initWatch.elapsedMilliseconds}ms', tag: 'Init');

    appRunner(preferences);
  }

  if (sentryDsn != null && sentryDsn.isNotEmpty) {
    AppLogger.d('Initializing Sentry error monitoring...', tag: 'Init');
    await SentryFlutter.init((options) {
      options.dsn = sentryDsn;
      options.environment = _sentryEnvironment();
      // Users are identified by their opaque Supabase id only (see
      // _bindSentryUser); no IP addresses, emails or request bodies.
      options.sendDefaultPii = false;
      options.enableFramesTracking = true;
      // Debug runs keep everything; release builds sample to protect quota.
      options.tracesSampleRate = kReleaseMode ? AppConfig.sentryTracesSampleRate : 1.0;
      options.replay.sessionSampleRate = kReleaseMode ? AppConfig.sentryReplaySessionSampleRate : 0.0;
      options.replay.onErrorSampleRate = AppConfig.sentryReplayOnErrorSampleRate;
      options.privacy.maskAllText = true;
      options.privacy.maskAllImages = true;
    }, appRunner: initRest);
    AppLogger.i('✅ Sentry initialized successfully', tag: 'Init');
  } else {
    AppLogger.w('SENTRY_DSN not found. Running without Sentry.', tag: 'Init');
    await initRest();
  }
}

/// `SENTRY_ENVIRONMENT` from .env (e.g. `staging`), otherwise derived from the
/// build mode so debug runs never mix with production issues.
String _sentryEnvironment() {
  final configured = dotenv.env['SENTRY_ENVIRONMENT']?.trim();
  if (configured != null && configured.isNotEmpty) return configured;
  if (kReleaseMode) return 'production';
  if (kProfileMode) return 'profile';
  return 'development';
}

/// Keeps the Sentry user in step with the signed-in Supabase user, by id only.
void _bindSentryUser(SupabaseClient client) {
  void apply(User? user) {
    Sentry.configureScope((scope) => scope.setUser(user == null ? null : SentryUser(id: user.id)));
  }

  apply(client.auth.currentUser);
  client.auth.onAuthStateChange.listen(
    (data) => apply(data.session?.user),
    onError: (Object e, StackTrace st) =>
        AppLogger.w('Auth state stream error while tagging Sentry user', tag: 'Init', error: e, stackTrace: st),
  );
}
