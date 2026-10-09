import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myglo/src/core/location/device_location.dart';
import 'package:myglo/src/core/location/geo_point.dart';
import 'package:myglo/src/core/routing/app_router.dart';
import 'package:myglo/src/core/services/app_preferences.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/customers/explore/controllers/provider_search_controller.dart';
import 'package:myglo/src/features/customers/explore/models/explore_repository.dart';
import 'package:myglo/src/features/customers/explore/models/provider_listing.dart';
import 'package:myglo/src/features/customers/explore/views/provider_search_screen.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _glow = ProviderListing(
  id: 'p1',
  name: 'Glow Studio',
  addressText: '1 Cavill Ave, Surfers Paradise QLD',
  categories: ['Nails'],
  serviceCount: 4,
  minPrice: 35,
  matchedServices: [MatchedService(id: 's1', name: 'Gel nails', price: 45, durationMinutes: 60)],
);

const _mobile = ProviderListing(
  id: 'p2',
  name: 'Lash Van',
  categories: ['Lashes & Brows'],
  serviceCount: 2,
  offersStudio: false,
  offersMobile: true,
  acceptsBookings: false,
);

class _FakeExplore implements ExploreRepository {
  final queries = <String>[];
  List<ProviderListing> results = const [_glow, _mobile];
  Object? error;

  @override
  Future<List<ProviderListing>> search(String query, {GeoPoint? near, int limit = 30}) async {
    queries.add(query);
    if (error != null) throw error!;
    return results;
  }

  @override
  Future<List<ProviderListing>> providersAround(GeoPoint center, {required double radiusMetres, int limit = 200}) async =>
      const [];
}

Future<(_FakeExplore, SharedPreferences)> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  final explore = _FakeExplore();
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (context, state) => const ProviderSearchScreen()),
      GoRoute(
        path: '/provider/:id',
        name: AppRoute.publicProviderProfile.name,
        builder: (context, state) => Scaffold(body: Text('profile ${state.pathParameters['id']}')),
      ),
      GoRoute(
        path: '/map',
        name: AppRoute.providersMap.name,
        builder: (context, state) => const Scaffold(body: Text('the map')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        exploreRepositoryProvider.overrideWithValue(explore),
        passiveLocationProvider.overrideWith((ref) async => null),
        userProfileProvider.overrideWith(
          (ref) async => AppUserProfile(
            rawUser: User(
              id: 'client-1',
              appMetadata: const {},
              userMetadata: const {},
              aud: 'authenticated',
              createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
            ),
            role: UserRole.customer,
            profile: const ProfileModel(id: 'client-1', role: UserRole.customer, firstName: 'Ava'),
          ),
        ),
      ],
      child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return (explore, preferences);
}

Future<void> _type(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump(ProviderSearchController.debounce);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('before typing: map shortcut and categories', (tester) async {
    await _pump(tester);

    expect(find.text('Explore on the map'), findsOneWidget);
    expect(find.text('BROWSE BY CATEGORY'), findsOneWidget);
    expect(find.text('Nails'), findsOneWidget);
    expect(find.text('RECENT SEARCHES'), findsNothing);
  });

  testWidgets('one letter waits; two letters search', (tester) async {
    final (explore, _) = await _pump(tester);

    await _type(tester, 'g');
    expect(explore.queries, isEmpty);

    await _type(tester, 'ge');
    expect(explore.queries, ['ge']);
    expect(find.text('2 results'), findsOneWidget);
  });

  testWidgets('shows results with matched services and status', (tester) async {
    await _pump(tester);

    await _type(tester, 'gel');

    expect(find.textContaining('Glow Studio', findRichText: true), findsOneWidget);
    expect(find.textContaining('Gel nails', findRichText: true), findsOneWidget);
    expect(find.text('From \$35'), findsOneWidget);
    expect(find.textContaining('Comes to you', findRichText: true), findsOneWidget);
    expect(find.text('Not taking bookings'), findsOneWidget);
  });

  testWidgets('a category searches straight away and is remembered', (tester) async {
    final (explore, preferences) = await _pump(tester);

    await tester.tap(find.text('Nails'));
    await tester.pumpAndSettle();

    expect(explore.queries, ['Nails']);
    expect(preferences.getStringList('recent_searches.client-1'), ['Nails']);
  });

  testWidgets('opening a result goes to the profile and saves the search', (tester) async {
    final (_, preferences) = await _pump(tester);

    await _type(tester, 'glow');
    await tester.tap(find.textContaining('Glow Studio', findRichText: true));
    await tester.pumpAndSettle();

    expect(find.text('profile p1'), findsOneWidget);
    expect(preferences.getStringList('recent_searches.client-1'), ['glow']);
  });

  testWidgets('no matches suggests the map', (tester) async {
    final (explore, _) = await _pump(tester);
    explore.results = const [];

    await _type(tester, 'zzz');

    expect(find.text('No matches for “zzz”'), findsOneWidget);
    await tester.tap(find.text('Explore the map'));
    await tester.pumpAndSettle();
    expect(find.text('the map'), findsOneWidget);
  });

  testWidgets('a failed search can be retried', (tester) async {
    final (explore, _) = await _pump(tester);
    explore.error = const SocketException('offline');

    await _type(tester, 'hair');
    expect(find.text("Search didn't work"), findsOneWidget);

    explore.error = null;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();

    expect(explore.queries, ['hair', 'hair']);
    expect(find.text('2 results'), findsOneWidget);
  });

  testWidgets('recent searches can be reused and cleared', (tester) async {
    await _pump(tester);

    await tester.tap(find.text('Hair'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Clear'));
    await tester.pumpAndSettle();

    expect(find.text('RECENT SEARCHES'), findsOneWidget);
    expect(find.text('Hair'), findsNWidgets(2));

    await tester.tap(find.widgetWithText(TextButton, 'Clear'));
    await tester.pumpAndSettle();
    expect(find.text('RECENT SEARCHES'), findsNothing);
  });
}
