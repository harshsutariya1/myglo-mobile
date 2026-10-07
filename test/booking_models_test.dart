import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/location/geo_point.dart';
import 'package:myglo/src/core/utils/formatters.dart';
import 'package:myglo/src/features/customers/booking/controllers/booking_draft_controller.dart';
import 'package:myglo/src/features/customers/booking/controllers/service_selection_controller.dart';
import 'package:myglo/src/features/providers/schedule/views/widgets/booking_rules_section.dart';
import 'package:myglo/src/features/shared/bookings/models/available_slot.dart';
import 'package:myglo/src/features/shared/bookings/models/booking.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_enums.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_failure.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_repository.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_settings.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_terms.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_time.dart';
import 'package:myglo/src/features/shared/bookings/models/cancellation_policy.dart';
import 'package:myglo/src/features/shared/bookings/models/client_address.dart';
import 'package:myglo/src/features/shared/bookings/models/working_hours.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/booking_fixtures.dart';

AvailableSlot _slot(String startsAt, String date, String time) =>
    AvailableSlot.fromJson({'starts_at': startsAt, 'local_date': date, 'local_time': time});

WorkingHoursRange _range(int weekday, int opensHour, int closesHour) =>
    WorkingHoursRange(weekday: weekday, opensMinutes: opensHour * 60, closesMinutes: closesHour * 60);

void main() {
  group('Formatters (booking)', () {
    final morning = DateTime.utc(2026, 10, 7, 9, 30);

    test('formats cents as AUD', () {
      expect(Formatters.audCents(11500), r'$115');
      expect(Formatters.audCents(4550), r'$45.50');
      expect(Formatters.audCents(123456), r'$1,234.56');
    });

    test('formats wall-clock times the Australian way', () {
      expect(Formatters.time(morning), '9:30 am');
      expect(Formatters.time(DateTime.utc(2026, 10, 7, 12, 5)), '12:05 pm');
      expect(Formatters.time(DateTime.utc(2026, 10, 7)), '12:00 am');
      expect(Formatters.timeRange(morning, DateTime.utc(2026, 10, 7, 11)), '9:30 am – 11:00 am');
    });

    test('formats dates', () {
      expect(Formatters.dateShort(morning), 'Wed 7 Oct');
      expect(Formatters.dateTimeShort(morning), 'Wed 7 Oct, 9:30 am');
      expect(Formatters.dateLong(morning, currentYear: 2026), 'Wednesday 7 October');
      expect(Formatters.dateLong(morning, currentYear: 2025), 'Wednesday 7 October 2026');
      expect(Formatters.monthYear(morning), 'October 2026');
    });
  });

  group('PostgisPoint', () {
    test('writes EWKT, longitude first', () {
      expect(
        PostgisPoint.toEwkt(const GeoPoint(latitude: -28.0023, longitude: 153.4294)),
        'SRID=4326;POINT(153.4294 -28.0023)',
      );
    });

    test('reads little-endian EWKB with an SRID, as PostgREST returns it', () {
      final point = PostgisPoint.parse('0101000020E6100000E09C11A5BD2D6340E3C798BB96003CC0')!;
      expect(point.latitude, closeTo(-28.0023, 1e-9));
      expect(point.longitude, closeTo(153.4294, 1e-9));
    });

    test('reads big-endian WKB without an SRID', () {
      final point = PostgisPoint.parse('000000000140632dbda5119ce0c03c0096bb98c7e3')!;
      expect(point.latitude, closeTo(-28.0023, 1e-9));
      expect(point.longitude, closeTo(153.4294, 1e-9));
    });

    test('reads GeoJSON', () {
      final point = PostgisPoint.parse({
        'type': 'Point',
        'coordinates': [153.4294, -28.0023],
      });
      expect(point, const GeoPoint(latitude: -28.0023, longitude: 153.4294));
    });

    test('rejects anything that is not a valid point', () {
      expect(PostgisPoint.parse(null), isNull);
      expect(PostgisPoint.parse('not hex'), isNull);
      expect(PostgisPoint.parse('0102000020E6100000'), isNull);
      expect(PostgisPoint.parse({'type': 'LineString', 'coordinates': []}), isNull);
      expect(PostgisPoint.parse({'type': 'Point', 'coordinates': [200, 100]}), isNull);
    });

    test('knows roughly where Australia is', () {
      expect(const GeoPoint(latitude: -28.0023, longitude: 153.4294).isInAustralia, isTrue);
      expect(const GeoPoint(latitude: 51.5, longitude: -0.12).isInAustralia, isFalse);
    });
  });

  group('BookingTime', () {
    test('reads Postgres wall-clock values without shifting them', () {
      final local = BookingTime.parseWallClock('2026-10-08T09:30:00');
      expect((local.year, local.month, local.day, local.hour, local.minute), (2026, 10, 8, 9, 30));
      expect(BookingTime.wallClockFrom('2026-10-08', '09:30:00'), local);
    });

    test('Gold Coast is UTC+10 all year (no daylight saving in Queensland)', () {
      for (final instant in [DateTime.utc(2026, 1, 15, 2), DateTime.utc(2026, 7, 15, 2)]) {
        expect(BookingTime.nowIn('Australia/Brisbane', now: instant).hour, 12);
      }
    });

    test('converts between instants and wall clocks', () {
      final instant = DateTime.utc(2026, 10, 7, 23, 30);
      final local = BookingTime.wallClockOf(instant, 'Australia/Brisbane');
      expect(local, DateTime.utc(2026, 10, 8, 9, 30));
      expect(BookingTime.instantOf(local, 'Australia/Brisbane'), instant);
      expect(BookingTime.todayIn('Australia/Brisbane', now: instant), DateTime.utc(2026, 10, 8));
    });

    test('labels the zone in plain English', () {
      expect(BookingTime.label('Australia/Brisbane'), 'Gold Coast time (AEST)');
      expect(BookingTime.abbreviation('Australia/Sydney', const Duration(hours: 11)), 'AEDT');
      expect(BookingTime.abbreviation('Asia/Kolkata', const Duration(hours: 5, minutes: 30)), 'UTC+05:30');
    });
  });

  group('BookingFailure', () {
    test('maps server error keys and their details', () {
      final tooSoon = BookingFailure.from(
        const PostgrestException(message: 'too_soon', code: 'P0001', details: '{"min_notice_minutes": 120}'),
      );
      expect(tooSoon.code, BookingFailureCode.tooSoon);
      expect(tooSoon.message, contains('2 hr notice'));

      final outside = BookingFailure.from(
        const PostgrestException(
          message: 'outside_service_area',
          code: 'P0001',
          details: '{"distance_km": 23.4, "radius_km": 15}',
        ),
      );
      expect(outside.message, contains('23 km away'));
      expect(outside.message, contains('15 km'));
      expect(outside.isExpected, isTrue);
    });

    test('treats unknown server errors as unexpected', () {
      final failure = BookingFailure.from(const PostgrestException(message: 'boom', code: 'XX000'));
      expect(failure.code, BookingFailureCode.unknown);
      expect(failure.isExpected, isFalse);
    });

    test('recognises connectivity errors', () {
      expect(BookingFailure.from(const SocketException('Failed host lookup')).code, BookingFailureCode.offline);
    });

    test('rethrows expected refusals as failures and everything else unchanged', () {
      expect(
        () => throwBookingError(
          const PostgrestException(message: 'slot_unavailable', code: 'P0001'),
          StackTrace.current,
          tag: 'test',
          action: 'Booking',
        ),
        throwsA(isA<BookingFailure>().having((f) => f.code, 'code', BookingFailureCode.slotUnavailable)),
      );
      expect(
        () => throwBookingError(const SocketException('offline'), StackTrace.current, tag: 'test', action: 'Booking'),
        throwsA(isA<SocketException>()),
      );
    });
  });

  group('ClientAddress', () {
    const address = ClientAddress(
      line1: '12 Smith St',
      unit: 'Unit 4',
      suburb: 'Southport',
      state: AustralianState.qld,
      postcode: '4215',
    );

    test('formats and geocodes like the server', () {
      expect(address.formatted, 'Unit 4, 12 Smith St, Southport QLD 4215');
      expect(address.geocodingQuery, '12 Smith St, Southport QLD 4215, Australia');
      expect(address.toJson(), {
        'line1': '12 Smith St',
        'unit': 'Unit 4',
        'suburb': 'Southport',
        'state': 'QLD',
        'postcode': '4215',
      });
      expect(ClientAddress.fromJson(address.toJson()), address);
    });

    test('validates each field', () {
      expect(address.isComplete, isTrue);
      expect(ClientAddress.validatePostcode('421'), isNotNull);
      expect(ClientAddress.validatePostcode('42150'), isNotNull);
      expect(ClientAddress.validateLine1('1'), isNotNull);
      expect(ClientAddress.validateSuburb(' '), isNotNull);
    });
  });

  group('WeeklySchedule', () {
    test('round-trips ranges, including midnight closing', () {
      final range = WorkingHoursRange.fromJson({'weekday': 5, 'opens_at': '18:00:00', 'closes_at': '24:00:00'});
      expect(range.closesMinutes, 1440);
      expect(range.toJson(), {'weekday': 5, 'opens_at': '18:00', 'closes_at': '24:00'});
      expect(range.label, '6:00 pm – 12:00 am');
    });

    test('rejects overlapping or backwards ranges', () {
      expect(WeeklySchedule([_range(1, 9, 17), _range(1, 12, 18)]).validationError, contains('overlap'));
      expect(WeeklySchedule([_range(2, 17, 9)]).validationError, contains('end after it starts'));
      expect(WeeklySchedule([_range(1, 9, 12), _range(1, 12, 17)]).validationError, isNull);
    });

    test('summarises the week for settings', () {
      expect(WeeklySchedule(const []).summary, isNull);
      expect(
        WeeklySchedule([for (var day = 1; day <= 5; day++) _range(day, 9, 17)]).summary,
        'Mon–Fri · 9:00 am – 5:00 pm',
      );
      expect(WeeklySchedule([for (var day = 1; day <= 7; day++) _range(day, 10, 16)]).summary,
          'Every day · 10:00 am – 4:00 pm');
      expect(WeeklySchedule([_range(1, 9, 17), _range(3, 9, 17), _range(6, 8, 12), _range(7, 8, 12)]).summary,
          'Mon, Wed, Sat, Sun');
    });
  });

  group('SlotCalendar', () {
    final slots = [
      _slot('2026-10-08T03:00:00Z', '2026-10-08', '13:00:00'),
      _slot('2026-10-07T23:30:00Z', '2026-10-08', '09:30:00'),
      _slot('2026-10-09T08:00:00Z', '2026-10-09', '18:00:00'),
    ];
    final calendar = SlotCalendar(slots);

    test('indexes slots by provider-local day, in order', () {
      expect(calendar.days, [DateTime.utc(2026, 10, 8), DateTime.utc(2026, 10, 9)]);
      expect(calendar.on(DateTime.utc(2026, 10, 8)).map((s) => s.local.hour), [9, 13]);
      expect(calendar.firstDayFrom(DateTime.utc(2026, 10, 9)), DateTime.utc(2026, 10, 9));
      expect(calendar.firstDayFrom(DateTime.utc(2026, 10, 10)), isNull);
      expect(calendar.contains(slots.first), isTrue);
    });

    test('groups a day into morning, afternoon and evening', () {
      final grouped = SlotCalendar.byPeriod([...calendar.on(DateTime.utc(2026, 10, 8)), slots.last]);
      expect(grouped.keys, [SlotPeriod.morning, SlotPeriod.afternoon, SlotPeriod.evening]);
    });

    test('knows the offset between instant and wall clock', () {
      expect(slots[1].utcOffset, const Duration(hours: 10));
      expect(slots[1].localEnd(90), DateTime.utc(2026, 10, 8, 11));
    });
  });

  group('BookingDraftController', () {
    test('renews the attempt id on every change, so retries stay idempotent per choice', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final draft = bookingDraftProvider('prov-1');
      final subscription = container.listen(draft, (_, _) {});
      addTearDown(subscription.close);

      final first = container.read(draft).attemptId;
      container.read(draft.notifier).selectSlot(_slot('2026-10-07T23:30:00Z', '2026-10-08', '09:30:00'));
      final second = container.read(draft).attemptId;
      expect(second, isNot(first));

      // Re-selecting the same slot is not a change.
      container.read(draft.notifier).selectSlot(_slot('2026-10-07T23:30:00Z', '2026-10-08', '09:30:00'));
      expect(container.read(draft).attemptId, second);
    });

    test('changing the services clears the chosen time', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final draft = bookingDraftProvider('prov-1');
      final subscription = container.listen(draft, (_, _) {});
      addTearDown(subscription.close);

      container.read(selectedServiceIdsProvider('prov-1').notifier).select('svc-1');
      container.read(draft.notifier).selectSlot(_slot('2026-10-07T23:30:00Z', '2026-10-08', '09:30:00'));
      expect(container.read(draft).slot, isNotNull);

      container.read(selectedServiceIdsProvider('prov-1').notifier).select('svc-2');
      expect(container.read(draft).slot, isNull);
    });
  });

  group('BookingRequest', () {
    test('sends the address only for home visits', () {
      final studio = BookingRequest(
        bookingId: 'b-1',
        providerId: 'prov-1',
        serviceIds: const ['svc-1'],
        startsAt: DateTime.utc(2026, 10, 7, 23, 30),
        locationType: BookingLocationType.studio,
        phone: '0412345678',
        expectedTotalCents: 8500,
        address: const ClientAddress(line1: '12 Smith St', suburb: 'Southport', state: AustralianState.qld, postcode: '4215'),
        point: const GeoPoint(latitude: -27.97, longitude: 153.41),
        notes: '   ',
      ).toRpcParams();

      expect(studio['p_location_type'], 'studio');
      expect(studio['p_address'], isNull);
      expect(studio['p_latitude'], isNull);
      expect(studio['p_client_notes'], isNull);
      expect(studio['p_starts_at'], '2026-10-07T23:30:00.000Z');
      expect(studio['p_payment_method'], 'cash');
    });
  });

  group('Booking', () {
    test('summarises services and money', () {
      final booking = sampleBooking(paymentMethod: PaymentMethod.card, cancellationFeePercent: 50);
      expect(booking.servicesSummary, 'Lash lift, Lash tint');
      expect(booking.lateFeePercent, 50);
      expect(booking.lateFeeCents, 5750);
      expect(booking.timeZoneLabel, 'Gold Coast time (AEST)');
      expect(paymentStatusLabel(PaymentMethod.cash, booking.paymentStatus), 'Pending (Cash)');
    });

    test('a cash booking never carries a late-cancellation or no-show fee', () {
      final booking = sampleBooking(cancellationFeePercent: 50);
      expect(booking.lateFeePercent, 0);
      expect(booking.lateFeeCents, 0);
    });

    test('knows when cancelling is free, late or no longer possible', () {
      final booking = sampleBooking();
      expect(booking.isLateToCancel(DateTime.utc(2026, 10, 6, 23)), isFalse);
      expect(booking.isLateToCancel(DateTime.utc(2026, 10, 7, 0)), isTrue);
      expect(booking.canCancel(DateTime.utc(2026, 10, 7, 23)), isTrue);
      expect(booking.canCancel(DateTime.utc(2026, 10, 7, 23, 30)), isFalse);
      // Requests can always be withdrawn for free.
      expect(sampleBooking(status: BookingStatus.pending).isLateToCancel(DateTime.utc(2026, 10, 7, 23)), isFalse);
    });

    test('reads the booking_details view', () {
      final booking = Booking.fromJson({
        'id': 'b-1',
        'reference': 'MG-ABC123',
        'client_id': 'client-1',
        'provider_id': 'prov-1',
        'status': 'pending',
        'starts_at': '2026-10-07T23:30:00+00:00',
        'ends_at': '2026-10-08T01:00:00+00:00',
        'time_zone': 'Australia/Brisbane',
        'starts_at_local': '2026-10-08T09:30:00',
        'ends_at_local': '2026-10-08T11:00:00',
        'duration_minutes': 90,
        'location_type': 'client',
        'address_text': 'Unit 4, 12 Smith St, Southport QLD 4215',
        'address': {'line1': '12 Smith St', 'unit': 'Unit 4', 'suburb': 'Southport', 'state': 'QLD', 'postcode': '4215'},
        'distance_km': 6.42,
        'provider_name': 'Glow Studio',
        'client_name': 'Michelle Zhang',
        'client_phone': '0412345678',
        'subtotal_cents': 11500,
        'total_cents': 11500,
        'currency': 'AUD',
        'payment_method': 'cash',
        'payment_status': 'pending',
        'requires_approval': true,
        'cancellation_window_hours': 24,
        'cancellation_fee_percent': 0,
        'free_cancellation_until': '2026-10-06T23:30:00+00:00',
        'late_cancellation': false,
        'cancellation_fee_cents': 0,
        'created_at': '2026-10-05T01:00:00+00:00',
        'updated_at': '2026-10-05T01:00:00+00:00',
        'items': [
          {'service_id': 'svc-1', 'name': 'Lash lift', 'category': 'Lashes', 'duration_minutes': 70, 'price_cents': 8500},
        ],
        'platform_fee_cents': null,
      });
      expect(booking.status, BookingStatus.pending);
      expect(booking.isMobile, isTrue);
      expect(Formatters.time(booking.startsAtLocal), '9:30 am');
      expect(booking.address?.suburb, 'Southport');
      expect(booking.platformFeeCents, isNull);
    });
  });

  group('Booking terms', () {
    const instant = ProviderBookingSettings(
      providerId: 'prov-1',
      cancellationWindowHours: 48,
      cancellationFeePercent: 50,
    );

    test('cash is always a request with no fee, whatever the provider settings', () {
      for (final settings in [instant, instant.copyWith(requiresApproval: true)]) {
        final terms = BookingTerms.of(settings, PaymentMethod.cash);
        expect(terms.requiresApproval, isTrue);
        expect(terms.cancellationFeePercent, 0);
        expect(terms.cancellationWindowHours, 48);
      }
    });

    test('bookings paid in the app follow the provider settings', () {
      final terms = BookingTerms.of(instant, PaymentMethod.card);
      expect(terms.requiresApproval, isFalse);
      expect(terms.cancellationFeePercent, 50);
      expect(
        BookingTerms.of(instant.copyWith(requiresApproval: true), PaymentMethod.applePay).requiresApproval,
        isTrue,
      );
    });

    test('only cash can be chosen until in-app payments launch', () {
      expect(
        [
          for (final method in PaymentMethod.values)
            if (method.isAvailable) method,
        ],
        [PaymentMethod.cash],
      );
    });
  });

  group('Policy wording', () {
    test('profile terms never put a fee on cash', () {
      expect(
        CancellationPolicy.profileTerms(windowHours: 24, inAppFeePercent: 50, inAppPaymentsLive: false),
        'No fee on cash bookings; later cancellations are recorded as late.',
      );
      expect(
        CancellationPolicy.profileTerms(windowHours: 0, inAppFeePercent: 0, inAppPaymentsLive: true),
        'Cash bookings never have a cancellation fee.',
      );
      expect(
        CancellationPolicy.profileTerms(windowHours: 24, inAppFeePercent: 50, inAppPaymentsLive: true),
        endsWith('Paid in the app: later cancellations and no-shows are charged 50% of the booking.'),
      );
    });

    test('a booking without a fee says so', () {
      expect(
        CancellationPolicy.forBooking(
          freeUntilLocal: DateTime.utc(2026, 10, 7, 9, 30),
          windowHours: 24,
          feePercent: 0,
          totalCents: 11500,
        ),
        "Free cancellation until Wed 7 Oct, 9:30 am. After that, you can still cancel with no fee, but it's recorded "
        'as a late cancellation.',
      );
    });

    test('cancellation policy', () {
      expect(CancellationPolicy.summary(windowHours: 24, feePercent: 0),
          'Free cancellation up to 24 hours before. Later cancellations are recorded as late.');
      expect(CancellationPolicy.summary(windowHours: 48, feePercent: 50), contains('2 days before'));
      expect(CancellationPolicy.summary(windowHours: 0, feePercent: 0), contains('any time'));
    });

    test('booking rule labels', () {
      expect(BookingRuleLabels.lateFeeSummary(0), 'No fee');
      expect(BookingRuleLabels.lateFeeSummary(50), '50% of the booking · paid in app only');
      expect(BookingRuleLabels.notice(0), 'No minimum');
      expect(BookingRuleLabels.notice(90), '1.5 hours ahead');
      expect(BookingRuleLabels.notice(120), '2 hours ahead');
      expect(BookingRuleLabels.notice(2880), '2 days ahead');
      expect(BookingRuleLabels.bookingWindow(60), '2 months ahead');
      expect(BookingRuleLabels.cancellationWindow(24), 'Free until 1 day before');
      expect(BookingRuleLabels.cancellationWindow(6), 'Free until 6 hours before');
      expect(BookingRuleLabels.cancellationFee(100), 'Full price');
      expect(BookingRuleLabels.slotInterval(60), 'Every hour');
    });
  });
}
