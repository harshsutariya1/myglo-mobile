import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:sentry_flutter/sentry_flutter.dart';

import '../utils/app_logger.dart';
import 'geo_point.dart';

/// Turns a written address into coordinates.
///
/// Screens depend on this app-owned interface rather than a vendor SDK, so the
/// service behind it can change (for example to Google's Geocoding API once
/// Google Maps is integrated, keeping map and search data from one vendor)
/// without touching them.
abstract interface class AddressGeocoder {
  /// The best match for [address], or null when nothing matches it.
  ///
  /// Throws [GeocodingUnavailableException] when the lookup itself couldn't
  /// run (no connection, service unavailable).
  Future<GeoPoint?> locate(String address);
}

/// Turns coordinates back into a readable address, e.g. to suggest a
/// provider's address from where they dropped their map pin.
abstract interface class ReverseGeocoder {
  /// A street address for [point] in Australian style (`1 Cavill Ave,
  /// Surfers Paradise QLD 4217`), or null when nothing useful is known there.
  ///
  /// Throws [GeocodingUnavailableException] when the lookup couldn't run.
  Future<String?> describe(GeoPoint point);
}

/// The geocoding service couldn't be reached or failed unexpectedly.
class GeocodingUnavailableException implements Exception {
  const GeocodingUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'GeocodingUnavailableException: $message';
}

final addressGeocoderProvider = Provider<AddressGeocoder>((ref) => PlatformAddressGeocoder());

final reverseGeocoderProvider = Provider<ReverseGeocoder>((ref) => PlatformAddressGeocoder());

/// Uses the device's built-in geocoder (Apple's on iOS, Google Play services'
/// on Android), biased to Australian results. It's free and needs no key.
///
/// Reverse lookups only ever pre-fill an address the provider then confirms
/// or edits, so the text that's saved and shown is theirs; no geocoder
/// result is drawn on the map itself.
class PlatformAddressGeocoder implements AddressGeocoder, ReverseGeocoder {
  PlatformAddressGeocoder({geocoding.Geocoding? geocoder})
      : _geocoder = geocoder ?? geocoding.Geocoding(locale: const Locale('en', 'AU'));

  final geocoding.Geocoding _geocoder;

  static const Duration _timeout = Duration(seconds: 12);

  @override
  Future<GeoPoint?> locate(String address) async {
    final query = address.trim();
    if (query.isEmpty) return null;
    try {
      final results = await _geocoder.locationFromAddress(query).timeout(_timeout);
      for (final result in results) {
        final point = GeoPoint(latitude: result.latitude, longitude: result.longitude);
        if (point.isValid) return point;
      }
      return null;
    } on PlatformException catch (e) {
      // Both platforms report "no match" as an error; only a network failure
      // (CLError.network, code 2 on iOS) means the lookup couldn't run.
      final details = '${e.details ?? ''} ${e.message ?? ''}';
      if (details.contains('Code=2 ') || details.contains('kCLErrorDomain error 2.')) {
        Sentry.addBreadcrumb(Breadcrumb(category: 'geocoding', message: 'Geocoder offline', level: SentryLevel.warning));
        throw const GeocodingUnavailableException('The address lookup service is unreachable.');
      }
      AppLogger.d('No geocoding match (${e.code})', tag: 'Geocoder');
      return null;
    } on TimeoutException {
      Sentry.addBreadcrumb(Breadcrumb(category: 'geocoding', message: 'Geocoder timed out', level: SentryLevel.warning));
      throw const GeocodingUnavailableException('The address lookup timed out.');
    } catch (e, st) {
      AppLogger.e('Unexpected geocoding failure', tag: 'Geocoder', error: e, stackTrace: st);
      throw GeocodingUnavailableException('$e');
    }
  }

  @override
  Future<String?> describe(GeoPoint point) async {
    if (!point.isValid) return null;
    try {
      final placemarks = await _geocoder.placemarkFromCoordinates(point.latitude, point.longitude).timeout(_timeout);
      for (final placemark in placemarks) {
        final address = AustralianAddress.format(
          subThoroughfare: placemark.subThoroughfare,
          thoroughfare: placemark.thoroughfare,
          street: placemark.street,
          name: placemark.name,
          locality: placemark.locality,
          subLocality: placemark.subLocality,
          administrativeArea: placemark.administrativeArea,
          postalCode: placemark.postalCode,
        );
        if (address != null) return address;
      }
      return null;
    } on PlatformException catch (e) {
      final details = '${e.details ?? ''} ${e.message ?? ''}';
      if (details.contains('Code=2 ') || details.contains('kCLErrorDomain error 2.')) {
        Sentry.addBreadcrumb(
          Breadcrumb(category: 'geocoding', message: 'Reverse geocoder offline', level: SentryLevel.warning),
        );
        throw const GeocodingUnavailableException('The address lookup service is unreachable.');
      }
      AppLogger.d('No address at $point (${e.code})', tag: 'Geocoder');
      return null;
    } on TimeoutException {
      Sentry.addBreadcrumb(
        Breadcrumb(category: 'geocoding', message: 'Reverse geocoder timed out', level: SentryLevel.warning),
      );
      throw const GeocodingUnavailableException('The address lookup timed out.');
    } catch (e, st) {
      AppLogger.e('Unexpected reverse geocoding failure', tag: 'Geocoder', error: e, stackTrace: st);
      throw GeocodingUnavailableException('$e');
    }
  }
}

/// Builds the one-line address Australians write: `1 Cavill Ave, Surfers
/// Paradise QLD 4217`.
abstract final class AustralianAddress {
  static const Map<String, String> _states = {
    'new south wales': 'NSW',
    'victoria': 'VIC',
    'queensland': 'QLD',
    'south australia': 'SA',
    'western australia': 'WA',
    'tasmania': 'TAS',
    'northern territory': 'NT',
    'australian capital territory': 'ACT',
  };

  /// Open Location Codes ("8HQ7+2X") some geocoders return as a street name.
  static final RegExp _plusCode = RegExp(
    r'^[23456789CFGHJMPQRVWX]{2,8}\+[23456789CFGHJMPQRVWX]{0,3}',
    caseSensitive: false,
  );

  /// Null unless there's at least a street or a suburb to show.
  static String? format({
    String? subThoroughfare,
    String? thoroughfare,
    String? street,
    String? name,
    String? locality,
    String? subLocality,
    String? administrativeArea,
    String? postalCode,
  }) {
    String? clean(String? value) {
      final trimmed = value?.trim() ?? '';
      return trimmed.isEmpty || _plusCode.hasMatch(trimmed) ? null : trimmed;
    }

    final number = clean(subThoroughfare);
    final road = clean(thoroughfare);
    final streetLine = road != null ? [?number, road].join(' ') : clean(street) ?? clean(name);
    final suburb = clean(locality) ?? clean(subLocality);
    final state = abbreviateState(administrativeArea);
    final postcode = clean(postalCode);

    final area = [?suburb, ?state, ?postcode].join(' ');
    // A street line that only repeats the suburb (common for parks and
    // beaches) or is just a number (remote areas report the postcode as the
    // place name) adds nothing.
    final streetPart = streetLine != null &&
            streetLine.toLowerCase() != suburb?.toLowerCase() &&
            !RegExp(r'^\d+$').hasMatch(streetLine)
        ? streetLine
        : null;
    final parts = [?streetPart, if (area.isNotEmpty) area];
    if (parts.isEmpty || (streetPart == null && suburb == null)) return null;
    return parts.join(', ');
  }

  /// `Queensland` → `QLD`; already-short or unknown values pass through.
  static String? abbreviateState(String? state) {
    final trimmed = state?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    return _states[trimmed.toLowerCase()] ?? trimmed;
  }
}
