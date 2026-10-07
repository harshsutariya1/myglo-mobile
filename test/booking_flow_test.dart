import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myglo/src/core/platform/calendar_bridge.dart';
import 'package:myglo/src/core/routing/app_router.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/customers/booking/controllers/booking_draft_controller.dart';
import 'package:myglo/src/features/customers/booking/controllers/service_selection_controller.dart';
import 'package:myglo/src/features/customers/booking/views/booking_confirmed_screen.dart';
import 'package:myglo/src/features/customers/booking/views/booking_payment_screen.dart';
import 'package:myglo/src/features/customers/provider_profile/controllers/public_provider_profile_controller.dart';
import 'package:myglo/src/features/providers/provider_profiles/controllers/provider_services_controller.dart';
import 'package:myglo/src/features/providers/provider_profiles/models/service_model.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:myglo/src/features/shared/bookings/controllers/booking_controllers.dart';
import 'package:myglo/src/features/shared/bookings/models/available_slot.dart';
import 'package:myglo/src/features/shared/bookings/models/booking.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_enums.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_failure.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_repository.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_settings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/booking_fixtures.dart';

const _providerId = 'prov-1';

final _client = User(
  id: 'client-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
);

ServiceModel _service(String id, String name, double price, int minutes) => ServiceModel(
      id: id,
      providerId: _providerId,
      name: name,
      description: '',
      price: price,
      durationMinutes: minutes,
      createdAt: DateTime.utc(2026, 9, 1),
    );

final _slot = AvailableSlot.fromJson({
  'starts_at': '2026-10-07T23:30:00Z',
  'local_date': '2026-10-08',
  'local_time': '09:30:00',
});

class _FakeBookingRepository implements BookingRepository {
  BookingRequest? lastRequest;
  Object? failure;

  @override
  Future<Booking> createBooking(BookingRequest request) async {
    lastRequest = request;
    if (failure != null) throw failure!;
    return sampleBooking(id: request.bookingId);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCalendar implements CalendarBridge {
  final events = <CalendarEvent>[];

  @override
  Future<CalendarAddResult> addEvent(CalendarEvent event) async {
    events.add(event);
    return CalendarAddResult.saved;
  }
}

/// Opens the payment step with two services, a time and the studio chosen.
Future<ProviderContainer> _pumpPayment(
  WidgetTester tester, {
  required _FakeBookingRepository repository,
  bool requiresApproval = false,
}) async {
  final router = GoRouter(
    initialLocation: '/pay',
    routes: [
      GoRoute(path: '/pay', builder: (_, _) => const BookingPaymentScreen(providerId: _providerId)),
      GoRoute(
        path: AppRoute.bookingConfirmed.path,
        name: AppRoute.bookingConfirmed.name,
        builder: (_, state) => Scaffold(body: Text('Confirmation for ${state.pathParameters['bookingId']}')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        userProfileProvider.overrideWith(
          (ref) async => AppUserProfile(
            rawUser: _client,
            role: UserRole.customer,
            profile: const ProfileModel(id: 'client-1', role: UserRole.customer, phoneNumber: '0412345678'),
          ),
        ),
        publicProviderProfileProvider(_providerId).overrideWith(
          (ref) => const ProfileModel(id: _providerId, role: UserRole.provider, providerName: 'Glow Studio'),
        ),
        providerServicesProvider(_providerId).overrideWith(
          (ref) => [_service('svc-1', 'Lash lift', 85, 70), _service('svc-2', 'Lash tint', 30, 20)],
        ),
        bookingSettingsProvider(_providerId).overrideWith(
          (ref) => Stream.value(ProviderBookingSettings(providerId: _providerId, requiresApproval: requiresApproval)),
        ),
        bookingRepositoryProvider.overrideWithValue(repository),
      ],
      child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ),
  );
  await tester.pump();

  final container = ProviderScope.containerOf(tester.element(find.byType(BookingPaymentScreen)));
  container.read(selectedServiceIdsProvider(_providerId).notifier)
    ..select('svc-1')
    ..select('svc-2');
  // What the earlier steps leave in the draft (the review step stores the
  // confirmed phone number).
  container.read(bookingDraftProvider(_providerId).notifier)
    ..selectSlot(_slot)
    ..selectLocation(BookingLocationType.studio)
    ..setPhone('0412345678');
  await tester.pumpAndSettle();
  return container;
}

/// Scrolls the page until [finder] is fully on screen.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('Payment step', () {
    testWidgets('cash is the only live method; other rails are marked coming soon', (tester) async {
      await _pumpPayment(tester, repository: _FakeBookingRepository());

      expect(find.text('Pay in cash'), findsOneWidget);
      expect(find.text('Coming soon'), findsNWidgets(3));
      expect(find.text('Afterpay'), findsOneWidget);

      await tester.tap(find.text('Afterpay'));
      await tester.pump();
      expect(find.text('Afterpay is coming soon'), findsOneWidget);

      expect(find.widgetWithText(FilledButton, 'Confirm booking'), findsOneWidget);
      expect(find.text(r'$115'), findsWidgets);
    });

    testWidgets('a provider who approves requests receives a request', (tester) async {
      await _pumpPayment(tester, repository: _FakeBookingRepository(), requiresApproval: true);

      expect(find.widgetWithText(FilledButton, 'Send request'), findsOneWidget);
    });

    testWidgets('confirming places a cash booking and opens the confirmation', (tester) async {
      final repository = _FakeBookingRepository();
      final container = await _pumpPayment(tester, repository: repository);
      final attemptId = container.read(bookingDraftProvider(_providerId)).attemptId;

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm booking'));
      await tester.pumpAndSettle();

      final request = repository.lastRequest!;
      expect(request.bookingId, attemptId);
      expect(request.paymentMethod, PaymentMethod.cash);
      expect(request.locationType, BookingLocationType.studio);
      expect(request.serviceIds, ['svc-1', 'svc-2']);
      expect(request.expectedTotalCents, 11500);
      expect(request.startsAt, _slot.startsAt);
      expect(request.phone, '0412345678');
      expect(find.text('Confirmation for $attemptId'), findsOneWidget);
    });

    testWidgets('a time taken in the meantime is explained and cleared', (tester) async {
      final repository = _FakeBookingRepository()
        ..failure = const BookingFailure(BookingFailureCode.slotUnavailable);
      final container = await _pumpPayment(tester, repository: repository);

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm booking'));
      await tester.pumpAndSettle();

      expect(find.text('That time is no longer available'), findsOneWidget);
      await tester.tap(find.text('Choose another time'));
      await tester.pumpAndSettle();
      expect(container.read(bookingDraftProvider(_providerId)).slot, isNull);
    });
  });

  group('Confirmation', () {
    Future<_FakeCalendar> pumpConfirmation(WidgetTester tester, Booking booking) async {
      final calendar = _FakeCalendar();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            bookingDetailsProvider(booking.id).overrideWith((ref) async => booking),
            calendarBridgeProvider.overrideWithValue(calendar),
          ],
          child: MaterialApp(
            theme: AppTheme.lightTheme,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: child!,
            ),
            home: BookingConfirmedScreen(bookingId: booking.id, initial: booking),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return calendar;
    }

    testWidgets('shows the reference, summary and payment status', (tester) async {
      await pumpConfirmation(tester, sampleBooking());

      expect(find.text("You're booked!"), findsOneWidget);
      expect(find.text('MG-7K3QX9'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Pending (Cash)'), findsOneWidget);
      await _scrollTo(tester, find.text('Booking fee'));
      expect(find.text('Free'), findsOneWidget);
      await _scrollTo(tester, find.text('View my bookings'));
      expect(find.text('Back to home'), findsOneWidget);
    });

    testWidgets('a request reads as sent, pending approval', (tester) async {
      await pumpConfirmation(tester, sampleBooking(status: BookingStatus.pending));

      expect(find.text('Request sent!'), findsOneWidget);
      expect(find.text('Pending approval'), findsOneWidget);
    });

    testWidgets('Add to calendar sends the appointment to the calendar', (tester) async {
      final booking = sampleBooking();
      final calendar = await pumpConfirmation(tester, booking);

      await _scrollTo(tester, find.text('Add to calendar'));
      await tester.tap(find.text('Add to calendar'));
      await tester.pump();

      final event = calendar.events.single;
      expect(event.title, 'Lash lift, Lash tint · Glow Studio');
      expect(event.start, booking.startsAt);
      expect(event.end, booking.endsAt);
      expect(event.timeZone, 'Australia/Brisbane');
      expect(event.notes, contains(r'Pay $115 in cash'));
      expect(find.text('Added to your calendar'), findsOneWidget);
    });
  });
}
