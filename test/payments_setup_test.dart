import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/providers/payments/models/payments_repository.dart';
import 'package:myglo/src/features/providers/payments/models/payments_setup.dart';
import 'package:myglo/src/features/providers/payments/views/payments_setup_screen.dart';
import 'package:myglo/src/features/providers/schedule/controllers/provider_schedule_controller.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_settings.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class _FakePayments implements PaymentsRepository {
  _FakePayments(this.setup);

  final PaymentsSetup setup;

  @override
  Future<PaymentsSetup> getSetup() async => setup;

  @override
  Future<PaymentsSetup> refresh() async => setup;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError('${invocation.memberName}');
}

Future<void> _pump(WidgetTester tester, PaymentsSetup setup, {ProviderBookingSettings? settings}) async {
  final overrides = <Override>[
    paymentsRepositoryProvider.overrideWithValue(_FakePayments(setup)),
    ownBookingSettingsProvider.overrideWith(
      (ref) => AsyncData(settings ?? const ProviderBookingSettings(providerId: 'prov-1')),
    ),
  ];
  await tester.pumpWidget(ProviderScope(
    overrides: overrides,
    retry: (_, _) => null,
    child: MaterialApp(theme: AppTheme.lightTheme, home: const PaymentsSetupScreen()),
  ));
  await tester.pumpAndSettle();
}

void main() {
  group('ProviderBookingSettings payment rules', () {
    const base = ProviderBookingSettings(providerId: 'p');

    test('cash is always taken until card payments are ready', () {
      final noCashNotReady = base.copyWith(acceptsCash: false, acceptsCard: true, cardReady: false);
      expect(noCashNotReady.takesCard, isFalse);
      expect(noCashNotReady.takesCash, isTrue);
    });

    test('a provider can go card-only once card payments are ready', () {
      final cardOnly = base.copyWith(acceptsCash: false, acceptsCard: true, cardReady: true);
      expect(cardOnly.takesCard, isTrue);
      expect(cardOnly.takesCash, isFalse);
    });

    test('card is never offered before the payout account works', () {
      expect(base.copyWith(acceptsCard: true, cardReady: false).takesCard, isFalse);
      expect(base.copyWith(acceptsCard: false, cardReady: true).takesCard, isFalse);
    });

    test('reads the new columns', () {
      final settings = ProviderBookingSettings.fromJson({
        'provider_id': 'p',
        'accepts_cash': false,
        'accepts_card': true,
        'card_ready': true,
      });
      expect((settings.acceptsCash, settings.acceptsCard, settings.cardReady), (false, true, true));
    });
  });

  group('PaymentsSetup', () {
    test('reads statuses and falls back for new ones', () {
      expect(PaymentsSetup.fromJson({'status': 'action_needed'}).status, PaymentsSetupStatus.actionNeeded);
      expect(PaymentsSetup.fromJson({'status': 'something_new'}).status, PaymentsSetupStatus.unknown);
    });

    test('fee-free while the period lasts or when the fee is zero', () {
      final now = DateTime.utc(2026, 11, 1);
      expect(PaymentsSetup(feePercent: 5.5, feeFreeUntil: DateTime.utc(2026, 11, 10)).isFeeFree(now), isTrue);
      expect(PaymentsSetup(feePercent: 5.5, feeFreeUntil: DateTime.utc(2026, 10, 10)).isFeeFree(now), isFalse);
      expect(const PaymentsSetup().isFeeFree(now), isTrue);
    });

    test('which statuses need the provider and which can take cards', () {
      expect(PaymentsSetupStatus.actionNeeded.canTakeCards, isTrue);
      expect(PaymentsSetupStatus.actionNeeded.needsProvider, isTrue);
      expect(PaymentsSetupStatus.verifying.needsProvider, isFalse);
      expect(PaymentsSetupStatus.restricted.canTakeCards, isFalse);
    });
  });

  test('connect errors map to friendly failures', () {
    PaymentsFailureCode code(int status, Object? details) =>
        PaymentsFailure.from(FunctionException(status: status, details: details)).code;
    expect(code(409, {'error': 'not_onboarded'}), PaymentsFailureCode.notOnboarded);
    expect(code(403, {'error': 'providers_only'}), PaymentsFailureCode.notAllowed);
    expect(code(503, {'error': 'payments_unavailable'}), PaymentsFailureCode.unavailable);
    expect(code(502, null), PaymentsFailureCode.unavailable);
  });

  group('PaymentsSetupScreen', () {
    testWidgets('a new provider is invited to set up payouts', (tester) async {
      await _pump(tester, const PaymentsSetup(feePercent: 5.5, feeFreeDays: 14));
      expect(find.text('Take card payments'), findsOneWidget);
      expect(find.text('Set up payouts'), findsOneWidget);
      expect(find.textContaining('first 14 days of card payments are free'), findsOneWidget);
    });

    testWidgets("lists what Stripe needs and offers to continue", (tester) async {
      await _pump(tester, const PaymentsSetup(status: PaymentsSetupStatus.onboarding, requirementsDue: ['Date of birth']));
      expect(find.text('Finish setting up payouts'), findsOneWidget);
      expect(find.text('• Date of birth'), findsOneWidget);
      expect(find.text('Continue with Stripe'), findsOneWidget);
    });

    testWidgets('an active account opens the Stripe dashboard instead', (tester) async {
      await _pump(
        tester,
        const PaymentsSetup(status: PaymentsSetupStatus.active, payoutsEnabled: true),
        settings: const ProviderBookingSettings(providerId: 'prov-1', cardReady: true),
      );
      expect(find.text('Card payments are on'), findsOneWidget);
      expect(find.text('Set up payouts'), findsNothing);
      expect(find.text('Bank details & payout history'), findsOneWidget);
      expect(find.text('No Myglo fee on card bookings right now.'), findsOneWidget);
    });

    testWidgets('cash can only be turned off once clients can pay in the app', (tester) async {
      await _pump(tester, const PaymentsSetup());
      await tester.scrollUntilVisible(find.text('Cash at the appointment'), 200);
      final cashSwitch = tester.widget<Switch>(find.descendant(
        of: find.ancestor(of: find.text('Cash at the appointment'), matching: find.byType(Row)).first,
        matching: find.byType(Switch),
      ));
      expect(cashSwitch.value, isTrue);
      expect(cashSwitch.onChanged, isNull);
      expect(find.text('Always on until clients can pay in the app'), findsOneWidget);
    });
  });
}
