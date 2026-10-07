import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myglo/src/core/routing/app_router.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/core/widgets/skeleton/skeletons.dart';
import 'package:myglo/src/core/widgets/soon_badge.dart';
import 'package:myglo/src/features/providers/business_tools/controllers/business_stats_controller.dart';
import 'package:myglo/src/features/providers/business_tools/models/business_stats.dart';
import 'package:myglo/src/features/providers/business_tools/models/business_stats_repository.dart';
import 'package:myglo/src/features/providers/business_tools/views/business_tools_screen.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:myglo/src/features/shared/bookings/controllers/booking_controllers.dart';
import 'package:myglo/src/features/shared/notifications/controllers/notifications_controller.dart';
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

final _october = BusinessStats.fromJson(const {
  'period_start': '2026-10-01',
  'time_zone': 'Australia/Brisbane',
  'completed_bookings': 7,
  'cash_collected_cents': 124050,
});

List<Override> _overrides(BusinessStatsRepository repository, {Stream<int>? bookingChanges}) => [
      userProfileProvider.overrideWith(
        (ref) async => AppUserProfile(
          rawUser: _providerUser,
          role: UserRole.provider,
          profile: const ProfileModel(id: 'prov-1', role: UserRole.provider, providerName: 'Glow Studio'),
        ),
      ),
      notificationsProvider.overrideWith(_EmptyInbox.new),
      bookingChangesProvider.overrideWith((ref) => bookingChanges ?? const Stream.empty()),
      businessStatsRepositoryProvider.overrideWithValue(repository),
    ];

/// Hosts the screen in a router with the routes it links to.
Future<GoRouter> _pump(WidgetTester tester, List<Override> overrides, {bool settle = true}) async {
  final router = GoRouter(
    initialLocation: AppRoute.businessTools.path,
    routes: [
      GoRoute(
        path: AppRoute.businessTools.path,
        name: AppRoute.businessTools.name,
        builder: (context, state) => const BusinessToolsScreen(),
      ),
      GoRoute(
        path: AppRoute.providerProfile.path,
        name: AppRoute.providerProfile.name,
        builder: (context, state) => const Text('Profile tab'),
      ),
      GoRoute(
        path: AppRoute.workingHours.path,
        name: AppRoute.workingHours.name,
        builder: (context, state) => const Text('Working hours'),
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
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

void main() {
  group('BusinessStats', () {
    test('reads the RPC row, including bigint totals sent as numbers', () {
      expect(_october.periodStart, DateTime.utc(2026, 10, 1));
      expect(_october.timeZone, 'Australia/Brisbane');
      expect(_october.completedBookings, 7);
      expect(_october.cashCollectedCents, 124050);
    });

    test('treats missing totals as zero', () {
      final stats = BusinessStats.fromJson(const {'period_start': '2026-02-01'});
      expect(stats.completedBookings, 0);
      expect(stats.cashCollectedCents, 0);
      expect(stats.timeZone, 'Australia/Brisbane');
    });

    test('refetch when one of the provider\'s bookings changes', () async {
      final changes = StreamController<int>();
      addTearDown(changes.close);
      final repository = _FakeRepository(_october);
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

  group('Business Tools overview', () {
    testWidgets("shows this month's real numbers instead of mock figures", (tester) async {
      await _pump(tester, _overrides(_FakeRepository(_october)));

      expect(find.text('October 2026'), findsOneWidget);
      expect(find.text(r'$1,240.50'), findsOneWidget);
      expect(find.text('Cash collected'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('Completed bookings'), findsOneWidget);
      // The old hard-coded figures are gone.
      for (final mock in [r'$1,240', '24', '156', '4.8 ★']) {
        expect(find.text(mock), findsNothing);
      }
    });

    testWidgets('a month with nothing yet reads as zero', (tester) async {
      final empty = BusinessStats.fromJson(const {
        'period_start': '2026-10-01',
        'completed_bookings': 0,
        'cash_collected_cents': 0,
      });
      await _pump(tester, _overrides(_FakeRepository(empty)));

      expect(find.text(r'$0'), findsOneWidget);
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('shows skeletons while the numbers load', (tester) async {
      final pending = Completer<BusinessStats>();
      await _pump(
        tester,
        [
          ..._overrides(_FakeRepository(_october)),
          businessStatsProvider.overrideWith((ref) => pending.future),
        ],
        settle: false,
      );

      expect(find.byType(SkeletonText), findsNWidgets(2));
      expect(find.text('Cash collected'), findsOneWidget);
      expect(find.text('October 2026'), findsNothing);

      pending.complete(_october);
      await tester.pumpAndSettle();
      expect(find.byType(SkeletonText), findsNothing);
      expect(find.text(r'$1,240.50'), findsOneWidget);
    });

    testWidgets('a failed load shows an inline error that can be retried', (tester) async {
      final repository = _FakeRepository(_october, failures: 1);
      await _pump(tester, _overrides(repository));

      expect(find.text("Your numbers didn't load"), findsOneWidget);
      expect(find.text(r'$1,240.50'), findsNothing);

      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(repository.calls, 2);
      expect(find.text("Your numbers didn't load"), findsNothing);
      expect(find.text(r'$1,240.50'), findsOneWidget);
    });

    testWidgets('profile views and rating are "Soon" placeholders, not numbers', (tester) async {
      await _pump(tester, _overrides(_FakeRepository(_october)));

      for (final title in ['Profile views', 'Rating']) {
        expect(
          find.descendant(of: find.ancestor(of: find.text(title), matching: find.byType(InkWell)), matching: find.byType(SoonBadge)),
          findsOneWidget,
        );
      }

      await _tapVisible(tester, find.text('Profile views'));
      expect(find.text('Profile views is coming soon'), findsOneWidget);

      await _tapVisible(tester, find.text('Rating'));
      expect(find.text('Ratings is coming soon'), findsOneWidget);
    });
  });

  group('Quick actions', () {
    testWidgets('Services & Pricing opens the profile tab with the services list', (tester) async {
      final router = await _pump(tester, _overrides(_FakeRepository(_october)));

      await _tapVisible(tester, find.text('Services & Pricing'));
      expect(find.text('Profile tab'), findsOneWidget);
      expect(router.routeInformationProvider.value.uri.path, AppRoute.providerProfile.path);
    });

    testWidgets('Financials is marked Soon and only explains that', (tester) async {
      await _pump(tester, _overrides(_FakeRepository(_october)));

      final tile = find.ancestor(of: find.text('Financials'), matching: find.byType(InkWell));
      expect(find.descendant(of: tile, matching: find.byType(SoonBadge)), findsOneWidget);
      expect(find.descendant(of: tile, matching: find.byIcon(Icons.chevron_right)), findsNothing);

      await _tapVisible(tester, find.text('Financials'));
      expect(find.text('Financials is coming soon'), findsOneWidget);
      expect(find.byType(BusinessToolsScreen), findsOneWidget);
    });

    testWidgets('Manage Schedule still opens working hours', (tester) async {
      await _pump(tester, _overrides(_FakeRepository(_october)));

      await _tapVisible(tester, find.text('Manage Schedule'));
      expect(find.text('Working hours'), findsOneWidget);
    });
  });
}
