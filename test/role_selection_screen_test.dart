import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/shared/authentication/controllers/session_actions.dart';
import 'package:myglo/src/features/shared/authentication/views/screens/role_selection_screen.dart';

class _FakeSessionActions implements SessionActions {
  var signOuts = 0;
  Object? signOutError;

  @override
  Future<void> signOut() async {
    signOuts++;
    if (signOutError != null) throw signOutError!;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<_FakeSessionActions> _pump(WidgetTester tester) async {
  final session = _FakeSessionActions();
  final router = GoRouter(
    initialLocation: '/role',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const Scaffold(body: Text('splash'))),
      GoRoute(
        path: '/role',
        builder: (context, state) => const RoleSelectionScreen(email: 'new@example.test', id: 'user-1'),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [sessionActionsProvider.overrideWithValue(session)],
      child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return session;
}

void main() {
  testWidgets('explains that the role is final and deletion is possible', (tester) async {
    await _pump(tester);

    expect(find.text(RoleSelectionCopy.note), findsOneWidget);
    expect(find.text('Log out'), findsOneWidget);
  });

  testWidgets('log out asks first, then signs out', (tester) async {
    final session = await _pump(tester);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    expect(find.text('Log out?'), findsOneWidget);

    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(session.signOuts, 0);

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(session.signOuts, 1);
    expect(find.text('splash'), findsOneWidget);
  });

  testWidgets('a failed log out says so and stays put', (tester) async {
    final session = await _pump(tester);
    session.signOutError = Exception('offline');

    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(find.text("Couldn't log you out. Please try again."), findsOneWidget);
    expect(find.byType(RoleSelectionScreen), findsOneWidget);
  });
}
