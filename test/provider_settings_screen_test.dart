import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:myglo/src/core/routing/app_router.dart';
import 'package:myglo/src/core/services/app_preferences.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/providers/provider_profiles/controllers/provider_settings_controller.dart';
import 'package:myglo/src/features/providers/provider_profiles/views/screens/settings_screen.dart';
import 'package:myglo/src/features/providers/schedule/controllers/provider_schedule_controller.dart';
import 'package:myglo/src/features/shared/bookings/controllers/booking_controllers.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_settings.dart';
import 'package:myglo/src/features/shared/bookings/models/working_hours.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/auth_repository.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:myglo/src/features/shared/notifications/push/push_messaging.dart';
import 'package:myglo/src/features/shared/notifications/push/push_token_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fake_push_messaging.dart';

class _MockAuthRepository extends Mock implements AuthRepository {}

/// Records booking-rule changes instead of saving them.
class _FakeScheduleActions implements ProviderScheduleActions {
  final updates = <Map<String, Object?>>[];

  @override
  Future<ProviderBookingSettings> updateSettings(Map<String, Object?> changes) async {
    updates.add(changes);
    return _settings;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _settings = ProviderBookingSettings(providerId: 'prov-1', requiresApproval: true, bufferMinutes: 15);

final _hours = WeeklySchedule([
  for (var day = 1; day <= 5; day++) WorkingHoursRange(weekday: day, opensMinutes: 9 * 60, closesMinutes: 17 * 60),
]);

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

/// Records push token registrations instead of calling Supabase.
class _FakePushTokens implements PushTokenRepository {
  final registered = <String>[];

  @override
  Future<void> register(String token, {required String platform}) async => registered.add(token);

  @override
  Future<void> unregister(String token) async => registered.remove(token);
}

/// Screens the settings rows open, stood in by a labelled page.
const _destinations = [
  AppRoute.editProviderProfile,
  AppRoute.coverPhotos,
  AppRoute.businessLocation,
  AppRoute.serviceArea,
  AppRoute.workingHours,
  AppRoute.timeOff,
];

Future<(_MockAuthRepository, _FakeSettingsActions)> _pump(
  WidgetTester tester, {
  _FakeScheduleActions? scheduleActions,
  ProviderBookingSettings settings = _settings,
  ProfileModel profile = _profile,
  FakePushMessaging? push,
  _FakePushTokens? pushTokens,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final auth = _MockAuthRepository();
  final actions = _FakeSettingsActions();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SettingsScreen()),
      for (final route in _destinations)
        GoRoute(
          path: '/test/${route.name}',
          name: route.name,
          builder: (context, state) => Scaffold(body: Text('opened ${route.name}')),
        ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        userProfileProvider.overrideWith(
          (ref) async => AppUserProfile(rawUser: _user, role: UserRole.provider, profile: profile),
        ),
        authRepositoryProvider.overrideWithValue(auth),
        providerSettingsActionsProvider.overrideWithValue(actions),
        providerScheduleActionsProvider.overrideWithValue(scheduleActions ?? _FakeScheduleActions()),
        bookingSettingsProvider.overrideWith((ref, id) => Stream.value(settings)),
        workingHoursProvider.overrideWith((ref, id) async => _hours),
        ownTimeOffProvider.overrideWith((ref) async => const []),
        pushMessagingProvider.overrideWithValue(push ?? FakePushMessaging()),
        pushTokenRepositoryProvider.overrideWithValue(pushTokens ?? _FakePushTokens()),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
        // Keeps the pulsing status dot still so frames settle.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (auth, actions);
}

Future<void> _tapRow(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(find.text(label), 300);
  await tester.ensureVisible(find.text(label));
  await tester.pumpAndSettle();
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
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

  testWidgets('pausing new bookings asks first, then saves', (tester) async {
    final schedule = _FakeScheduleActions();
    await _pump(tester, scheduleActions: schedule);

    await tester.tap(find.text('Accepting new clients'));
    await tester.pumpAndSettle();
    expect(find.text('Pause new bookings?'), findsOneWidget);
    await tester.tap(find.text('Pause'));
    await tester.pumpAndSettle();

    expect(schedule.updates, [
      {'accepts_bookings': false},
    ]);
  });

  testWidgets('shows a paused status while bookings are paused', (tester) async {
    await _pump(tester, settings: _settings.copyWith(acceptsBookings: false));

    expect(find.text('Bookings paused'), findsOneWidget);
    expect(find.text('Listed publicly'), findsNothing);
  });

  testWidgets('booking rules show their live values', (tester) async {
    await _pump(tester);

    await tester.scrollUntilVisible(find.text('Late cancellation fee'), 300);
    expect(find.text('Mon–Fri · 9:00 am – 5:00 pm'), findsOneWidget);
    expect(find.text('None planned'), findsOneWidget);
    expect(find.text('Every booking waits for you to accept'), findsOneWidget);
    expect(find.text('15 min between bookings'), findsOneWidget);
    expect(find.text('2 hours ahead'), findsOneWidget);
    expect(find.text('Free until 1 day before'), findsOneWidget);
    expect(find.text('No fee'), findsOneWidget);
  });

  testWidgets('changing a booking rule saves the picked value', (tester) async {
    final schedule = _FakeScheduleActions();
    await _pump(tester, scheduleActions: schedule);

    await tester.scrollUntilVisible(find.text('Buffer between bookings'), 300);
    await tester.ensureVisible(find.text('Buffer between bookings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Buffer between bookings'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('30 minutes'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('30 minutes'));
    await tester.pumpAndSettle();

    expect(schedule.updates, [
      {'buffer_minutes': 30},
    ]);
  });

  testWidgets('groups settings into the expected sections', (tester) async {
    await _pump(tester);

    for (final section in [
      'BUSINESS PROFILE',
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
    expect(find.text('Add a phone number to your profile first'), findsOneWidget);
    await tester.tap(find.text('Show phone on profile'));
    await tester.pumpAndSettle();

    expect(actions.calls, isEmpty);
    // Tapping it goes where a number can be added.
    expect(find.text('opened editProviderProfile'), findsOneWidget);
  });

  testWidgets('has no separate account details page', (tester) async {
    await _pump(tester);

    await tester.scrollUntilVisible(find.text('Support & about'.toUpperCase()), 300);
    expect(find.text('Account details'), findsNothing);
  });

  testWidgets('public profile opens the profile editor', (tester) async {
    await _pump(tester);

    await _tapRow(tester, 'Public profile');

    expect(find.text('opened editProviderProfile'), findsOneWidget);
  });

  testWidgets('cover photos show how many are set and open the editor', (tester) async {
    await _pump(
      tester,
      profile: _profile.copyWith(coverPhotos: [
        'https://x.supabase.co/storage/v1/object/public/cover-photos/prov-1/a.jpg',
        'https://x.supabase.co/storage/v1/object/public/cover-photos/prov-1/b.jpg',
      ]),
    );

    expect(find.text('2 of 5 photos'), findsOneWidget);
    await _tapRow(tester, 'Cover photos');
    expect(find.text('opened coverPhotos'), findsOneWidget);
  });

  testWidgets('studio location shows the saved address once pinned', (tester) async {
    await _pump(
      tester,
      profile: _profile.copyWith(
        coordinates: const LocationCoordinates(type: 'Point', coordinates: [153.43, -28.0]),
      ),
    );

    expect(find.text('1 Cavill Ave, Surfers Paradise QLD'), findsOneWidget);
    await _tapRow(tester, 'Studio location');
    expect(find.text('opened businessLocation'), findsOneWidget);
  });

  testWidgets('studio location says when it is not set', (tester) async {
    await _pump(tester);

    expect(find.text("Not set. Clients can't find you on the map yet"), findsOneWidget);
  });

  testWidgets('contact visibility stays on while the profile refreshes', (tester) async {
    final (_, actions) = await _pump(tester);

    await _tapRow(tester, 'Show email on profile');

    expect(actions.calls, [(ContactField.email, true)]);
    final toggle = find.descendant(
      of: find.ancestor(of: find.text('Show email on profile'), matching: find.byType(InkWell)).first,
      matching: find.byType(Switch),
    );
    expect(tester.widget<Switch>(toggle).value, isTrue);
  });

  testWidgets('turning push notifications on asks the system and registers this phone', (tester) async {
    final push = FakePushMessaging();
    final tokens = _FakePushTokens();
    await _pump(tester, push: push, pushTokens: tokens);

    await tester.scrollUntilVisible(find.text('Push notifications'), 300);
    expect(find.text('Off. Turn on to hear about bookings straight away'), findsOneWidget);
    await _tapRow(tester, 'Push notifications');

    expect(push.permissionRequests, 1);
    expect(find.text('Booking requests, confirmations, changes and reminders'), findsOneWidget);
    expect(tokens.registered, [push.currentToken]);
  });

  testWidgets('push notifications show as coming soon where unsupported', (tester) async {
    await _pump(tester, push: FakePushMessaging(isSupported: false));

    await _tapRow(tester, 'Push notifications');

    expect(find.text('Push notifications on this device is coming soon'), findsOneWidget);
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
