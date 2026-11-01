import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/admin/models/admin_payments.dart';
import 'package:myglo/src/features/providers/payments/controllers/payments_controllers.dart';
import 'package:myglo/src/features/providers/payments/models/provider_financials.dart';
import 'package:myglo/src/features/providers/payments/views/financials_screen.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_enums.dart';
import 'package:myglo/src/features/shared/bookings/views/widgets/booking_overview.dart';
import 'package:myglo/src/features/shared/notifications/models/app_notification.dart';

import 'support/booking_fixtures.dart';

Future<void> _pump(WidgetTester tester, Widget child, {List<dynamic> overrides = const []}) async {
  await tester.pumpWidget(ProviderScope(
    overrides: [...overrides],
    retry: (_, _) => null,
    child: MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: child)),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('Provider earnings', () {
    final financials = ProviderFinancials.fromJson({
      'card_earned_cents': 20000,
      'myglo_fee_cents': 1100,
      'cash_collected_cents': 5000,
      'completed_bookings': 3,
      'on_its_way_cents': 9000,
      'held_cents': 4000,
      'settlements': [
        {
          'booking_id': 'b-1',
          'reference': 'MG-1',
          'client_name': 'Michelle Zhang',
          'starts_at': '2026-11-03T00:00:00Z',
          'kept_cents': 10000,
          'platform_fee_cents': 550,
          'transfer_cents': 9450,
          'reversed_cents': 0,
          'status': 'held',
          'hold_reason': 'dispute',
        },
      ],
      'payouts': [
        {'id': 'po_1', 'amount_cents': 12345, 'status': 'in_transit', 'arrival_date': '2026-11-10'},
      ],
    });

    test('totals what the provider earned after fees', () {
      expect(financials.totalEarnedCents, 20000 - 1100 + 5000);
      expect(financials.settlements.single.statusLabel, 'On hold: disputed');
      expect(financials.settlements.single.netCents, 9450);
      expect(financials.payouts.single.statusLabel, 'On its way');
    });

    testWidgets('shows the month, the split, held money and payouts', (tester) async {
      final month = DateTime(2026, 11);
      await tester.pumpWidget(ProviderScope(
        overrides: [providerFinancialsProvider(month).overrideWith((ref) async => financials)],
        retry: (_, _) => null,
        child: MaterialApp(theme: AppTheme.lightTheme, home: FinancialsScreen(now: DateTime(2026, 11, 20))),
      ));
      await tester.pumpAndSettle();

      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text(r'$239'), findsOneWidget);
      expect(find.text(r'−$11'), findsOneWidget);
      expect(find.textContaining(r'including $40 on hold'), findsOneWidget);
      expect(find.text('On hold: disputed · \$5.50 fee'), findsOneWidget);
      await tester.scrollUntilVisible(find.text(r'$123.45'), 200);
      // The current month is the latest one.
      expect(tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.chevron_right_rounded)).onPressed, isNull);
    });
  });

  group('Admin payments', () {
    test('a booking payment knows which actions apply', () {
      final paid = AdminBookingPayment.fromJson({
        'booking': {'id': 'b-1', 'reference': 'MG-1', 'status': 'completed', 'payment_method': 'card', 'refundable_cents': 5000},
        'settlement': {'status': 'transferred'},
        'jobs': [
          {'id': 'j-1', 'kind': 'transfer', 'status': 'failed', 'attempts': 8, 'last_error': 'insufficient funds'},
        ],
      });
      expect(paid.canRefund, isTrue);
      expect(paid.canCancel, isFalse);
      expect(paid.canHold, isFalse);
      expect(paid.canRelease, isFalse);
      expect(paid.jobs.single.label, 'Transfer to provider');

      final held = AdminBookingPayment.fromJson({
        'booking': {'id': 'b-2', 'status': 'confirmed', 'payment_method': 'card', 'refundable_cents': 0},
        'settlement': {'status': 'held', 'hold_reason': 'admin'},
      });
      expect(held.canRefund, isFalse);
      expect(held.canCancel, isTrue);
      expect(held.canHold, isFalse);
      expect(held.canRelease, isTrue);
    });

    test('reads the overview', () {
      final overview = AdminPaymentsOverview.fromJson({
        'paid_7d_cents': 10000,
        'open_disputes': 1,
        'failed_jobs': [
          {'id': 'j-1', 'kind': 'refund_payment', 'status': 'failed'},
        ],
        'disputes': [
          {'id': 'dp_1', 'amount_cents': 5000, 'status': 'needs_response', 'reference': 'MG-1'},
        ],
      });
      expect(overview.openDisputes, 1);
      expect(overview.failedJobs.single.label, 'Refund');
      expect(overview.disputes.single.reference, 'MG-1');
    });
  });

  test('payment notifications route to payments and get a colour', () {
    for (final key in ['payment_refunded', 'payout_paid', 'payout_failed', 'booking_disputed']) {
      expect(NotificationKind.fromKey(key), isNot(NotificationKind.unknown), reason: key);
    }
    expect(NotificationKind.payoutPaid.isAboutPayments, isTrue);
    expect(NotificationKind.payoutFailed.isAboutPayments, isTrue);
    expect(NotificationKind.paymentRefunded.isAboutPayments, isFalse);
  });

  group('Booking price card', () {
    testWidgets('a client sees a refund on its way', (tester) async {
      final booking = sampleBooking(
        status: BookingStatus.cancelled,
        paymentMethod: PaymentMethod.card,
        paymentStatus: PaymentStatus.paid,
      ).copyWith(refundPendingCents: 11500);
      await _pump(tester, BookingPriceCard(booking: booking));
      expect(find.textContaining(r'$115 refund on its way to your card.'), findsOneWidget);
    });

    testWidgets("a provider sees where their share is", (tester) async {
      final booking = sampleBooking(
        status: BookingStatus.completed,
        paymentMethod: PaymentMethod.card,
        paymentStatus: PaymentStatus.paid,
        platformFeeCents: 632,
      ).copyWith(settlementStatus: 'held', payoutCents: 10868);
      await _pump(tester, BookingPriceCard(booking: booking, forProvider: true));
      expect(find.textContaining(r'Your $108.68 is on hold.'), findsOneWidget);
    });
  });
}
