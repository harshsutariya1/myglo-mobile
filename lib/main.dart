import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'src/core/routing/app_router.dart';
import 'src/core/services/app_preferences.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/utils/app_init.dart';
import 'src/core/utils/app_logger.dart';
import 'src/core/utils/app_provider_observer.dart';
import 'src/core/widgets/init_error_app.dart';
import 'src/core/widgets/offline_overlay.dart';
import 'src/core/widgets/shorebird_update_listener.dart';
import 'src/features/shared/notifications/push/push_notification_host.dart';
import 'src/features/shared/notifications/views/in_app_notification_host.dart';

void main() async {
  // Global Flutter framework error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    AppLogger.e(
      'Flutter framework error: ${details.exceptionAsString()}',
      tag: 'FlutterError',
      error: details.exception,
      stackTrace: details.stack,
    );
    Sentry.captureException(details.exception, stackTrace: details.stack);
  };

  // Global platform / isolate error handling
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLogger.f(
      'Uncaught platform error',
      tag: 'PlatformDispatcher',
      error: error,
      stackTrace: stack,
    );
    Sentry.captureException(error, stackTrace: stack);
    return true;
  };

  try {
    await initializeApp(
      appRunner: (preferences) => runApp(
        ProviderScope(
          observers: const [AppProviderObserver()],
          overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
          child: const MyApp(),
        ),
      ),
    );
    AppLogger.i('🚀 App started successfully.', tag: 'Main');
  } catch (error, stackTrace) {
    AppLogger.f(
      'Fatal error during app initialization',
      tag: 'Main',
      error: error,
      stackTrace: stackTrace,
    );
    await Sentry.captureException(error, stackTrace: stackTrace);

    // If initialization fails, show an error screen instead of a blank screen
    runApp(InitErrorApp(error: error));
  }
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return ShorebirdUpdateListener(
      child: MaterialApp.router(
        title: 'MyGlo',
        theme: AppTheme.lightTheme,
        routerConfig: router,
        debugShowCheckedModeBanner: false,
        builder: (context, child) => OfflineOverlay(
          child: PushNotificationHost(child: InAppNotificationHost(child: child!)),
        ),
      ),
    );
  }
}
