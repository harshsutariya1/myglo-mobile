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

/// The geocoding service couldn't be reached or failed unexpectedly.
class GeocodingUnavailableException implements Exception {
  const GeocodingUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'GeocodingUnavailableException: $message';
}

final addressGeocoderProvider = Provider<AddressGeocoder>((ref) => PlatformAddressGeocoder());

/// Uses the device's built-in geocoder (Apple's on iOS, Google Play services'
/// on Android), biased to Australian results.
class PlatformAddressGeocoder implements AddressGeocoder {
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
}
