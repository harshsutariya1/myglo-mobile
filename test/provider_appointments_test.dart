import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/providers/home/views/provider_booking_detail_screen.dart';
import 'package:myglo/src/features/providers/home/views/provider_home_screen.dart';
import 'package:myglo/src/features/providers/provider_profiles/controllers/provider_services_controller.dart';
import 'package:myglo/src/features/providers/provider_profiles/models/service_model.dart';
import 'package:myglo/src/features/providers/schedule/controllers/provider_schedule_controller.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:myglo/src/features/shared/bookings/controllers/booking_controllers.dart';
import 'package:myglo/src/features/shared/bookings/models/booking.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_enums.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_repository.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_settings.dart';
import 'package:myglo/src/features/shared/bookings/models/working_hours.dart';
import 'package:myglo/src/features/shared/notifications/controllers/notifications_controller.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/booking_fixtures.dart';

final _providerUser = User(
  id: 'prov-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
);

class _EmptyInbox extends NotificationsController {
  @override
  Future<NotificationsState> build() async => NotificationsState.empty;
}

/// Serves fixed bookings per list.
class _FakeList extends BookingListController {
  _FakeList(super.key);

  static Map<BookingListScope, List<Booking>> data = {};

  @override
  Future<BookingPage> build() async => BookingPage(items: data[key.scope] ?? const [], hasMore: false);
}

/// Records lifecycle calls and returns the booking moved to its next state.
class _FakeActions implements BookingActions {
  final calls = <String>[];

  @override
  Future<Booking> accept(String bookingId) async {
    calls.add('accept $bookingId');
    return sampleBooking(id: bookingId);
  }

  @override
  Future<Booking> decline(String bookingId, {String? reason}) async {
    calls.add('decline $bookingId: $reason');
    return sampleBooking(id: bookingId, status: BookingStatus.declined);
  }

  @override
  Future<Booking> cancel(String bookingId, {String? reason, bool acceptLateCancellation = false}) async {
    calls.add('cancel $bookingId: $reason');
    return sampleBooking(id: bookingId, status: BookingStatus.cancelled);
  }

  @override
  Future<Booking> complete(String bookingId, {required bool paymentReceived}) async {
    calls.add('complete $bookingId paid=$paymentReceived');
    return sampleBooking(id: bookingId, status: BookingStatus.completed, paymentStatus: PaymentStatus.paid);
  }

  @override
  Future<Booking> markNoShow(String bookingId) async {
    calls.add('noShow $bookingId');
    return sampleBooking(id: bookingId, status: BookingStatus.noShow);
  }

  @override
  Future<Booking> recordCashPayment(String bookingId) async {
    calls.add('paid $bookingId');
    return sampleBooking(id: bookingId, status: BookingStatus.completed, paymentStatus: PaymentStatus.paid);
  }
}

class _FakeScheduleActions implements ProviderScheduleActions {
  final updates = <Map<String, Object?>>[];

  @override
  Future<ProviderBookingSettings> updateSettings(Map<String, Object?> changes) async {
    updates.add(changes);
    return const ProviderBookingSettings(providerId: 'prov-1');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<Override> _common({
  required _FakeActions actions,
  _FakeScheduleActions? schedule,
  ProviderBookingSettings settings = const ProviderBookingSettings(providerId: 'prov-1'),
  ProfileModel profile = const ProfileModel(id: 'prov-1', role: UserRole.provider, providerName: 'Glow Studio'),
  bool setUp = true,
}) =>
    [
      userProfileProvider.overrideWith(
        (ref) async => AppUserProfile(rawUser: _providerUser, role: UserRole.provider, profile: profile),
      ),
      notificationsProvider.overrideWith(_EmptyInbox.new),
      bookingListProvider.overrideWith2(_FakeList.new),
      bookingActionsProvider.overrideWithValue(actions),
      providerScheduleActionsProvider.overrideWithValue(schedule ?? _FakeScheduleActions()),
      bookingSettingsProvider.overrideWith((ref, id) => Stream.value(settings)),
      workingHoursProvider.overrideWith(
        (ref, id) async => WeeklySchedule([
          if (setUp) const WorkingHoursRange(weekday: 1, opensMinutes: 540, closesMinutes: 1020),
        ]),
      ),
      providerServicesProvider.overrideWith((ref, id) async => setUp ? [_service] : const []),
    ];

final _service = ServiceModel(
  id: 'svc-1',
  providerId: 'prov-1',
  name: 'Lash lift',
  description: '',
  price: 85,
  durationMinutes: 70,
  createdAt: DateTime.utc(2026, 9, 1),
);

Future<void> _pump(WidgetTester tester, Widget home, List<Override> overrides) async {
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: overrides,
      child: MaterialApp(
        theme: AppTheme.lightTheme,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// A booking starting tomorrow (provider time), so day headings are stable.
Booking _tomorrow({BookingStatus status = BookingStatus.confirmed}) {
  final now = DateTime.now().toUtc();
  final start = DateTime.utc(now.year, now.month, now.day, now.hour).add(const Duration(days: 1));
  return sampleBooking(status: status, startsAt: start);
}

/// Scrolls the page until [finder] is fully on screen.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => _FakeList.data = {});

  group('Appointments', () {
    testWidgets('a new provider sees what is left to set up', (tester) async {
      await _pump(tester, const ProviderHomeScreen(), _common(actions: _FakeActions(), setUp: false));

      expect(find.text('Get ready for bookings'), findsOneWidget);
      expect(find.textContaining('0 of 3 done'), findsOneWidget);
      expect(find.text('Add a service'), findsOneWidget);
      expect(find.text('Set your working hours'), findsOneWidget);
      expect(find.text('Add your business location'), findsOneWidget);
    });

    testWidgets('upcoming appointments are grouped by day', (tester) async {
      _FakeList.data = {
        BookingListScope.confirmed: [_tomorrow()],
      };
      await _pump(tester, const ProviderHomeScreen(), _common(actions: _FakeActions()));

      expect(find.text('TOMORROW'), findsOneWidget);
      expect(find.text('Michelle Zhang'), findsOneWidget);
      expect(find.text('Lash lift, Lash tint'), findsOneWidget);
    });

    testWidgets('requests show a badge and can be accepted in place', (tester) async {
      final actions = _FakeActions();
      final request = _tomorrow(status: BookingStatus.pending);
      _FakeList.data = {
        BookingListScope.requests: [request],
      };
      await _pump(tester, const ProviderHomeScreen(), _common(actions: actions));

      await tester.tap(find.text('Requests'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Respond before'), findsOneWidget);

      await _scrollTo(tester, find.widgetWithText(FilledButton, 'Accept'));
      await tester.tap(find.widgetWithText(FilledButton, 'Accept'));
      await tester.pump();
      expect(actions.calls, ['accept ${request.id}']);
      expect(find.text('Booking confirmed. Michelle Zhang has been notified.'), findsOneWidget);
    });

    testWidgets('paused bookings can be resumed from the banner', (tester) async {
      final schedule = _FakeScheduleActions();
      await _pump(
        tester,
        const ProviderHomeScreen(),
        _common(
          actions: _FakeActions(),
          schedule: schedule,
          settings: const ProviderBookingSettings(providerId: 'prov-1', acceptsBookings: false),
        ),
      );

      expect(find.text('New bookings are paused'), findsOneWidget);
      await tester.tap(find.text('Resume'));
      await tester.pump();
      expect(schedule.updates, [
        {'accepts_bookings': true},
      ]);
    });
  });

  group('Booking detail', () {
    Future<_FakeActions> pumpDetail(WidgetTester tester, Booking booking) async {
      final actions = _FakeActions();
      await _pump(
        tester,
        ProviderBookingDetailScreen(bookingId: booking.id),
        [
          ..._common(actions: actions),
          bookingDetailsProvider(booking.id).overrideWith((ref) async => booking),
        ],
      );
      return actions;
    }

    testWidgets('shows the client, their phone and what the provider earns', (tester) async {
      await pumpDetail(tester, _tomorrow());

      expect(find.text('Michelle Zhang'), findsWidgets);
      await _scrollTo(tester, find.text('0412 345 678'));
      await _scrollTo(tester, find.text('You earn'));
      expect(find.text('Myglo fee'), findsOneWidget);
      // Myglo takes no commission on cash bookings.
      expect(find.text('None on cash'), findsOneWidget);
      expect(find.text('Client pays'), findsOneWidget);
    });

    testWidgets('a request can be declined with a message', (tester) async {
      final booking = _tomorrow(status: BookingStatus.pending);
      final actions = await pumpDetail(tester, booking);

      await _scrollTo(tester, find.widgetWithText(OutlinedButton, 'Decline'));
      await tester.tap(find.widgetWithText(OutlinedButton, 'Decline'));
      await tester.pumpAndSettle();
      expect(find.text('Decline request?'), findsOneWidget);

      await tester.enterText(find.byType(TextField), 'Fully booked that day');
      await tester.tap(find.widgetWithText(FilledButton, 'Decline request'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['decline ${booking.id}: Fully booked that day']);
    });

    testWidgets('cancelling needs a reason for the client', (tester) async {
      final booking = _tomorrow();
      final actions = await pumpDetail(tester, booking);

      await _scrollTo(tester, find.text('Cancel appointment'));
      await tester.tap(find.text('Cancel appointment'));
      await tester.pumpAndSettle();

      final confirm = find.widgetWithText(FilledButton, 'Cancel appointment');
      expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
      await tester.enterText(find.byType(TextField), "I'm unwell");
      await tester.pump();
      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(actions.calls, ["cancel ${booking.id}: I'm unwell"]);
    });

    testWidgets('a started appointment can be completed with the cash received', (tester) async {
      final booking = sampleBooking(startsAt: DateTime.now().toUtc().subtract(const Duration(minutes: 30)));
      final actions = await pumpDetail(tester, booking);

      await _scrollTo(tester, find.text('Mark as completed'));
      expect(find.text("Michelle Zhang didn't show up"), findsOneWidget);
      await tester.tap(find.text('Mark as completed'));
      await tester.pumpAndSettle();

      expect(find.text(r"I've received $115 in cash"), findsOneWidget);
      final sheet = find.byType(BottomSheet);
      await tester.tap(find.descendant(of: sheet, matching: find.widgetWithText(FilledButton, 'Mark as completed')));
      await tester.pumpAndSettle();
      expect(actions.calls, ['complete ${booking.id} paid=true']);
    });

    testWidgets('an unpaid completed appointment can record the cash later', (tester) async {
      final booking = sampleBooking(
        status: BookingStatus.completed,
        startsAt: DateTime.now().toUtc().subtract(const Duration(hours: 3)),
      );
      final actions = await pumpDetail(tester, booking);

      await _scrollTo(tester, find.text('Record cash payment'));
      await tester.tap(find.text('Record cash payment'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Record payment'));
      await tester.pumpAndSettle();
      expect(actions.calls, ['paid ${booking.id}']);
    });
  });
}
