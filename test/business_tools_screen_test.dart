import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myglo/src/core/routing/app_router.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/core/widgets/skeleton/skeletons.dart';
import 'package:myglo/src/features/providers/business_tools/controllers/business_stats_controller.dart';
import 'package:myglo/src/features/providers/business_tools/controllers/contacts_controllers.dart';
import 'package:myglo/src/features/providers/business_tools/models/business_stats.dart';
import 'package:myglo/src/features/providers/business_tools/models/business_stats_repository.dart';
import 'package:myglo/src/features/providers/business_tools/models/contacts_repository.dart';
import 'package:myglo/src/features/providers/business_tools/views/business_tools_screen.dart';
import 'package:myglo/src/features/providers/business_tools/views/widgets/business_attention.dart';
import 'package:myglo/src/features/providers/business_tools/views/widgets/business_manage.dart';
import 'package:myglo/src/features/providers/payments/controllers/payments_controllers.dart';
import 'package:myglo/src/features/providers/payments/models/payments_setup.dart';
import 'package:myglo/src/features/providers/provider_profiles/controllers/provider_services_controller.dart';
import 'package:myglo/src/features/providers/provider_profiles/models/service_model.dart';
import 'package:myglo/src/features/providers/schedule/controllers/provider_schedule_controller.dart';
import 'package:myglo/src/features/providers/schedule/models/time_off.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:myglo/src/features/shared/bookings/controllers/booking_controllers.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_settings.dart';
import 'package:myglo/src/features/shared/bookings/models/working_hours.dart';
import 'package:myglo/src/features/shared/notifications/controllers/notifications_controller.dart';
import 'package:myglo/src/features/shared/reviews/controllers/reviews_controllers.dart';
import 'package:myglo/src/features/shared/reviews/models/review.dart';
import 'package:myglo/src/features/shared/reviews/models/review_summary.dart';
import 'package:myglo/src/features/shared/reviews/models/reviews_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

/// One unanswered review; the summary comes from an override.
class _FakeReviews implements ReviewsRepository {
  @override
  Future<List<Review>> list({
    String? providerId,
    String? serviceId,
    String? bookingId,
    Review? before,
    required int limit,
  }) async =>
      [
        Review(
          id: 'r-1',
          bookingId: 'b-1',
          providerId: 'prov-1',
          clientId: 'c-1',
          reviewerName: 'Mia T.',
          rating: 5,
          body: 'Loved it',
          createdAt: DateTime.utc(2026, 10, 1),
        ),
      ];

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

/// Fails the first [failures] calls, then serves [stats].
class _FakeRepository implements BusinessStatsRepository {
  _FakeRepository(this.stats, {this.failures = 0});

  final BusinessStats stats;
  int failures;
  int calls = 0;

  @override
  Future<BusinessStats> thisMonth() async {
    calls++;
    if (failures > 0) {
      failures--;
      throw const PostgrestException(message: 'boom', code: '500');
    }
    return stats;
  }
}

/// Serves a fixed client count.
class _FakeContacts implements ContactsRepository {
  _FakeContacts(this.total);

  final int total;

  @override
  Future<int> count() async => total;

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

/// Serves a fixed payments set-up.
class _FakeSetup extends PaymentsSetupController {
  _FakeSetup(this.setup);

  final PaymentsSetup setup;

  @override
  Future<PaymentsSetup> build() async => setup;
}

const _active = PaymentsSetup(status: PaymentsSetupStatus.active, payoutsEnabled: true);

final _november = BusinessStats.fromJson(const {
  'period_start': '2026-11-01',
  'time_zone': 'Australia/Brisbane',
  'completed_bookings': 7,
  'cash_collected_cents': 24050,
  'card_earned_cents': 100000,
  'previous_completed_bookings': 5,
  'previous_earned_cents': 98000,
  'upcoming_week_bookings': 3,
});

final _service = ServiceModel(
  id: 'svc-1',
  providerId: 'prov-1',
  name: 'Lash lift',
  description: '',
  price: 85,
  durationMinutes: 70,
  createdAt: DateTime.utc(2026, 9, 1),
);

/// Monday to Friday, 9 to 5.
final _weekdays = WeeklySchedule([
  for (var day = 1; day <= 5; day++) WorkingHoursRange(weekday: day, opensMinutes: 540, closesMinutes: 1020),
]);

List<Override> _overrides(
  BusinessStatsRepository repository, {
  Stream<int>? bookingChanges,
  PaymentsSetup setup = _active,
  ProviderBookingSettings settings = const ProviderBookingSettings(providerId: 'prov-1'),
  List<ServiceModel>? services,
  WeeklySchedule? hours,
  List<TimeOffBlock> timeOff = const [],
  bool phoneVerified = true,
}) =>
    [
      userProfileProvider.overrideWith(
        (ref) async => AppUserProfile(
          rawUser: _providerUser,
          role: UserRole.provider,
          profile: ProfileModel(
            id: 'prov-1',
            role: UserRole.provider,
            providerName: 'Glow Studio',
            phoneNumber: '+61412345678',
            phoneVerifiedAt: phoneVerified ? DateTime(2026, 11, 1) : null,
            addressText: '1 Cavill Ave, Surfers Paradise QLD 4217',
            coordinates: const LocationCoordinates(type: 'Point', coordinates: [153.43, -28.0]),
          ),
        ),
      ),
      notificationsProvider.overrideWith(_EmptyInbox.new),
      bookingChangesProvider.overrideWith((ref) => bookingChanges ?? const Stream.empty()),
      businessStatsRepositoryProvider.overrideWithValue(repository),
      contactsRepositoryProvider.overrideWithValue(_FakeContacts(23)),
      paymentsSetupProvider.overrideWith(() => _FakeSetup(setup)),
      bookingSettingsProvider.overrideWith((ref, id) => Stream.value(settings)),
      providerServicesProvider('prov-1').overrideWith((ref) async => services ?? [_service]),
      workingHoursProvider.overrideWith((ref, id) async => hours ?? _weekdays),
      ownTimeOffProvider.overrideWith((ref) async => timeOff),
    ];

/// Hosts the screen in a router with the routes it links to.
Future<GoRouter> _pump(WidgetTester tester, List<Override> overrides, {bool settle = true}) async {
  Widget page(String label) => Scaffold(body: Text(label));
  final router = GoRouter(
    initialLocation: AppRoute.businessTools.path,
    routes: [
      GoRoute(
        path: AppRoute.businessTools.path,
        name: AppRoute.businessTools.name,
        builder: (context, state) => const BusinessToolsScreen(),
      ),
      GoRoute(
        path: AppRoute.providerHome.path,
        name: AppRoute.providerHome.name,
        builder: (context, state) => page('Home tab ${state.uri.queryParameters['tab'] ?? 'upcoming'}'),
      ),
      GoRoute(
        path: AppRoute.providerProfile.path,
        name: AppRoute.providerProfile.name,
        builder: (context, state) => page('Profile tab'),
        routes: [
          GoRoute(
            path: AppRoute.settings.path,
            name: AppRoute.settings.name,
            builder: (context, state) => page('Settings screen'),
          ),
        ],
      ),
      for (final (route, label) in [
        (AppRoute.workingHours, 'Working hours screen'),
        (AppRoute.timeOff, 'Time off screen'),
        (AppRoute.serviceArea, 'Service area screen'),
        (AppRoute.providerContacts, 'Contacts screen'),
      ])
        GoRoute(path: route.path, name: route.name, builder: (context, state) => page(label)),
      GoRoute(
        path: AppRoute.providerPayments.path,
        name: AppRoute.providerPayments.name,
        builder: (context, state) => page('Payments screen'),
        routes: [
          GoRoute(
            path: AppRoute.providerEarnings.path,
            name: AppRoute.providerEarnings.name,
            builder: (context, state) => page('Earnings screen'),
          ),
        ],
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: overrides,
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        // Keeps the shimmer still so frames settle.
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(disableAnimations: true),
          child: child!,
        ),
        routerConfig: router,
      ),
    ),
  );
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return router;
}

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(finder, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('BusinessStats', () {
    test('reads the RPC row, including bigint totals sent as numbers', () {
      expect(_november.periodStart, DateTime.utc(2026, 11, 1));
      expect(_november.previousPeriodStart, DateTime.utc(2026, 10, 1));
      expect(_november.timeZone, 'Australia/Brisbane');
      expect(_november.completedBookings, 7);
      expect(_november.cashCollectedCents, 24050);
      expect(_november.earnedCents, 124050);
      expect(_november.previousCompletedBookings, 5);
      expect(_november.upcomingWeekBookings, 3);
    });

    test('treats missing figures as zero', () {
      final stats = BusinessStats.fromJson(const {'period_start': '2026-02-01'});
      expect(stats.completedBookings, 0);
      expect(stats.earnedCents, 0);
      expect(stats.previousEarnedCents, 0);
      expect(stats.pendingRequests, 0);
      expect(stats.nextReplyBy, isNull);
      expect(stats.nextReplyByLocal, isNull);
      expect(stats.reviewsAwaitingReply, 0);
      expect(stats.onItsWayCents, 0);
      expect(stats.timeZone, 'Australia/Brisbane');
    });

    test('reads the reply deadline as an instant and shows it on the provider\'s clock', () {
      final stats = BusinessStats.fromJson(const {
        'period_start': '2026-11-01',
        'time_zone': 'Australia/Brisbane',
        'pending_requests': 2,
        'next_reply_by': '2026-11-08T09:49:00+00:00',
      });
      expect(stats.nextReplyBy, DateTime.utc(2026, 11, 8, 9, 49));
      // Brisbane is UTC+10 all year.
      expect(stats.nextReplyByLocal, DateTime.utc(2026, 11, 8, 19, 49));
    });

    test('last month rolls back over the new year', () {
      final january = BusinessStats.fromJson(const {'period_start': '2027-01-01'});
      expect(january.previousPeriodStart, DateTime.utc(2026, 12, 1));
    });

    test("refetch when one of the provider's bookings changes", () async {
      final changes = StreamController<int>();
      addTearDown(changes.close);
      final repository = _FakeRepository(_november);
      final container = ProviderContainer.test(
        retry: (_, _) => null,
        overrides: _overrides(repository, bookingChanges: changes.stream),
      );
      container.listen(businessStatsProvider, (_, _) {});

      await container.read(businessStatsProvider.future);
      expect(repository.calls, 1);

      changes.add(1);
      await Future<void>.delayed(Duration.zero);
      await container.read(businessStatsProvider.future);
      expect(repository.calls, 2);
    });
  });

  group('Summaries', () {
    test('working hours', () {
      expect(workingHoursSummary(null), isNull);
      expect(workingHoursSummary(WeeklySchedule(const [])), "Not set. Clients can't book you yet");
      expect(workingHoursSummary(_weekdays), 'Open 5 days a week');
      expect(
        workingHoursSummary(WeeklySchedule(const [WorkingHoursRange(weekday: 6, opensMinutes: 540, closesMinutes: 720)])),
        'Open 1 day a week',
      );
      expect(
        workingHoursSummary(WeeklySchedule([
          for (var day = 1; day <= 7; day++) WorkingHoursRange(weekday: day, opensMinutes: 540, closesMinutes: 1020),
        ])),
        'Open every day',
      );
    });

    test('time off, in the provider\'s time zone', () {
      final now = DateTime.utc(2026, 11, 2, 1);
      TimeOffBlock block(String id, DateTime start, DateTime end) => TimeOffBlock(id: id, startsAt: start, endsAt: end);

      expect(timeOffSummary(null, timeZone: 'Australia/Brisbane', now: now), isNull);
      expect(timeOffSummary(const [], timeZone: 'Australia/Brisbane', now: now), 'No time off planned');
      // Starts 14:00 UTC on Fri 13 Nov, which is Sat 14 Nov in Brisbane.
      final saturday = block('a', DateTime.utc(2026, 11, 13, 14), DateTime.utc(2026, 11, 14, 14));
      final later = block('b', DateTime.utc(2026, 12, 1), DateTime.utc(2026, 12, 2));
      expect(timeOffSummary([later, saturday], timeZone: 'Australia/Brisbane', now: now), 'Next: Sat 14 Nov · 2 planned');
      final current = block('c', DateTime.utc(2026, 11, 1), DateTime.utc(2026, 11, 3, 8));
      expect(timeOffSummary([current], timeZone: 'Australia/Brisbane', now: now), 'Off now, back Tue 3 Nov, 6:00 pm');
    });

    test('booking rules', () {
      expect(bookingRulesSummary(null), isNull);
      expect(
        bookingRulesSummary(const ProviderBookingSettings(providerId: 'p')),
        'Clients book instantly · free to cancel until 24 h before',
      );
      expect(
        bookingRulesSummary(const ProviderBookingSettings(providerId: 'p', requiresApproval: true, cancellationWindowHours: 0)),
        'You approve each booking · free to cancel any time',
      );
    });

    test('services and payments', () {
      expect(servicesSummary(null), isNull);
      expect(servicesSummary(const []), 'Add your first service');
      expect(servicesSummary([_service]), '1 service');
      expect(servicesSummary([_service, _service]), '2 services');

      expect(paymentsSummary(null), isNull);
      expect(paymentsSummary(_active), 'Card payments on · paid out every Monday');
      expect(paymentsSummary(const PaymentsSetup()), 'Not set up. Clients pay in cash');
      expect(paymentsSummary(const PaymentsSetup(status: PaymentsSetupStatus.restricted)), 'Paused: Stripe needs details from you');
    });

    test('card payments only ask for attention when the provider has something to do', () {
      const cardOff = ProviderBookingSettings(providerId: 'p', acceptsCard: false);
      expect(paymentsAttention(null, null), isNull);
      expect(paymentsAttention(_active, null), isNull);
      expect(paymentsAttention(const PaymentsSetup(status: PaymentsSetupStatus.verifying), null), isNull);
      expect(paymentsAttention(const PaymentsSetup(), null)?.title, 'Take card payments');
      // A provider who turned card payments off isn't nagged to set them up.
      expect(paymentsAttention(const PaymentsSetup(), cardOff), isNull);
      final due = paymentsAttention(
        PaymentsSetup(status: PaymentsSetupStatus.actionNeeded, requirementsDeadline: DateTime.utc(2026, 11, 20, 14)),
        null,
      );
      expect(due?.title, 'Stripe needs more details');
      expect(due?.subtitle, 'Send them by Sat 21 Nov to keep taking card payments');
      expect(paymentsAttention(const PaymentsSetup(status: PaymentsSetupStatus.restricted), cardOff)?.title,
          'Card payments are paused');
    });
  });

  group('This month', () {
    testWidgets('shows earnings split by card and cash, with last month beside them', (tester) async {
      await _pump(tester, _overrides(_FakeRepository(_november)));

      expect(find.text('My business'), findsOneWidget);
      expect(find.text('NOVEMBER 2026'), findsNothing); // The month label isn't shouted.
      expect(find.text('November 2026'), findsOneWidget);
      expect(find.text(r'$1,240.50'), findsOneWidget);
      expect(find.text('Earned in November'), findsOneWidget);
      expect(find.text('In the app'), findsOneWidget);
      expect(find.text(r'$1,000'), findsOneWidget);
      expect(find.text('Cash'), findsOneWidget);
      expect(find.text(r'$240.50'), findsOneWidget);
      expect(find.text('October'), findsOneWidget);
      expect(find.text(r'$980'), findsOneWidget);
      // Nothing is waiting for a transfer.
      expect(find.textContaining('on its way'), findsNothing);
    });

    testWidgets('mentions card money still on its way and opens Earnings', (tester) async {
      final stats = BusinessStats.fromJson(const {
        'period_start': '2026-11-01',
        'card_earned_cents': 5000,
        'on_its_way_cents': 5000,
      });
      await _pump(tester, _overrides(_FakeRepository(stats)));

      expect(find.text(r'$50 on its way to your Stripe balance'), findsOneWidget);
      await tester.tap(find.text('Earned in November'));
      await tester.pumpAndSettle();
      expect(find.text('Earnings screen'), findsOneWidget);
    });

    testWidgets('completed bookings compare with last month, and the week ahead opens appointments', (tester) async {
      await _pump(tester, _overrides(_FakeRepository(_november)));

      expect(find.text('7'), findsOneWidget);
      expect(find.text('Completed bookings'), findsOneWidget);
      expect(find.text('October: 5'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.bySemanticsLabel('Coming up in the next 7 days: 3 confirmed appointments'), findsOneWidget);

      await _tapVisible(tester, find.text('Coming up'));
      expect(find.text('Home tab upcoming'), findsOneWidget);
    });

    testWidgets('a month with nothing yet reads as zero', (tester) async {
      final empty = BusinessStats.fromJson(const {'period_start': '2026-11-01'});
      await _pump(tester, _overrides(_FakeRepository(empty)));

      expect(find.text(r'$0'), findsNWidgets(4)); // Earned, in the app, cash, last month.
      expect(find.text('0'), findsNWidgets(2));
      expect(find.text('October: 0'), findsOneWidget);
    });

    testWidgets('shows skeletons while the numbers load', (tester) async {
      final pending = Completer<BusinessStats>();
      final pendingCount = Completer<int>();
      await _pump(
        tester,
        [
          ..._overrides(_FakeRepository(_november)),
          businessStatsProvider.overrideWith((ref) => pending.future),
          providerContactCountProvider.overrideWith((ref) => pendingCount.future),
        ],
        settle: false,
      );

      // Earned, completed, the week ahead and the client count.
      expect(find.byType(SkeletonText), findsNWidgets(4));
      expect(find.text('Earned this month'), findsOneWidget);
      expect(find.text('November 2026'), findsNothing);

      pending.complete(_november);
      pendingCount.complete(23);
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonText), findsNothing);
      expect(find.text(r'$1,240.50'), findsOneWidget);
    });

    testWidgets('a failed load shows an inline error that can be retried', (tester) async {
      final repository = _FakeRepository(_november, failures: 1);
      await _pump(tester, _overrides(repository));

      expect(find.text("Your numbers didn't load"), findsOneWidget);
      expect(find.text(r'$1,240.50'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(find.text("Your numbers didn't load"), findsNothing);
      expect(find.text(r'$1,240.50'), findsOneWidget);
    });

    testWidgets('rating and review count share one live card that opens the reviews', (tester) async {
      await _pump(tester, [
        ..._overrides(_FakeRepository(_november)),
        providerReviewSummaryProvider('prov-1').overrideWith(
          (ref) async => const ReviewSummary(count: 12, average: 4.75, starCounts: [0, 0, 1, 1, 10]),
        ),
        reviewsRepositoryProvider.overrideWithValue(_FakeReviews()),
      ]);

      expect(find.text('4.8'), findsOneWidget);
      expect(find.text('(12)'), findsOneWidget);
      expect(find.bySemanticsLabel('Rating 4.8 from 12 reviews'), findsOneWidget);

      await _tapVisible(tester, find.text('Rating & reviews'));
      expect(find.text('Your reviews'), findsOneWidget);
      expect(find.text('Mia T.'), findsOneWidget);
      // Providers can answer from here.
      expect(find.text('Reply publicly'), findsOneWidget);
    });

    testWidgets('a provider nobody has reviewed yet reads as new', (tester) async {
      await _pump(tester, [
        ..._overrides(_FakeRepository(_november)),
        providerReviewSummaryProvider('prov-1').overrideWith((ref) async => ReviewSummary.empty),
      ]);

      expect(find.text('New'), findsOneWidget);
    });

    testWidgets('the contacts card counts clients and opens the contacts list', (tester) async {
      await _pump(tester, _overrides(_FakeRepository(_november)));

      expect(find.text('23'), findsOneWidget);
      expect(find.bySemanticsLabel('Contacts: 23 clients'), findsOneWidget);

      await _tapVisible(tester, find.text('Contacts'));
      expect(find.text('Contacts screen'), findsOneWidget);
    });

    testWidgets('the client count refetches when a booking changes', (tester) async {
      final changes = StreamController<int>();
      addTearDown(changes.close);
      var calls = 0;
      await _pump(tester, [
        ..._overrides(_FakeRepository(_november), bookingChanges: changes.stream),
        providerContactCountProvider.overrideWith((ref) async {
          ref.watch(bookingChangesProvider);
          return ++calls;
        }),
      ]);
      expect(find.bySemanticsLabel('Contacts: 1 client'), findsOneWidget);

      changes.add(1);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Contacts: 2 clients'), findsOneWidget);
    });
  });

  group('Needs your attention', () {
    testWidgets('is hidden when there is nothing to do', (tester) async {
      await _pump(tester, _overrides(_FakeRepository(_november)));

      expect(find.text('NEEDS YOUR ATTENTION'), findsNothing);
    });

    testWidgets('asks a provider with an unverified phone number to verify it', (tester) async {
      await _pump(tester, _overrides(_FakeRepository(_november), phoneVerified: false));

      expect(find.text('NEEDS YOUR ATTENTION'), findsOneWidget);
      expect(find.text('Verify your phone number'), findsOneWidget);
    });

    testWidgets('lists waiting requests, unanswered reviews and card payments to set up', (tester) async {
      final stats = BusinessStats.fromJson(const {
        'period_start': '2026-11-01',
        'time_zone': 'Australia/Brisbane',
        'pending_requests': 2,
        'next_reply_by': '2026-11-08T09:49:00+00:00',
        'reviews_awaiting_reply': 1,
      });
      await _pump(tester, _overrides(_FakeRepository(stats), setup: const PaymentsSetup()));

      expect(find.text('NEEDS YOUR ATTENTION'), findsOneWidget);
      expect(find.text('2 requests waiting'), findsOneWidget);
      expect(find.text('Reply by Sun 8 Nov, 7:49 pm, or it expires'), findsOneWidget);
      expect(find.text('1 review to reply to'), findsOneWidget);
      expect(find.text('Take card payments'), findsOneWidget);

      await tester.tap(find.text('2 requests waiting'));
      await tester.pumpAndSettle();
      // Opens appointments on the Requests list.
      expect(find.text('Home tab requests'), findsOneWidget);
    });

    testWidgets('the card payments row opens Payments & payouts', (tester) async {
      await _pump(
        tester,
        _overrides(
          _FakeRepository(_november),
          setup: const PaymentsSetup(status: PaymentsSetupStatus.restricted),
        ),
      );

      await tester.tap(find.text('Card payments are paused'));
      await tester.pumpAndSettle();
      expect(find.text('Payments screen'), findsOneWidget);
    });

    testWidgets('flags paused bookings and unfinished set-up', (tester) async {
      await _pump(
        tester,
        _overrides(
          _FakeRepository(_november),
          settings: const ProviderBookingSettings(providerId: 'prov-1', acceptsBookings: false),
          services: const [],
        ),
      );

      expect(find.text('New bookings are paused'), findsOneWidget);
      expect(find.text('Finish setting up'), findsOneWidget);
      expect(find.textContaining('2 of 3 done'), findsOneWidget);
    });
  });

  group('Manage', () {
    testWidgets('each tool shows where it stands', (tester) async {
      await _pump(tester, _overrides(_FakeRepository(_november)));

      await tester.scrollUntilVisible(find.text('Earnings'), 200, scrollable: find.byType(Scrollable).first);
      expect(find.text('Open 5 days a week'), findsOneWidget);
      expect(find.text('No time off planned'), findsOneWidget);
      expect(find.text('Clients book instantly · free to cancel until 24 h before'), findsOneWidget);
      expect(find.text('1 service'), findsOneWidget);
      expect(find.text('At your studio'), findsOneWidget);
      expect(find.text('Card payments on · paid out every Monday'), findsOneWidget);
    });

    testWidgets('rows open their tools', (tester) async {
      for (final (row, screen) in [
        ('Working hours', 'Working hours screen'),
        ('Time off', 'Time off screen'),
        ('Booking rules', 'Settings screen'),
        ('Services & pricing', 'Profile tab'),
        ('Where you work', 'Service area screen'),
        ('Payments & payouts', 'Payments screen'),
        ('Earnings', 'Earnings screen'),
      ]) {
        await _pump(tester, _overrides(_FakeRepository(_november)));
        await _tapVisible(tester, find.text(row));
        expect(find.text(screen), findsOneWidget, reason: row);
      }
    });
  });
}
