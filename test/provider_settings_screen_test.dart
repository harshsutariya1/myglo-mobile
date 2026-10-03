import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/providers/provider_profiles/controllers/provider_settings_controller.dart';
import 'package:myglo/src/features/providers/provider_profiles/views/screens/settings_screen.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/auth_repository.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

class _FakeSettingsActions implements ProviderSettingsActions {
  final calls = <(ContactField, bool)>[];

  @override
  Future<bool> setContactVisibility(ContactField field, {required bool visible}) async {
    calls.add((field, visible));
    return true;
  }
}

final _user = User(
  id: 'prov-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  email: 'hello@glowstudio.com.au',
  createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
);

const _profile = ProfileModel(
  id: 'prov-1',
  role: UserRole.provider,
  firstName: 'Mia',
  lastName: 'Nguyen',
  providerName: 'Glow Studio',
  addressText: '1 Cavill Ave, Surfers Paradise QLD',
);

Future<(_MockAuthRepository, _FakeSettingsActions)> _pump(WidgetTester tester) async {
  final auth = _MockAuthRepository();
  final actions = _FakeSettingsActions();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileProvider.overrideWith(
          (ref) async => AppUserProfile(rawUser: _user, role: UserRole.provider, profile: _profile),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        providerSettingsActionsProvider.overrideWithValue(actions),
      ],
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        // Keeps the pulsing status dot still so frames settle.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: const SettingsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (auth, actions);
}

void main() {
  testWidgets('shows the identity card with status', (tester) async {
    await _pump(tester);

    expect(find.text('Glow Studio'), findsOneWidget);
    expect(find.text('Mia Nguyen'), findsOneWidget);
    expect(find.text('Unverified'), findsOneWidget);
    expect(find.text('Accepting new clients'), findsOneWidget);
    expect(find.text('Listed publicly'), findsOneWidget);
  });

  testWidgets('groups settings into the expected sections', (tester) async {
    await _pump(tester);
    await tester.scrollUntilVisible(find.text('1 Cavill Ave, Surfers Paradise QLD'), 300);
    expect(find.text('1 Cavill Ave, Surfers Paradise QLD'), findsOneWidget);

    for (final section in [
      'ACCOUNT & PROFILE',
      'BUSINESS DETAILS',
      'AVAILABILITY & BOOKINGS',
      'PAYOUTS & BANKING',
      'NOTIFICATIONS',
      'PRIVACY & SECURITY',
      'SUPPORT & ABOUT',
    ]) {
      await tester.scrollUntilVisible(find.text(section), 300);
      expect(find.text(section), findsOneWidget);
    }
  });

  testWidgets('features that are not live explain themselves', (tester) async {
    await _pump(tester);

    await tester.scrollUntilVisible(find.text('Bank account'), 300);
    await tester.ensureVisible(find.text('Bank account'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bank account'));
    await tester.pumpAndSettle();

    expect(find.text('Payouts is coming soon'), findsOneWidget);
  });

  testWidgets('email visibility toggle saves the new value', (tester) async {
    final (_, actions) = await _pump(tester);

    await tester.scrollUntilVisible(find.text('Show email on profile'), 300);
    await tester.ensureVisible(find.text('Show email on profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show email on profile'));
    await tester.pumpAndSettle();

    expect(actions.calls, [(ContactField.email, true)]);
  });

  testWidgets('phone visibility is disabled without a phone number', (tester) async {
    final (_, actions) = await _pump(tester);

    await tester.scrollUntilVisible(find.text('Show phone on profile'), 300);
    await tester.ensureVisible(find.text('Show phone on profile'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show phone on profile'));
    await tester.pumpAndSettle();

    expect(find.text('Add a phone number in Account details first'), findsOneWidget);
    expect(actions.calls, isEmpty);
  });

  testWidgets('log out asks for confirmation first', (tester) async {
    final (auth, _) = await _pump(tester);

    await tester.scrollUntilVisible(find.widgetWithText(TextButton, 'Log out'), 300);
    await tester.ensureVisible(find.widgetWithText(TextButton, 'Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Log out?'), findsNothing);
    verifyNever(() => auth.signOut());
  });
}
