import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/core/widgets/skeleton/skeletons.dart';
import 'package:myglo/src/features/customers/home/controllers/home_controller.dart';
import 'package:myglo/src/features/customers/home/views/home_screen.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:myglo/src/features/shared/notifications/controllers/notifications_controller.dart';
import 'package:myglo/src/features/shared/notifications/models/app_notification.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final _user = User(
  id: 'client-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
);

/// An inbox with fixed contents and no network.
class _FakeInbox extends NotificationsController {
  _FakeInbox(this.items);

  final List<AppNotification> items;

  @override
  Future<NotificationsState> build() async => NotificationsState(items);
}

AppNotification _notification(String id, {bool read = false}) => AppNotification(
      id: id,
      recipientId: 'client-1',
      kind: NotificationKind.bookingConfirmed,
      title: 'Booking confirmed',
      body: 'See you soon',
      createdAt: DateTime.utc(2026, 10, 5),
      readAt: read ? DateTime.utc(2026, 10, 5, 1) : null,
    );

Future<String> _greetingFor(
  WidgetTester tester,
  String? firstName, {
  List<AppNotification> inbox = const [],
}) async {
  final profile = ProfileModel(id: 'client-1', role: UserRole.customer, firstName: firstName);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        userProfileProvider.overrideWith(
          (ref) async => AppUserProfile(rawUser: _user, role: UserRole.customer, profile: profile),
        ),
        allProvidersProvider.overrideWith((ref) => Completer<List<HomeProvider>>().future),
        notificationsProvider.overrideWith(() => _FakeInbox(inbox)),
      ],
      child: MaterialApp(theme: AppTheme.lightTheme, home: const HomeScreen()),
    ),
  );
  await tester.pump();
  final rich = tester.widgetList<RichText>(find.byType(RichText)).firstWhere(
    (r) => r.text.toPlainText().startsWith('Welcome'),
  );
  return rich.text.toPlainText();
}

void main() {
  testWidgets('greets the client by first name only', (tester) async {
    expect(await _greetingFor(tester, 'Mary Jane'), 'Welcome, Mary');
  });

  testWidgets('falls back to a bare "Welcome" for a blank name', (tester) async {
    expect(await _greetingFor(tester, '   '), 'Welcome');
    expect(await _greetingFor(tester, null), 'Welcome');
  });

  testWidgets('the bell shows how many notifications are unread', (tester) async {
    await _greetingFor(
      tester,
      'Priya',
      inbox: [_notification('a'), _notification('b'), _notification('c', read: true)],
    );
    await tester.pump();

    expect(find.byTooltip('Notifications, 2 unread'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('the bell has no badge when everything is read', (tester) async {
    await _greetingFor(tester, 'Priya', inbox: [_notification('a', read: true)]);
    await tester.pump();

    expect(find.byTooltip('Notifications'), findsOneWidget);
  });

  testWidgets('shows provider skeletons instead of a spinner while loading', (tester) async {
    await _greetingFor(tester, 'Priya');
    expect(find.byType(ProviderItemSkeleton), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
