import 'package:flutter/painting.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/location/address_geocoder.dart';
import 'package:myglo/src/core/location/geo_point.dart';
import 'package:myglo/src/core/maps/app_map.dart';
import 'package:myglo/src/core/maps/map_clustering.dart';
import 'package:myglo/src/core/maps/map_zoom.dart';
import 'package:myglo/src/core/maps/marker_icons.dart';
import 'package:myglo/src/features/shared/authentication/models/profile_model.dart';
import 'package:myglo/src/features/shared/authentication/models/user_role.dart';

const _surfers = GeoPoint(latitude: -28.0023, longitude: 153.4145);
const _broadbeach = GeoPoint(latitude: -28.0333, longitude: 153.4305);
const _burleigh = GeoPoint(latitude: -28.0890, longitude: 153.4520);

void main() {
  group('AustralianAddress', () {
    test('writes number, street, suburb, state and postcode on one line', () {
      expect(
        AustralianAddress.format(
          subThoroughfare: '1',
          thoroughfare: 'Cavill Ave',
          locality: 'Surfers Paradise',
          administrativeArea: 'Queensland',
          postalCode: '4217',
        ),
        '1 Cavill Ave, Surfers Paradise QLD 4217',
      );
    });

    test('keeps a state that is already abbreviated', () {
      expect(
        AustralianAddress.format(thoroughfare: 'Gold Coast Hwy', locality: 'Broadbeach', administrativeArea: 'QLD'),
        'Gold Coast Hwy, Broadbeach QLD',
      );
    });

    test('falls back to the street line, then the name', () {
      expect(
        AustralianAddress.format(street: '12 James St', locality: 'Burleigh Heads', administrativeArea: 'Queensland'),
        '12 James St, Burleigh Heads QLD',
      );
      expect(
        AustralianAddress.format(name: 'Pacific Fair', locality: 'Broadbeach'),
        'Pacific Fair, Broadbeach',
      );
    });

    test('ignores plus codes and street lines that repeat the suburb', () {
      expect(
        AustralianAddress.format(street: '8HQ7+2X', locality: 'Surfers Paradise', administrativeArea: 'Queensland'),
        'Surfers Paradise QLD',
      );
      expect(
        AustralianAddress.format(name: 'Burleigh Heads', locality: 'Burleigh Heads', postalCode: '4220'),
        'Burleigh Heads 4220',
      );
    });

    test('drops a bare number standing in for the street', () {
      expect(
        AustralianAddress.format(name: '0872', locality: 'Ghan', administrativeArea: 'NT', postalCode: '0872'),
        'Ghan NT 0872',
      );
    });

    test('returns null when there is neither a street nor a suburb', () {
      expect(AustralianAddress.format(administrativeArea: 'Queensland', postalCode: '4217'), isNull);
      expect(AustralianAddress.format(), isNull);
    });

    test('abbreviates every state and territory', () {
      expect(AustralianAddress.abbreviateState('New South Wales'), 'NSW');
      expect(AustralianAddress.abbreviateState('australian capital territory'), 'ACT');
      expect(AustralianAddress.abbreviateState(' Victoria '), 'VIC');
      expect(AustralianAddress.abbreviateState(''), isNull);
    });
  });

  group('GeoPoint', () {
    test('coarse() rounds to about 100 m', () {
      expect(
        const GeoPoint(latitude: -28.00234567, longitude: 153.41456789).coarse(),
        const GeoPoint(latitude: -28.002, longitude: 153.415),
      );
    });

    test('distanceKmTo() measures great-circle distance', () {
      expect(_surfers.distanceKmTo(_surfers), 0);
      expect(_surfers.distanceKmTo(_burleigh), closeTo(10.4, 0.3));
      expect(_surfers.distanceKmTo(_broadbeach), _broadbeach.distanceKmTo(_surfers));
    });

    test('a profile exposes its saved location as a point', () {
      const profile = ProfileModel(
        id: 'p',
        role: UserRole.provider,
        coordinates: LocationCoordinates(type: 'Point', coordinates: [153.4145, -28.0023]),
      );
      expect(profile.location, _surfers);
      expect(const ProfileModel(id: 'c', role: UserRole.customer).location, isNull);
    });
  });

  group('MapBounds', () {
    test('centre and covering radius', () {
      const bounds = MapBounds(
        southwest: GeoPoint(latitude: -28.1, longitude: 153.3),
        northeast: GeoPoint(latitude: -27.9, longitude: 153.5),
      );
      expect(bounds.center, const GeoPoint(latitude: -28.0, longitude: 153.4));
      expect(bounds.coverRadiusMetres, closeTo(14700, 400));
    });
  });

  group('clusterByScreenDistance', () {
    final points = [_surfers, _broadbeach, _burleigh];

    test('groups nearby pins when zoomed out', () {
      final clusters = clusterByScreenDistance(points, (point) => point, zoom: 9);
      expect(clusters, hasLength(1));
      expect(clusters.single.items, points);
      expect(clusters.single.center.latitude, closeTo(-28.0415, 0.001));
    });

    test('splits them apart when zoomed in', () {
      final clusters = clusterByScreenDistance(points, (point) => point, zoom: 14);
      expect(clusters, hasLength(3));
      expect(clusters.every((cluster) => cluster.isSingle), isTrue);
      expect([for (final cluster in clusters) cluster.items.single], points);
    });

    test('a middle zoom groups only the close pair', () {
      // About 5 km per 52 px here: Surfers–Broadbeach (3.8 km) joins up,
      // Burleigh (10 km away) stays apart.
      final clusters = clusterByScreenDistance(points, (point) => point, zoom: 10.5);
      expect(clusters.map((cluster) => cluster.items.length), [2, 1]);
      expect(clusters.first.items, [_surfers, _broadbeach]);
    });

    test('handles no pins', () {
      expect(clusterByScreenDistance(<GeoPoint>[], (point) => point, zoom: 12), isEmpty);
    });
  });

  group('zoomToFitRadius', () {
    const phone = Size(363, 520);

    test('fits a whole city on a phone at a regional zoom', () {
      final zoom = zoomToFitRadius(centre: _surfers, radiusMetres: 30000, viewport: phone);
      expect(zoom, closeTo(9.7, 0.2));
    });

    test('a smaller area zooms further in', () {
      final city = zoomToFitRadius(centre: _surfers, radiusMetres: 30000, viewport: phone);
      final suburb = zoomToFitRadius(centre: _surfers, radiusMetres: 3000, viewport: phone);
      expect(suburb - city, closeTo(3.32, 0.01)); // log2(10)
    });

    test('stays within its limits, including for empty viewports', () {
      expect(zoomToFitRadius(centre: _surfers, radiusMetres: 10, viewport: phone, maxZoom: 13.5), 13.5);
      expect(zoomToFitRadius(centre: _surfers, radiusMetres: 1e9, viewport: phone, minZoom: 3), 3);
      expect(zoomToFitRadius(centre: _surfers, radiusMetres: 30000, viewport: const Size(363, -10), maxZoom: 12), 12);
    });
  });

  group('markers', () {
    test('initials come from the first two words', () {
      expect(markerInitials('Glow Studio'), 'GS');
      expect(markerInitials('lash'), 'LA');
      expect(markerInitials('  '), 'M');
    });

    test('pin specs that look the same share a picture key', () {
      const a = ProviderPinSpec(tone: PinTone.selected);
      const b = ProviderPinSpec(tone: PinTone.selected);
      const c = ProviderPinSpec();
      const d = ProviderPinSpec(approximate: true);
      expect(a, b);
      expect(a.key, b.key);
      expect(a.key, isNot(c.key));
      expect(c.key, isNot(d.key));
    });

    test('there is a small fixed set of provider pins', () {
      expect(ProviderPinSpec.all, hasLength(PinTone.values.length * 2));
      expect(ProviderPinSpec.all.map((spec) => spec.key).toSet(), hasLength(ProviderPinSpec.all.length));
    });

    test('one icon factory is shared per pixel ratio', () {
      expect(identical(MarkerIconFactory(pixelRatio: 3), MarkerIconFactory(pixelRatio: 3)), isTrue);
      expect(identical(MarkerIconFactory(pixelRatio: 3), MarkerIconFactory(pixelRatio: 2)), isFalse);
    });

    testWidgets('warming up draws every pin once and reuses it', (tester) async {
      final icons = MarkerIconFactory(pixelRatio: 2.5);
      await tester.runAsync(icons.warmUp);

      for (final spec in ProviderPinSpec.all) {
        final image = icons.cached(spec.key);
        expect(image, isNotNull, reason: spec.key);
        expect(image!.png, isNotEmpty);
        expect(image.anchor.dy, inInclusiveRange(0.9, 1.0));
      }
      final first = icons.cached(const ProviderPinSpec().key);
      final again = await tester.runAsync(() => icons.providerPin(const ProviderPinSpec()));
      expect(identical(first, again), isTrue);
    });
  });
}
