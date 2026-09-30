import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myglo/src/core/services/connectivity_service.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/core/widgets/offline_overlay.dart';

class _FakeNetwork extends NetworkStatusNotifier {
  bool recheckResult = false;
  int rechecks = 0;

  @override
  NetworkStatus build() => NetworkStatus.online;

  void set(NetworkStatus status) => state = status;

  @override
  Future<bool> recheck({bool userInitiated = false}) async {
    rechecks++;
    if (recheckResult) state = NetworkStatus.online;
    return recheckResult;
  }
}

class _FormPage extends StatelessWidget {
  const _FormPage({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          TextField(key: const Key('draft'), controller: controller),
          ElevatedButton(
            onPressed: () => context.push('/second'),
            child: const Text('Next step'),
          ),
          ElevatedButton(
            onPressed: () => showDialog<void>(
              context: context,
              builder: (_) => AlertDialog(
                title: const Text('Confirm booking'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Dialog OK'),
                  ),
                ],
              ),
            ),
            child: const Text('Open dialog'),
          ),
        ],
      ),
    );
  }
}

Future<_FakeNetwork> _pumpApp(WidgetTester tester, TextEditingController draft) async {
  final fake = _FakeNetwork();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => _FormPage(controller: draft)),
      GoRoute(
        path: '/second',
        builder: (_, _) => const Scaffold(body: Text('Second step')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [networkStatusProvider.overrideWith(() => fake)],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
        builder: (context, child) => OfflineOverlay(child: child!),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return fake;
}

void main() {
  testWidgets('shows nothing while online', (tester) async {
    await _pumpApp(tester, TextEditingController());

    expect(find.text(OfflineCopy.title), findsNothing);
  });

  testWidgets('offline shows illustration, copy and Retry; online dismisses it', (tester) async {
    final fake = await _pumpApp(tester, TextEditingController());

    fake.set(NetworkStatus.offline);
    await tester.pumpAndSettle();

    expect(find.text('No Internet Connection'), findsOneWidget);
    expect(find.text(OfflineCopy.description), findsOneWidget);
    expect(find.byType(OfflineIllustration), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);

    fake.set(NetworkStatus.online);
    await tester.pumpAndSettle();

    expect(find.text('No Internet Connection'), findsNothing);
  });

  testWidgets('Retry re-probes and reports when still offline', (tester) async {
    final fake = await _pumpApp(tester, TextEditingController());
    fake.set(NetworkStatus.offline);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(fake.rechecks, 1);
    expect(find.text(OfflineCopy.stillOffline), findsOneWidget);
    expect(find.text('No Internet Connection'), findsOneWidget);

    fake.recheckResult = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('No Internet Connection'), findsNothing);
  });

  testWidgets('keeps route history, open dialog and unsaved input intact', (tester) async {
    final draft = TextEditingController();
    addTearDown(draft.dispose);
    final fake = await _pumpApp(tester, draft);

    await tester.enterText(find.byKey(const Key('draft')), 'half-filled booking note');
    await tester.tap(find.text('Next step'));
    await tester.pumpAndSettle();
    expect(find.text('Second step'), findsOneWidget);

    // Go back so the form is on top, then open a dialog above it.
    final router = GoRouter.of(tester.element(find.text('Second step')));
    router.pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open dialog'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm booking'), findsOneWidget);

    fake.set(NetworkStatus.offline);
    await tester.pumpAndSettle();

    // Sheet is mounted above the dialog, and the dialog is still there.
    expect(find.text('No Internet Connection'), findsOneWidget);
    expect(find.text('Confirm booking'), findsOneWidget);

    // Underlying controls cannot be reached while offline.
    await tester.tap(find.text('Dialog OK'), warnIfMissed: false);
    await tester.pumpAndSettle();
    expect(find.text('Confirm booking'), findsOneWidget);

    fake.set(NetworkStatus.online);
    await tester.pumpAndSettle();

    expect(find.text('No Internet Connection'), findsNothing);
    expect(find.text('Confirm booking'), findsOneWidget);
    expect(draft.text, 'half-filled booking note');
  });

  testWidgets('system back is swallowed while offline and works again online', (tester) async {
    final fake = await _pumpApp(tester, TextEditingController());
    await tester.tap(find.text('Next step'));
    await tester.pumpAndSettle();
    expect(find.text('Second step'), findsOneWidget);

    fake.set(NetworkStatus.offline);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Second step'), findsOneWidget, reason: 'route history untouched');

    fake.set(NetworkStatus.online);
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Second step'), findsNothing);
  });
}
