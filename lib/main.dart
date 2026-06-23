import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'src/core/routing/app_router.dart';
import 'src/core/theme/app_theme.dart';
import 'src/core/utils/app_init.dart';
import 'src/core/widgets/init_error_app.dart';
import 'src/core/widgets/shorebird_update_listener.dart';

void main() async {
  try {
    await initializeApp(
      appRunner: () => runApp(const ProviderScope(child: MyApp())),
    );
    developer.log('App initialization completed successfully.', name: 'main');
  } catch (error, stackTrace) {
    developer.log(
      'App initialization failed',
      level: 1000,
      name: 'main',
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
      ),
    );
  }
}
