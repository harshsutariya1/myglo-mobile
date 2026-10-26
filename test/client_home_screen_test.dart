import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:myglo/src/core/location/device_location.dart';
import 'package:myglo/src/core/location/geo_point.dart';
import 'package:myglo/src/core/routing/app_router.dart';
import 'package:myglo/src/core/services/app_preferences.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/customers/explore/models/explore_repository.dart';
import 'package:myglo/src/features/customers/explore/models/provider_listing.dart';
import 'package:myglo/src/features/customers/favourites/controllers/favourites_controller.dart';
import 'package:myglo/src/features/customers/home/controllers/home_controller.dart';
import 'package:myglo/src/features/customers/home/controllers/home_location_controller.dart';
import 'package:myglo/src/features/customers/home/models/service_cities_repository.dart';
import 'package:myglo/src/features/customers/home/models/service_city.dart';
import 'package:myglo/src/features/customers/home/views/home_screen.dart';
import 'package:myglo/src/features/customers/home/views/welcome_greeting.dart';
import 'package:myglo/src/features/customers/home/views/widgets/home_location_picker.dart';
import 'package:myglo/src/features/customers/home/views/widgets/home_no_salons.dart';
import 'package:myglo/src/features/customers/home/views/widgets/home_provider_cards.dart';
import 'package:myglo/src/features/customers/home/views/widgets/next_appointment_card.dart';
import 'package:myglo/src/features/shared/authentication/controllers/user_profile_provider.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';
import 'package:myglo/src/features/shared/bookings/controllers/booking_controllers.dart';
import 'package:myglo/src/features/shared/bookings/models/booking.dart';
import 'package:myglo/src/features/shared/bookings/models/booking_enums.dart';
import 'package:myglo/src/features/shared/notifications/controllers/notifications_controller.dart';
import 'package:myglo/src/features/shared/notifications/models/app_notification.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/booking_fixtures.dart';

final _user = User(
  id: 'client-1',
  appMetadata: const {},
  userMetadata: const {},
  aud: 'authenticated',
  createdAt: DateTime.utc(2026, 1, 1).toIso8601String(),
);

const _choiceKey = 'home_location.client-1';

const _goldCoast = ServiceCity(
  id: 'gc',
  name: 'Gold Coast',
  state: 'QLD',
  centre: GeoPoint(latitude: -28.0167, longitude: 153.4),
  radiusMetres: 30000,
  providerCount: 21,
);

const _brisbane = ServiceCity(
  id: 'bne',
  name: 'Brisbane',
  state: 'QLD',
  centre: GeoPoint(latitude: -27.4698, longitude: 153.0251),
  radiusMetres: 25000,
);

/// Somewhere on the Gold Coast, and somewhere with no salons.
const _surfers = GeoPoint(latitude: -28.00234, longitude: 153.41459);
const _ahmedabad = GeoPoint(latitude: 23.02, longitude: 72.57);

const _glow = ProviderListing(
  id: 'p1',
  name: 'Glow Studio',
  addressText: '1 Cavill Ave, Surfers Paradise QLD',
  distanceKm: 1.2,
  categories: ['Nails'],
  serviceCount: 4,
  minPrice: 35,
  ratingAverage: 4.6,
  reviewCount: 12,
);

const _lash = ProviderListing(
  id: 'p2',
  name: 'Lash Van',
  distanceKm: 4.8,
  categories: ['Lashes & Brows'],
  serviceCount: 2,
  offersStudio: false,
  offersMobile: true,
);

const _fresh = ProviderListing(
  id: 'p3',
  name: 'Fresh Cuts',
  addressText: 'Southport QLD',
  distanceKm: 6.1,
  categories: ['Hair'],
  serviceCount: 1,
  minPrice: 50,
  acceptsBookings: false,
);

/// Answers `providersAround` per centre: the Gold Coast (city or the
/// Surfers Paradise device position) has salons, anywhere else has none.
class _FakeExplore implements ExploreRepository {
  _FakeExplore({this.goldCoast = const [_glow, _lash, _fresh]});

  final List<ProviderListing> goldCoast;
  final requests = <({GeoPoint centre, double radius})>[];
  Object? error;

  @override
  Future<List<ProviderListing>> providersAround(GeoPoint center, {required double radiusMetres, int limit = 200}) async {
    requests.add((centre: center, radius: radiusMetres));
    if (error != null) throw error!;
    return center.distanceKmTo(_goldCoast.centre) < 20 ? goldCoast : const [];
  }

  @override
  Future<List<ProviderListing>> search(String query, {GeoPoint? near, int limit = 30}) async => const [];
}

class _FakeCities implements ServiceCitiesRepository {
  _FakeCities([this.cities = const [_brisbane, _goldCoast]]);

  final List<ServiceCity> cities;

  @override
  Future<List<ServiceCity>> listCities() async => cities;
}

/// A device whose location access and position the test controls.
class _FakeDevice implements DeviceLocation {
  _FakeDevice({this.access_ = LocationAccess.denied, this.position, this.onRequest});

  LocationAccess access_;
  final GeoPoint? position;

  /// What asking for access returns (defaults to the current access).
  final LocationAccess? onRequest;
  int settingsOpened = 0;

  @override
  Future<LocationAccess> access() async => access_;

  @override
  Future<LocationAccess> requestAccess() async => access_ = onRequest ?? access_;

  @override
  Future<GeoPoint?> lastKnown() async => access_ == LocationAccess.granted ? position : null;

  @override
  Future<GeoPoint> current({Duration timeout = const Duration(seconds: 12)}) async =>
      position ?? (throw const LocationUnavailableException('none'));

  @override
  Future<bool> openAppSettings() async {
    settingsOpened++;
    return true;
  }

  @override
  Future<bool> openLocationSettings() async {
    settingsOpened++;
    return true;
  }
}

/// An inbox with fixed contents and no network.
class _FakeInbox extends NotificationsController {
  _FakeInbox(this.items);

  final List<AppNotification> items;

  @override
  Future<NotificationsState> build() async => NotificationsState(items);
}

class _FakeFavourites extends FavouritesController {
  @override
  Future<FavouritesState> build() async => const FavouritesState(providerIds: [], canFavourite: true);
}

/// Serves fixed upcoming bookings.
class _FakeBookings extends BookingListController {
  _FakeBookings(super.key);

  static List<Booking> upcoming = const [];

  @override
  Future<BookingPage> build() async => BookingPage(items: upcoming, hasMore: false);
}

AppNotification _notification(String id, {bool read = false}) => AppNotification(
      id: id,
      recipientId: 'client-1',
      kind: NotificationKind.bookingConfirmed,
      title: 'Booking confirmed',
      body: 'See you soon',
      createdAt: DateTime.utc(2026, 10, 5),
      readAt: read ? DateTime.utc(2026, 10, 5, 1) : null,
    );

Future<List<Override>> _overrides({
  List<AppNotification> inbox = const [],
  ExploreRepository? explore,
  ServiceCitiesRepository? cities,
  DeviceLocation? device,
  Map<String, Object> prefs = const {},
  bool feedNeverLoads = false,
}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final preferences = await SharedPreferences.getInstance();
  const profile = ProfileModel(id: 'client-1', role: UserRole.customer, firstName: 'Priya');
  return [
    sharedPreferencesProvider.overrideWithValue(preferences),
    userProfileProvider.overrideWith(
      (ref) async => AppUserProfile(rawUser: _user, role: UserRole.customer, profile: profile),
    ),
    notificationsProvider.overrideWith(() => _FakeInbox(inbox)),
    favouritesProvider.overrideWith(_FakeFavourites.new),
    bookingListProvider.overrideWith2(_FakeBookings.new),
    deviceLocationProvider.overrideWithValue(device ?? _FakeDevice()),
    exploreRepositoryProvider.overrideWithValue(explore ?? _FakeExplore()),
    serviceCitiesRepositoryProvider.overrideWithValue(cities ?? _FakeCities()),
    if (feedNeverLoads) homeFeedProvider.overrideWith((ref) => Completer<HomeFeed>().future),
  ];
}

void _tallView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1170, 9000);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump();
  }
}

Future<void> _pumpHome(WidgetTester tester, List<Override> overrides) async {
  _tallView(tester);
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
      retry: (_, _) => null,
      child: MaterialApp(theme: AppTheme.lightTheme, home: const HomeScreen()),
    ),
  );
  await _settle(tester);
}

ProviderContainer _container(WidgetTester tester) =>
    ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));

void main() {
  setUp(() => _FakeBookings.upcoming = const []);

  group('header', () {
    test('greeting follows the time of day', () {
      expect(timeOfDayGreeting(DateTime(2026, 10, 26, 7)), 'Good morning');
      expect(timeOfDayGreeting(DateTime(2026, 10, 26, 12)), 'Good afternoon');
      expect(timeOfDayGreeting(DateTime(2026, 10, 26, 19)), 'Good evening');
      expect(timeOfDayGreeting(DateTime(2026, 10, 26, 2)), 'Good evening');
    });

    testWidgets('shows the greeting without the client’s name', (tester) async {
      await _pumpHome(tester, await _overrides(feedNeverLoads: true));
      expect(find.textContaining(RegExp(r'^Good (morning|afternoon|evening)$')), findsOneWidget);
      expect(find.textContaining('Priya'), findsNothing);
      expect(find.textContaining('Welcome'), findsNothing);
    });

    testWidgets('the bell shows how many notifications are unread', (tester) async {
      await _pumpHome(
        tester,
        await _overrides(
          inbox: [_notification('a'), _notification('b'), _notification('c', read: true)],
          feedNeverLoads: true,
        ),
      );
      expect(find.byTooltip('Notifications, 2 unread'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
    });

    testWidgets('the bell has no badge when everything is read', (tester) async {
      await _pumpHome(tester, await _overrides(inbox: [_notification('a', read: true)], feedNeverLoads: true));
      expect(find.byTooltip('Notifications'), findsOneWidget);
    });
  });

  group('choice storage', () {
    test('round-trips current location and cities, and ignores junk', () {
      expect(HomeLocationChoice.decode(const CurrentLocationChoice().encode()), const CurrentLocationChoice());
      expect(HomeLocationChoice.decode(const CityChoice('gc').encode()), const CityChoice('gc'));
      expect(HomeLocationChoice.decode('city:'), isNull);
      expect(HomeLocationChoice.decode('somewhere'), isNull);
      expect(HomeLocationChoice.decode(null), isNull);
    });

    test('the default city is the first one with salons', () {
      expect(defaultServiceCity(const [_brisbane, _goldCoast]), _goldCoast);
      expect(defaultServiceCity(const [_brisbane]), _brisbane);
      expect(defaultServiceCity(const []), isNull);
    });

    test('places coastal regions "on the" and other cities "in"', () {
      ServiceCity named(String name) => ServiceCity(
            id: name,
            name: name,
            state: 'QLD',
            centre: _goldCoast.centre,
            radiusMetres: 1000,
          );
      expect(named('Gold Coast').placePhrase, 'on the Gold Coast');
      expect(named('Sunshine Coast').placePhrase, 'on the Sunshine Coast');
      expect(named('The Central Coast').placePhrase, 'on the Central Coast');
      expect(named('Brisbane').placePhrase, 'in Brisbane');
      expect(named('Coasters Retreat').placePhrase, 'in Coasters Retreat');
    });

    test('parses a city row', () {
      final city = ServiceCity.fromJson({
        'city_id': 'gc',
        'name': ' Gold Coast ',
        'state': 'QLD',
        'latitude': -28.0167,
        'longitude': 153.4,
        'radius_m': 30000,
        'provider_count': 21,
      });
      expect(city.name, 'Gold Coast');
      expect(city.radiusMetres, 30000);
      expect(city.hasProviders, isTrue);
      expect(city.contains(_surfers), isTrue);
      expect(city.contains(_ahmedabad), isFalse);
      expect(
        () => ServiceCity.fromJson({'city_id': 'x', 'name': 'X', 'latitude': 200, 'longitude': 0, 'radius_m': 1000}),
        throwsFormatException,
      );
    });
  });

  group('feed', () {
    testWidgets('shows skeletons instead of a spinner while loading', (tester) async {
      await _pumpHome(tester, await _overrides(feedNeverLoads: true));
      expect(find.byType(NearbyProviderTileSkeleton), findsWidgets);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('with location allowed, lists salons near the client with distances', (tester) async {
      final explore = _FakeExplore();
      await _pumpHome(
        tester,
        await _overrides(explore: explore, device: _FakeDevice(access_: LocationAccess.granted, position: _surfers)),
      );

      expect(find.text('Near you'), findsOneWidget);
      expect(find.text('Current location'), findsOneWidget);
      expect(find.byType(NearbyProviderTile), findsNWidgets(3));
      expect(find.text('1.2 km'), findsOneWidget);
      // The position is coarsened before it leaves the device.
      expect(explore.requests.single.centre, const GeoPoint(latitude: -28.002, longitude: 153.415));
    });

    testWidgets('without location, shows the first city with salons', (tester) async {
      final explore = _FakeExplore();
      await _pumpHome(tester, await _overrides(explore: explore));

      expect(find.text('Salons on the Gold Coast'), findsOneWidget);
      expect(find.text('Gold Coast'), findsOneWidget);
      expect(explore.requests.single, (centre: _goldCoast.centre, radius: _goldCoast.radiusMetres));
      expect(find.text('1.2 km'), findsNothing);
    });

    testWidgets('a saved city wins over the device location', (tester) async {
      final explore = _FakeExplore();
      await _pumpHome(
        tester,
        await _overrides(
          explore: explore,
          device: _FakeDevice(access_: LocationAccess.granted, position: _ahmedabad),
          prefs: {_choiceKey: 'city:gc'},
        ),
      );

      expect(find.text('Salons on the Gold Coast'), findsOneWidget);
      expect(explore.requests.single.centre, _goldCoast.centre);
    });

    testWidgets('shows ratings once reviewed, and no prices or "New" tags', (tester) async {
      await _pumpHome(tester, await _overrides());

      expect(find.text('4.6'), findsOneWidget);
      expect(find.text('Not taking bookings'), findsOneWidget);
      expect(find.text('New'), findsNothing);
      expect(find.textContaining(r'$'), findsNothing);
    });

    testWidgets('with no salons nearby, offers the cities that have salons', (tester) async {
      await _pumpHome(
        tester,
        await _overrides(device: _FakeDevice(access_: LocationAccess.granted, position: _ahmedabad)),
      );

      expect(find.byType(HomeNoSalons), findsOneWidget);
      expect(find.text('No salons near you yet'), findsOneWidget);
      // Brisbane has no salons, so it isn't suggested.
      expect(find.text('Brisbane'), findsNothing);
      expect(find.text('QLD · 21 salons'), findsOneWidget);

      await tester.tap(find.text('Gold Coast'));
      await _settle(tester);

      expect(find.text('Salons on the Gold Coast'), findsOneWidget);
      expect(find.byType(NearbyProviderTile), findsNWidgets(3));
      final preferences = _container(tester).read(sharedPreferencesProvider);
      expect(preferences.getString(_choiceKey), 'city:gc');
    });

    testWidgets('a city with no salons yet says so and suggests another', (tester) async {
      await _pumpHome(tester, await _overrides(prefs: {_choiceKey: 'city:bne'}));

      expect(find.text('No salons in Brisbane yet'), findsOneWidget);
      expect(find.text('QLD · 21 salons'), findsOneWidget);
    });

    testWidgets('falls back to a city when current location is chosen but unavailable', (tester) async {
      await _pumpHome(tester, await _overrides(prefs: {_choiceKey: 'current'}));

      expect(find.text('Salons on the Gold Coast'), findsOneWidget);
      expect(find.textContaining('We couldn’t get your location'), findsOneWidget);
    });

    testWidgets('with no cities and no location, says no salons yet', (tester) async {
      await _pumpHome(tester, await _overrides(cities: _FakeCities(const [])));
      expect(find.text('No salons yet'), findsOneWidget);
      expect(find.textContaining('welcoming new salons'), findsOneWidget);
    });

    testWidgets('a saved city that no longer exists falls back to the default', (tester) async {
      await _pumpHome(tester, await _overrides(prefs: {_choiceKey: 'city:gone'}));
      expect(find.text('Salons on the Gold Coast'), findsOneWidget);
    });

    testWidgets('offers a retry when loading fails', (tester) async {
      final explore = _FakeExplore()..error = Exception('boom');
      await _pumpHome(tester, await _overrides(explore: explore));
      expect(find.text("Couldn't load salons"), findsOneWidget);

      explore.error = null;
      await tester.tap(find.text('Try again'));
      await _settle(tester);
      expect(find.byType(NearbyProviderTile), findsNWidgets(3));
    });

    testWidgets('opens a provider profile from the list', (tester) async {
      _tallView(tester);
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          GoRoute(
            path: AppRoute.publicProviderProfile.path,
            name: AppRoute.publicProviderProfile.name,
            builder: (_, state) => Text('profile ${state.pathParameters['id']}'),
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: await _overrides(explore: _FakeExplore(goldCoast: const [_fresh])),
          retry: (_, _) => null,
          child: MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
        ),
      );
      await _settle(tester);

      await tester.tap(find.byType(NearbyProviderTile));
      await tester.pumpAndSettle();
      expect(find.text('profile p3'), findsOneWidget);
    });
  });

  group('location picker', () {
    Future<void> openPicker(WidgetTester tester) async {
      await tester.tap(find.byType(HomeLocationButton));
      await tester.pumpAndSettle();
      expect(find.text('Choose your location'), findsOneWidget);
    }

    testWidgets('lists cities, with ones without salons coming soon', (tester) async {
      await _pumpHome(tester, await _overrides());
      await openPicker(tester);

      expect(find.text('QLD · Coming soon'), findsOneWidget);
      expect(find.text('QLD · 21 salons'), findsOneWidget);

      // Brisbane can't be picked yet.
      await tester.tap(find.text('Brisbane'));
      await tester.pumpAndSettle();
      expect(find.text('Choose your location'), findsOneWidget);
    });

    testWidgets('picking a city closes the sheet, saves it and shows its salons', (tester) async {
      await _pumpHome(
        tester,
        await _overrides(device: _FakeDevice(access_: LocationAccess.granted, position: _ahmedabad)),
      );
      expect(find.text('No salons near you yet'), findsOneWidget);
      await openPicker(tester);

      await tester.tap(find.descendant(of: find.byType(HomeLocationPickerSheet), matching: find.text('Gold Coast')));
      await tester.pumpAndSettle();

      expect(find.text('Choose your location'), findsNothing);
      expect(find.text('Salons on the Gold Coast'), findsOneWidget);
      expect(_container(tester).read(homeLocationChoiceProvider), const CityChoice('gc'));
    });

    testWidgets('using current location asks for access and switches to near you', (tester) async {
      final device = _FakeDevice(position: _surfers, onRequest: LocationAccess.granted);
      await _pumpHome(tester, await _overrides(device: device));
      expect(find.text('Salons on the Gold Coast'), findsOneWidget);
      await openPicker(tester);

      await tester.tap(find.text('Use my current location'));
      await tester.pumpAndSettle();

      expect(find.text('Choose your location'), findsNothing);
      expect(find.text('Near you'), findsOneWidget);
      expect(find.text('1.2 km'), findsOneWidget);
      expect(_container(tester).read(homeLocationChoiceProvider), const CurrentLocationChoice());
    });

    testWidgets('explains blocked access and links to Settings', (tester) async {
      final device = _FakeDevice(access_: LocationAccess.deniedForever);
      await _pumpHome(tester, await _overrides(device: device));
      await openPicker(tester);

      await tester.tap(find.text('Use my current location'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Location access is off for Myglo'), findsOneWidget);
      await tester.tap(find.text('Open Settings'));
      await tester.pump();
      expect(device.settingsOpened, 1);
      expect(_container(tester).read(homeLocationChoiceProvider), isNull);
    });

    testWidgets('a refused prompt keeps the sheet open with a hint', (tester) async {
      await _pumpHome(tester, await _overrides(device: _FakeDevice(onRequest: LocationAccess.denied)));
      await openPicker(tester);

      await tester.tap(find.text('Use my current location'));
      await tester.pumpAndSettle();

      expect(find.text('Choose your location'), findsOneWidget);
      expect(find.textContaining('Location access wasn’t allowed'), findsOneWidget);
    });
  });

  group('next appointment', () {
    testWidgets('shows the soonest upcoming booking and how many more there are', (tester) async {
      final soon = DateTime.now().toUtc().add(const Duration(days: 3));
      _FakeBookings.upcoming = [
        sampleBooking(id: 'b1', status: BookingStatus.pending, startsAt: soon),
        sampleBooking(id: 'b2', startsAt: soon.add(const Duration(days: 2))),
      ];
      await _pumpHome(tester, await _overrides(feedNeverLoads: true));

      expect(find.byType(NextAppointmentCard), findsOneWidget);
      expect(find.text('Lash lift, Lash tint'), findsOneWidget);
      expect(find.text('Awaiting confirmation'), findsOneWidget);
      expect(find.text('+1 more upcoming'), findsOneWidget);
    });

    testWidgets('is hidden with nothing booked', (tester) async {
      await _pumpHome(tester, await _overrides(feedNeverLoads: true));
      expect(find.byType(NextAppointmentCard), findsNothing);
    });

    test('labels the day in the provider time zone', () {
      // 9:30 am Thu 8 Oct in Brisbane.
      final booking = sampleBooking();
      expect(appointmentDayLabel(booking, DateTime.utc(2026, 10, 7, 20)), 'Today');
      expect(appointmentDayLabel(booking, DateTime.utc(2026, 10, 7, 1)), 'Tomorrow');
      expect(appointmentDayLabel(booking, DateTime.utc(2026, 10, 5, 1)), 'Thu 8 Oct');
      expect(appointmentDayLabel(booking, DateTime.utc(2026, 10, 7, 23, 45)), 'Happening now');
    });
  });
}
