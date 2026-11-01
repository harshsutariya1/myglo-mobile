import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myglo/src/core/config/remote_app_config.dart';
import 'package:myglo/src/core/payments/payment_sheet_gateway.dart';
import 'package:myglo/src/core/platform/calendar_bridge.dart';
import 'package:myglo/src/core/routing/app_router.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/customers/booking/controllers/booking_draft_controller.dart';
import 'package:myglo/src/features/customers/booking/controllers/checkout_controller.dart';
import 'package:myglo/src/features/customers/booking/models/card_checkout_repository.dart';
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
  final requests = <BookingRequest>[];
  Object? failure;

  /// What card bookings read as after paying (Stripe's answer applied).
  BookingStatus paidStatus = BookingStatus.confirmed;

  /// Bookings whose card checkout ran out, so a repeat returns them closed.
  final expired = <String>{};

  @override
  Future<Booking> createBooking(BookingRequest request) async {
    lastRequest = request;
    requests.add(request);
    if (failure != null) throw failure!;
    if (request.paymentMethod.isCash) return sampleBooking(id: request.bookingId, status: BookingStatus.pending);
    return sampleBooking(
      id: request.bookingId,
      status: expired.contains(request.bookingId) ? BookingStatus.checkoutExpired : BookingStatus.awaitingPayment,
      paymentMethod: PaymentMethod.card,
      paymentStatus: PaymentStatus.requiresPayment,
    );
  }

  @override
  Future<Booking?> getBooking(String id) async => sampleBooking(
        id: id,
        status: paidStatus,
        paymentMethod: PaymentMethod.card,
        paymentStatus: paidStatus == BookingStatus.pending ? PaymentStatus.authorized : PaymentStatus.paid,
      );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCardCheckout implements CardCheckoutRepository {
  final started = <String>[];
  final synced = <String>[];
  final abandoned = <String>[];
  bool hold = false;
  Object? failure;

  @override
  Future<CardCheckoutSession> start(String bookingId) async {
    started.add(bookingId);
    if (failure != null) throw failure!;
    return CardCheckoutSession(clientSecret: 'pi_test_secret_$bookingId', isHold: hold);
  }

  @override
  Future<void> sync(String bookingId) async => synced.add(bookingId);

  @override
  Future<void> abandon(String bookingId) async => abandoned.add(bookingId);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePaymentSheet implements PaymentSheetGateway {
  _FakePaymentSheet([this.result = const PaymentSheetResult.completed()]);

  PaymentSheetResult result;
  final requests = <PaymentSheetRequest>[];

  @override
  bool get isConfigured => true;

  @override
  Future<PaymentSheetResult> present(PaymentSheetRequest request) async {
    requests.add(request);
    return result;
  }
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
  bool takesCard = false,
  bool acceptsCash = true,
  _FakeCardCheckout? checkout,
  _FakePaymentSheet? sheet,
  int cardMaxAdvanceDays = 60,
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
          (ref) => Stream.value(ProviderBookingSettings(
            providerId: _providerId,
            requiresApproval: requiresApproval,
            acceptsCash: acceptsCash,
            acceptsCard: true,
            cardReady: takesCard,
          )),
        ),
        bookingRepositoryProvider.overrideWithValue(repository),
        cardCheckoutRepositoryProvider.overrideWithValue(checkout ?? _FakeCardCheckout()),
        paymentSheetGatewayProvider.overrideWithValue(sheet ?? _FakePaymentSheet()),
        remoteAppConfigProvider.overrideWith((ref) async => RemoteAppConfig(cardMaxAdvanceDays: cardMaxAdvanceDays)),
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
    testWidgets('card is unavailable until the provider can take it; Afterpay is coming soon', (tester) async {
      await _pumpPayment(tester, repository: _FakeBookingRepository());

      expect(find.text('Pay in cash'), findsOneWidget);
      expect(find.textContaining("doesn't take payment in the app yet"), findsOneWidget);
      expect(find.text('Unavailable'), findsOneWidget);
      expect(find.text('Coming soon'), findsOneWidget);
      expect(find.text('Afterpay'), findsOneWidget);

      await tester.tap(find.text('Afterpay'));
      await tester.pump();
      expect(find.text('Afterpay is coming soon'), findsOneWidget);

      expect(find.text(r'$115'), findsWidgets);
    });

    testWidgets('a cash booking is always a request, with no fees', (tester) async {
      // The provider confirms instantly, but that only applies to bookings
      // paid in the app.
      await _pumpPayment(tester, repository: _FakeBookingRepository());

      expect(find.widgetWithText(FilledButton, 'Send request'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Confirm booking'), findsNothing);
      await _scrollTo(tester, find.textContaining('Cash bookings have no booking or cancellation fees.'));
      await _scrollTo(tester, find.textContaining('Your booking is confirmed once they accept it.'));
    });

    testWidgets('a provider who approves every booking also receives a request', (tester) async {
      await _pumpPayment(tester, repository: _FakeBookingRepository(), requiresApproval: true);

      expect(find.widgetWithText(FilledButton, 'Send request'), findsOneWidget);
    });

    testWidgets('confirming places a cash booking and opens the confirmation', (tester) async {
      final repository = _FakeBookingRepository();
      final container = await _pumpPayment(tester, repository: repository);
      final attemptId = container.read(bookingDraftProvider(_providerId)).attemptId;

      await tester.tap(find.widgetWithText(FilledButton, 'Send request'));
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

      await tester.tap(find.widgetWithText(FilledButton, 'Send request'));
      await tester.pumpAndSettle();

      expect(find.text('That time is no longer available'), findsOneWidget);
      await tester.tap(find.text('Choose another time'));
      await tester.pumpAndSettle();
      expect(container.read(bookingDraftProvider(_providerId)).slot, isNull);
    });
  });

  group('Paying in the app', () {
    Finder cardTile() => find.textContaining('Card or ');

    testWidgets('an instant booking is charged now', (tester) async {
      await _pumpPayment(tester, repository: _FakeBookingRepository(), takesCard: true);
      await tester.tap(cardTile());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, r'Pay $115'), findsOneWidget);
      expect(find.text('Pay now'), findsOneWidget);
      await _scrollTo(tester, find.text('Secure payment'));
      await _scrollTo(tester, find.textContaining('may be processed on either'));
    });

    testWidgets('a request holds the amount until the provider accepts', (tester) async {
      await _pumpPayment(tester, repository: _FakeBookingRepository(), takesCard: true, requiresApproval: true);
      await tester.tap(cardTile());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, r'Hold $115 & send request'), findsOneWidget);
      expect(find.textContaining('charged only if Glow Studio accepts'), findsOneWidget);
      await _scrollTo(tester, find.text('Nothing is charged until they accept'));
    });

    testWidgets('a card-only provider has card chosen for the client', (tester) async {
      await _pumpPayment(tester, repository: _FakeBookingRepository(), takesCard: true, acceptsCash: false);

      expect(find.widgetWithText(FilledButton, r'Pay $115'), findsOneWidget);
      expect(find.text('Glow Studio only takes payment in the app'), findsOneWidget);
    });

    testWidgets("appointments beyond the card window can't be paid in the app", (tester) async {
      final container = await _pumpPayment(tester, repository: _FakeBookingRepository(), takesCard: true);
      final far = DateTime.now().toUtc().add(const Duration(days: 90));
      container.read(bookingDraftProvider(_providerId).notifier).selectSlot(AvailableSlot.fromJson({
            'starts_at': far.toIso8601String(),
            'local_date': far.toIso8601String().substring(0, 10),
            'local_time': '09:30:00',
          }));
      await tester.pumpAndSettle();

      expect(find.text('Available for appointments up to 60 days ahead'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Send request'), findsOneWidget);
    });

    testWidgets('paying opens the payment sheet, then the confirmation', (tester) async {
      final repository = _FakeBookingRepository();
      final checkout = _FakeCardCheckout();
      final sheet = _FakePaymentSheet();
      final container = await _pumpPayment(tester, repository: repository, takesCard: true, checkout: checkout, sheet: sheet);
      await tester.tap(cardTile());
      await tester.pumpAndSettle();
      final attemptId = container.read(bookingDraftProvider(_providerId)).attemptId;

      await tester.tap(find.widgetWithText(FilledButton, r'Pay $115'));
      await tester.pumpAndSettle();

      expect(repository.lastRequest!.paymentMethod, PaymentMethod.card);
      expect(checkout.started, [attemptId]);
      expect(sheet.requests.single.clientSecret, 'pi_test_secret_$attemptId');
      expect(sheet.requests.single.primaryButtonLabel, r'Pay $115');
      expect(checkout.synced, [attemptId]);
      expect(find.text('Confirmation for $attemptId'), findsOneWidget);
    });

    testWidgets('closing the sheet keeps the same checkout for another try', (tester) async {
      final repository = _FakeBookingRepository();
      final sheet = _FakePaymentSheet(const PaymentSheetResult.canceled());
      await _pumpPayment(tester, repository: repository, takesCard: true, sheet: sheet);
      await tester.tap(cardTile());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, r'Pay $115'));
      await tester.pumpAndSettle();
      expect(find.byType(BookingPaymentScreen), findsOneWidget);

      sheet.result = const PaymentSheetResult.completed();
      await tester.tap(find.widgetWithText(FilledButton, r'Pay $115'));
      await tester.pumpAndSettle();

      expect(sheet.requests, hasLength(2));
      expect(repository.requests.map((r) => r.bookingId).toSet(), hasLength(1));
      expect(find.textContaining('Confirmation for'), findsOneWidget);
    });

    testWidgets('a declined card is explained, with nothing charged', (tester) async {
      final sheet = _FakePaymentSheet(
        const PaymentSheetResult(PaymentSheetOutcome.failed, message: 'Your card was declined.', code: 'card_declined'),
      );
      await _pumpPayment(tester, repository: _FakeBookingRepository(), takesCard: true, sheet: sheet);
      await tester.tap(cardTile());
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, r'Pay $115'));
      await tester.pumpAndSettle();

      await _scrollTo(tester, find.text("Your payment didn't go through"));
      expect(find.textContaining("Your card was declined. You haven't been charged."), findsOneWidget);
    });

    testWidgets('leaving with an unpaid checkout gives it up', (tester) async {
      final checkout = _FakeCardCheckout();
      final container = await _pumpPayment(
        tester,
        repository: _FakeBookingRepository(),
        takesCard: true,
        checkout: checkout,
        sheet: _FakePaymentSheet(const PaymentSheetResult.canceled()),
      );
      await tester.tap(cardTile());
      await tester.pumpAndSettle();
      final attemptId = container.read(bookingDraftProvider(_providerId)).attemptId;
      await tester.tap(find.widgetWithText(FilledButton, r'Pay $115'));
      await tester.pumpAndSettle();

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(checkout.abandoned, [attemptId]);
    });

    testWidgets('a checkout that ran out starts a fresh attempt with the same choices', (tester) async {
      final repository = _FakeBookingRepository();
      final container = await _pumpPayment(tester, repository: repository, takesCard: true);
      await tester.tap(cardTile());
      await tester.pumpAndSettle();
      final firstAttempt = container.read(bookingDraftProvider(_providerId)).attemptId;
      repository.expired.add(firstAttempt);

      await tester.tap(find.widgetWithText(FilledButton, r'Pay $115'));
      await tester.pumpAndSettle();

      expect(repository.requests.map((r) => r.bookingId), [firstAttempt, isNot(firstAttempt)]);
      expect(repository.requests.last.startsAt, repository.requests.first.startsAt);
      expect(find.textContaining('Confirmation for'), findsOneWidget);
      expect(container.read(checkoutControllerProvider(_providerId)).busy, isFalse);
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
