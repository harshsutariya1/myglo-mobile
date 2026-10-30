import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/config/app_config.dart';
import 'package:myglo/src/core/location/device_location.dart';
import 'package:myglo/src/core/location/geo_point.dart';
import 'package:myglo/src/core/platform/system_bridge.dart';
import 'package:myglo/src/core/theme/app_theme.dart';
import 'package:myglo/src/features/customers/explore/models/explore_repository.dart';
import 'package:myglo/src/features/customers/explore/models/provider_listing.dart';
import 'package:myglo/src/features/customers/explore/views/providers_map_screen.dart';
import 'package:myglo/src/features/customers/home/controllers/home_controller.dart';
import 'package:myglo/src/features/customers/home/models/service_city.dart';

const _brisbane = ServiceCity(
  id: 'bne',
  name: 'Brisbane',
  state: 'QLD',
  centre: GeoPoint(latitude: -27.4698, longitude: 153.0251),
  radiusMetres: 25000,
  providerCount: 4,
);

const _surfers = GeoPoint(latitude: -28.002, longitude: 153.415);

class _FakeExplore implements ExploreRepository {
  final requests = <({GeoPoint centre, double radius})>[];

  @override
  Future<List<ProviderListing>> providersAround(GeoPoint center, {required double radiusMetres, int limit = 200}) async {
    requests.add((centre: center, radius: radiusMetres));
    return const [];
  }

  @override
  Future<List<ProviderListing>> search(String query, {GeoPoint? near, int limit = 30}) async => const [];
}

/// Location access is off; counts how often the map asks for it.
class _FakeDevice implements DeviceLocation {
  int requests = 0;

  @override
  Future<LocationAccess> access() async => LocationAccess.denied;

  @override
  Future<LocationAccess> requestAccess() async {
    requests++;
    return LocationAccess.denied;
  }

  @override
  Future<GeoPoint?> lastKnown() async => null;

  @override
  Future<GeoPoint> current({Duration timeout = const Duration(seconds: 12)}) =>
      throw const LocationUnavailableException('none');

  @override
  Future<bool> openAppSettings() async => true;

  @override
  Future<bool> openLocationSettings() async => true;
}

Future<void> _pumpMap(
  WidgetTester tester, {
  required _FakeExplore explore,
  required _FakeDevice device,
  required Override area,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // No Maps key in tests: the screen shows its stand-in and still loads.
        mapsAvailableProvider.overrideWith((ref) async => false),
        exploreRepositoryProvider.overrideWithValue(explore),
        deviceLocationProvider.overrideWithValue(device),
        area,
      ],
      retry: (_, _) => null,
      child: MaterialApp(theme: AppTheme.lightTheme, home: const ProvidersMapScreen()),
    ),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump();
  }
}

void main() {
  testWidgets('opens on the city chosen on home, without asking for location', (tester) async {
    final explore = _FakeExplore();
    final device = _FakeDevice();
    await _pumpMap(
      tester,
      explore: explore,
      device: device,
      area: homeAreaProvider.overrideWith((ref) async => const HomeArea(place: CityPlace(_brisbane))),
    );

    expect(explore.requests.first.centre, _brisbane.centre);
    expect(explore.requests.first.radius, greaterThanOrEqualTo(_brisbane.radiusMetres));
    expect(device.requests, 0);
  });

  testWidgets('around the client, starts where home placed them and asks for location', (tester) async {
    final explore = _FakeExplore();
    final device = _FakeDevice();
    await _pumpMap(
      tester,
      explore: explore,
      device: device,
      area: homeAreaProvider.overrideWith(
        (ref) async => const HomeArea(place: NearDevicePlace(), origin: _surfers),
      ),
    );

    expect(explore.requests.first.centre, _surfers);
    expect(device.requests, 1);
  });

  testWidgets('a city shown only because location was unavailable still asks for it', (tester) async {
    final device = _FakeDevice();
    await _pumpMap(
      tester,
      explore: _FakeExplore(),
      device: device,
      area: homeAreaProvider.overrideWith(
        (ref) async => const HomeArea(place: CityPlace(_brisbane), locationUnavailable: true),
      ),
    );

    expect(device.requests, 1);
  });

  testWidgets('falls back to the default view if home never works out its area', (tester) async {
    final explore = _FakeExplore();
    await _pumpMap(
      tester,
      explore: explore,
      device: _FakeDevice(),
      area: homeAreaProvider.overrideWith((ref) => Completer<HomeArea>().future),
    );
    expect(explore.requests, isEmpty);

    await tester.pump(const Duration(seconds: 5));
    await tester.pump();

    expect(explore.requests.single.centre, AppConfig.mapDefaultCenter);
  });
}
