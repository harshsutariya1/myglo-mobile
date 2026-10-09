import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:myglo/src/core/location/geo_point.dart';
import 'package:myglo/src/features/customers/explore/controllers/map_providers_controller.dart';
import 'package:myglo/src/features/customers/explore/models/provider_listing.dart';
import 'package:myglo/src/features/customers/explore/views/widgets/listing_widgets.dart';

void main() {
  group('ProviderListing.fromJson', () {
    test('reads a search row', () {
      final listing = ProviderListing.fromJson({
        'provider_id': 'p1',
        'provider_name': ' Glow Studio ',
        'profile_pic': 'https://img/p.jpg',
        'cover_photo': null,
        'address_text': '1 Cavill Ave, Surfers Paradise QLD',
        'approximate_location': false,
        'distance_km': 2.4,
        'categories': ['Nails', 'Hair', ' '],
        'service_count': 6,
        'min_price': 35.5,
        'matched_services': [
          {'id': 's1', 'name': 'Gel nails', 'category': 'Nails', 'price': 45, 'duration_minutes': 60},
        ],
        'accepts_bookings': true,
        'offers_studio': true,
        'offers_mobile': false,
      });

      expect(listing.id, 'p1');
      expect(listing.name, 'Glow Studio');
      expect(listing.point, isNull);
      expect(listing.distanceKm, 2.4);
      expect(listing.categories, ['Hair', 'Nails']);
      expect(listing.minPrice, 35.5);
      expect(listing.matchedServices.single.name, 'Gel nails');
      expect(listing.matchedServices.single.price, 45);
      expect(listing.imageUrl, 'https://img/p.jpg');
      expect(listing.mobileOnly, isFalse);
    });

    test('reads a map row for a mobile-only provider', () {
      final listing = ProviderListing.fromJson({
        'provider_id': 'p2',
        'provider_name': null,
        'cover_photo': 'https://img/c.jpg',
        'profile_pic': 'https://img/p.jpg',
        'address_text': null,
        'latitude': -28.0,
        'longitude': 153.43,
        'approximate_location': true,
        'categories': null,
        'service_count': 0,
        'min_price': null,
        'accepts_bookings': false,
        'offers_studio': false,
        'offers_mobile': true,
      });

      expect(listing.name, 'Provider');
      expect(listing.point, const GeoPoint(latitude: -28.0, longitude: 153.43));
      expect(listing.approximateLocation, isTrue);
      expect(listing.mobileOnly, isTrue);
      expect(listing.imageUrl, 'https://img/c.jpg');
      expect(listing.acceptsBookings, isFalse);
      expect(listingLocationLine(listing), 'Comes to you');
      expect(listingCategoryLine(listing), isNull);
    });

    test('distance can be measured on the device', () {
      const listing = ProviderListing(id: 'p', name: 'P', point: GeoPoint(latitude: -28.0, longitude: 153.43));
      final measured = listing.withDistanceFrom(const GeoPoint(latitude: -28.0, longitude: 153.43));
      expect(measured.distanceKm, 0);
      expect(listing.withDistanceFrom(null).distanceKm, isNull);
    });
  });

  group('listing text', () {
    test('category line caps how many it shows', () {
      const listing = ProviderListing(id: 'p', name: 'P', categories: ['Brows', 'Hair', 'Lashes', 'Nails']);
      expect(listingCategoryLine(listing), 'Brows · Hair · Lashes +1');
    });

    test('highlightMatches marks every word, ignoring case', () {
      const bold = TextStyle(fontWeight: FontWeight.bold);
      final spans = highlightMatches('Gel Nails & gel toes', ['gel', 'nail'], highlight: bold);
      expect(spans.map((span) => span.text).join(), 'Gel Nails & gel toes');
      expect([for (final span in spans) if (span.style == bold) span.text], ['Gel', 'Nail', 'gel']);
    });

    test('highlightMatches with nothing to find returns the text', () {
      final spans = highlightMatches('Glow', const [], highlight: const TextStyle());
      expect(spans.single.text, 'Glow');
    });
  });

  group('LoadedArea', () {
    const center = GeoPoint(latitude: -28.0, longitude: 153.4);

    test('covers circles inside it only', () {
      const area = LoadedArea(center, 10000);
      expect(area.covers(center, 5000), isTrue);
      expect(area.covers(const GeoPoint(latitude: -28.02, longitude: 153.4), 5000), isTrue);
      expect(area.covers(center, 12000), isFalse);
      expect(area.covers(const GeoPoint(latitude: -28.1, longitude: 153.4), 5000), isFalse);
    });
  });
}
