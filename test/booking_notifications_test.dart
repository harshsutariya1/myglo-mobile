import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myglo/src/core/realtime/postgres_changes.dart';
import 'package:myglo/src/core/routing/app_router.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/customers/bookings/views/cancel_booking_sheet.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:myglo/src/features/shared/bookings/controllers/booking_controllers.dart';
import 'package:myglo/src/features/shared/bookings/models/booking.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_enums.dart';
import 'package:myglo/src/features/shared/notifications/controllers/notifications_controller.dart';
import 'package:myglo/src/features/shared/notifications/models/app_notification.dart';
import 'package:myglo/src/features/shared/notifications/models/notifications_repository.dart';
import 'package:myglo/src/features/shared/notifications/views/in_app_notification_host.dart';
import 'package:myglo/src/features/shared/notifications/views/notifications_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/booking_fixtures.dart';

User _user(String id) => User(
      id: id,
      appMetadata: const {},
      userMetadata: const {},
      aud: 'authenticated',
      createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
    );

AppNotification _notification(
  String id, {
  String? bookingId,
  bool read = false,
  NotificationKind kind = NotificationKind.bookingNew,
  String title = 'New booking: Lash lift',
}) =>
    AppNotification(
      id: id,
      recipientId: 'prov-1',
      actorId: kind == NotificationKind.bookingRequestReminder ? null : 'client-1',
      kind: kind,
      title: title,
      body: 'Michelle Zhang booked Thu 8 Oct, 9:30 am. Payment pending (cash).',
      bookingId: bookingId,
      createdAt: DateTime.now().toUtc().subtract(const Duration(minutes: 5)),
      readAt: read ? DateTime.now().toUtc() : null,
    );

class _FakeNotificationsRepository implements NotificationsRepository {
  _FakeNotificationsRepository(this.items);

  final List<AppNotification> items;
  final changes = StreamController<RealtimeChange>.broadcast();
  final markedRead = <List<String>?>[];

  @override
  Future<List<AppNotification>> fetchLatest(String userId, {int limit = 60}) async => items;

  @override
  Future<void> markRead({List<String>? ids}) async => markedRead.add(ids);

  @override
  Future<void> delete(String id) async {}

  @override
  Stream<RealtimeChange> watch(String userId) => changes.stream;
}

class _FakeActions implements BookingActions {
  final cancelled = <(String?, bool)>[];

  @override
  Future<Booking> cancel(String bookingId, {String? reason, bool acceptLateCancellation = false}) async {
    cancelled.add((reason, acceptLateCancellation));
    return sampleBooking(status: BookingStatus.cancelled, lateCancellation: acceptLateCancellation);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('Notifications screen', () {
    Future<_FakeNotificationsRepository> pumpInbox(WidgetTester tester, List<AppNotification> items) async {
      final repository = _FakeNotificationsRepository(items);
      addTearDown(repository.changes.close);
      final router = GoRouter(
        initialLocation: '/notifications',
        routes: [
          GoRoute(path: '/notifications', builder: (_, _) => const NotificationsScreen()),
          GoRoute(
            path: AppRoute.providerBookingDetail.path,
            name: AppRoute.providerBookingDetail.name,
            builder: (_, state) => Scaffold(body: Text('Appointment ${state.pathParameters['bookingId']}')),
          ),
          GoRoute(
            path: AppRoute.clientBookingDetail.path,
            name: AppRoute.clientBookingDetail.name,
            builder: (_, state) => Scaffold(body: Text('Booking ${state.pathParameters['bookingId']}')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) async => AppUserProfile(
                rawUser: _user('prov-1'),
                role: UserRole.provider,
                profile: const ProfileModel(id: 'prov-1', role: UserRole.provider),
              ),
            ),
            notificationsRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      return repository;
    }

    testWidgets('lists notifications and marks them all read', (tester) async {
      final repository = await pumpInbox(tester, [_notification('n-1'), _notification('n-2', read: true)]);

      expect(find.text('New booking: Lash lift'), findsNWidgets(2));
      await tester.tap(find.text('Mark all read'));
      await tester.pumpAndSettle();

      expect(repository.markedRead, [null]);
      expect(find.text('Mark all read'), findsNothing);
    });

    testWidgets("a booking notification opens the booking as the provider sees it", (tester) async {
      final repository = await pumpInbox(tester, [_notification('n-1', bookingId: 'booking-9')]);

      await tester.tap(find.text('New booking: Lash lift'));
      await tester.pumpAndSettle();

      expect(find.text('Appointment booking-9'), findsOneWidget);
      expect(repository.markedRead, [
        ['n-1'],
      ]);
    });

    testWidgets('a reminder about an unanswered request opens it for the provider', (tester) async {
      await pumpInbox(tester, [
        _notification(
          'n-1',
          bookingId: 'booking-9',
          kind: NotificationKind.bookingRequestReminder,
          title: 'Request waiting for you',
        ),
      ]);

      expect(find.byIcon(NotificationKind.bookingRequestReminder.icon), findsOneWidget);
      await tester.tap(find.text('Request waiting for you'));
      await tester.pumpAndSettle();

      expect(find.text('Appointment booking-9'), findsOneWidget);
    });

    test('request reminders are read from the server with request styling', () {
      final notification = AppNotification.fromJson({
        'id': 'n-1',
        'recipient_id': 'prov-1',
        'kind': 'booking_request_reminder',
        'title': 'Respond before it expires',
        'body': "Michelle Zhang's request still needs an answer.",
        'booking_id': 'booking-9',
        'created_at': '2026-10-07T10:00:00Z',
      });

      expect(notification.kind, NotificationKind.bookingRequestReminder);
      expect(notification.actorId, isNull);
      expect(notification.kind.color(AppTheme.lightTheme.colorScheme), AppTheme.warning);
    });

    testWidgets('shows an empty state when there is nothing yet', (tester) async {
      await pumpInbox(tester, const []);

      expect(find.text("You're all caught up"), findsOneWidget);
    });
  });

  group('In-app banner', () {
    testWidgets('announces a new notification, then hides it', (tester) async {
      final repository = _FakeNotificationsRepository(const []);
      addTearDown(repository.changes.close);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            userProfileProvider.overrideWith(
              (ref) async => AppUserProfile(
                rawUser: _user('prov-1'),
                role: UserRole.provider,
                profile: const ProfileModel(id: 'prov-1', role: UserRole.provider),
              ),
            ),
            notificationsRepositoryProvider.overrideWithValue(repository),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => InAppNotificationHost(child: child!),
            home: const Scaffold(body: Text('Home')),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(tester.element(find.text('Home')));
      container.read(notificationArrivalProvider.notifier).announce(_notification('n-1', bookingId: 'b-1'));
      await tester.pumpAndSettle();
      expect(find.text('New booking: Lash lift'), findsOneWidget);

      await tester.pump(InAppNotificationHost.visibleFor);
      await tester.pumpAndSettle();
      expect(find.text('New booking: Lash lift'), findsNothing);
    });
  });

  group('Client cancellation', () {
    Future<_FakeActions> pumpSheet(WidgetTester tester, Booking booking) async {
      final actions = _FakeActions();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [bookingActionsProvider.overrideWithValue(actions)],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: TextButton(
                    onPressed: () => showCancelBookingSheet(context, booking: booking),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      return actions;
    }

    testWidgets('free cancellation needs no acknowledgement', (tester) async {
      final booking = sampleBooking(startsAt: DateTime.now().toUtc().add(const Duration(days: 3)));
      final actions = await pumpSheet(tester, booking);

      expect(find.text('Free to cancel. Nothing is owed.'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Cancel booking'));
      await tester.pumpAndSettle();
      expect(actions.cancelled, [('', false)]);
    });

    testWidgets('a late cancellation spells out the fee and must be acknowledged', (tester) async {
      final booking = sampleBooking(
        startsAt: DateTime.now().toUtc().add(const Duration(hours: 5)),
        paymentMethod: PaymentMethod.card,
        cancellationFeePercent: 50,
      );
      final actions = await pumpSheet(tester, booking);

      expect(find.text('This is a late cancellation'), findsOneWidget);
      expect(find.textContaining(r'$57.50 (50%)'), findsOneWidget);
      final confirm = find.widgetWithText(FilledButton, 'Cancel booking');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

      await tester.tap(find.text('I understand the fee and want to cancel'));
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(actions.cancelled, [('', true)]);
    });

    testWidgets('a late cash cancellation has no fee but is still acknowledged', (tester) async {
      // Even with a fee percentage on record, cash bookings never carry one.
      final booking = sampleBooking(
        startsAt: DateTime.now().toUtc().add(const Duration(hours: 5)),
        cancellationFeePercent: 50,
      );
      final actions = await pumpSheet(tester, booking);

      expect(find.text('This is a late cancellation'), findsOneWidget);
      expect(find.textContaining("There's no fee on cash bookings."), findsOneWidget);
      expect(find.textContaining(r'$57.50'), findsNothing);
      final confirm = find.widgetWithText(FilledButton, 'Cancel booking');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);

      await tester.tap(find.text('I understand and want to cancel'));
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(actions.cancelled, [('', true)]);
    });

    testWidgets('a request is withdrawn for free', (tester) async {
      final booking = sampleBooking(
        status: BookingStatus.pending,
        startsAt: DateTime.now().toUtc().add(const Duration(hours: 5)),
      );
      await pumpSheet(tester, booking);

      expect(find.text('Withdraw request?'), findsOneWidget);
      expect(find.text('Free to cancel. Nothing is owed.'), findsOneWidget);
    });
  });
}
