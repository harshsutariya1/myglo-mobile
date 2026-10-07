import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/routing/app_router.dart';
import 'package:myglo/src/core/services/app_preferences.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/auth_repository.dart';
import 'package:myglo/src/features/shared/authentication/views/screens/email_auth_screen.dart';
import 'package:myglo/src/features/shared/authentication/views/screens/intro_screen.dart';
import 'package:myglo/src/features/shared/authentication/views/screens/role_selection_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _session = Session(
  accessToken: 'token',
  tokenType: 'bearer',
  user: User(
    id: 'user-1',
    appMetadata: const {},
    userMetadata: const {},
    aud: 'authenticated',
    email: 'mia@example.com',
    createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
  ),
);

final _signedOut = AuthState(AuthChangeEvent.signedOut, null);

Future<SharedPreferences> _preferences({bool introSeen = false}) async {
  SharedPreferences.setMockInitialValues({if (introSeen) IntroSeenController.storageKey: true});
  return SharedPreferences.getInstance();
}

/// Runs the real router with a controllable auth stream. Signed-in users
/// have no profile yet, so they land on role selection.
Future<StreamController<AuthState>> _pumpApp(WidgetTester tester, SharedPreferences preferences) async {
  final auth = StreamController<AuthState>();
  addTearDown(auth.close);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        authStateProvider.overrideWith((ref) => auth.stream),
        userProfileProvider.overrideWith((ref) async => null),
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: AppTheme.lightTheme,
          routerConfig: ref.watch(routerProvider),
        ),
      ),
    ),
  );
  return auth;
}

Future<void> _emit(WidgetTester tester, StreamController<AuthState> auth, AuthState state) async {
  auth.add(state);
  await tester.pumpAndSettle();
}

void main() {
  group('IntroSeenController', () {
    test('starts unseen and remembers once marked', () async {
      final preferences = await _preferences();
      final container = ProviderContainer.test(overrides: [sharedPreferencesProvider.overrideWithValue(preferences)]);

      expect(container.read(introSeenProvider), isFalse);
      await container.read(introSeenProvider.notifier).markSeen();
      expect(container.read(introSeenProvider), isTrue);
      expect(preferences.getBool(IntroSeenController.storageKey), isTrue);

      // A fresh start (new container) reads it back.
      final restarted = ProviderContainer.test(overrides: [sharedPreferencesProvider.overrideWithValue(preferences)]);
      expect(restarted.read(introSeenProvider), isTrue);
    });
  });

  group('Intro slides', () {
    testWidgets('are shown to a signed-out user on first launch', (tester) async {
      final auth = await _pumpApp(tester, await _preferences());
      await _emit(tester, auth, _signedOut);

      expect(find.byType(IntroScreen), findsOneWidget);
    });

    testWidgets('reaching the last slide marks them seen, and Get started replaces them with sign-in',
        (tester) async {
      final preferences = await _preferences();
      final auth = await _pumpApp(tester, preferences);
      await _emit(tester, auth, _signedOut);

      await tester.tap(find.text('Skip'));
      await tester.pumpAndSettle();
      expect(preferences.getBool(IntroSeenController.storageKey), isTrue);

      await tester.tap(find.text('Get started'));
      await tester.pumpAndSettle();
      expect(find.byType(EmailAuthScreen), findsOneWidget);
      expect(find.byType(IntroScreen), findsNothing);
      // Nothing to go back to.
      expect(find.byIcon(Icons.arrow_back), findsNothing);
    });

    testWidgets('are skipped once seen: signed-out users go straight to sign-in', (tester) async {
      final auth = await _pumpApp(tester, await _preferences(introSeen: true));
      await _emit(tester, auth, _signedOut);

      expect(find.byType(EmailAuthScreen), findsOneWidget);
      expect(find.byType(IntroScreen), findsNothing);
    });

    testWidgets('logging out leads to sign-in, not the slides, even for older installs without the flag',
        (tester) async {
      final preferences = await _preferences();
      final auth = await _pumpApp(tester, preferences);

      await _emit(tester, auth, AuthState(AuthChangeEvent.signedIn, _session));
      expect(find.byType(RoleSelectionScreen), findsOneWidget);
      expect(preferences.getBool(IntroSeenController.storageKey), isTrue);

      await _emit(tester, auth, _signedOut);
      expect(find.byType(EmailAuthScreen), findsOneWidget);
      expect(find.byType(IntroScreen), findsNothing);
    });
  });
}
