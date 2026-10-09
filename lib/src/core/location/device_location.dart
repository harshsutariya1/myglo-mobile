import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:sentry_flutter/sentry_flutter.dart';

import '../utils/app_logger.dart';
import 'geo_point.dart';

/// Whether the app may read the device's location right now.
enum LocationAccess {
  granted,

  /// Not asked yet, or refused once: asking again shows the system prompt.
  denied,

  /// Refused for good; only the system settings can change it.
  deniedForever,

  /// Location services are switched off for the whole device.
  serviceDisabled,
}

/// The device couldn't produce a position (timed out, no fix, service error).
class LocationUnavailableException implements Exception {
  const LocationUnavailableException(this.message);

  final String message;

  @override
  String toString() => 'LocationUnavailableException: $message';
}

/// Reads where the device is. Screens use this app-owned interface rather
/// than the plugin, so it can be faked in tests and swapped later.
///
/// Positions are only used on the device (centring a map, sorting by
/// distance) or saved deliberately by a provider as their studio location;
/// a client's position is never stored.
abstract interface class DeviceLocation {
  /// Current access, without prompting.
  Future<LocationAccess> access();

  /// Asks for access if it can still be asked for, and returns the result.
  Future<LocationAccess> requestAccess();

  /// The last position the OS remembers, if any. Fast; may be stale.
  Future<GeoPoint?> lastKnown();

  /// A fresh position. Throws [LocationUnavailableException] if none arrives
  /// within [timeout]. Call only once access is granted.
  Future<GeoPoint> current({Duration timeout});

  Future<bool> openAppSettings();

  Future<bool> openLocationSettings();
}

final deviceLocationProvider = Provider<DeviceLocation>((ref) => GeolocatorDeviceLocation());

/// The signed-in user's approximate position when location access is
/// already granted; null otherwise. Never prompts, so screens can use it to
/// show distances without asking for anything.
final passiveLocationProvider = FutureProvider.autoDispose<GeoPoint?>((ref) async {
  final location = ref.watch(deviceLocationProvider);
  try {
    if (await location.access() != LocationAccess.granted) return null;
    return await location.lastKnown() ?? await location.current(timeout: const Duration(seconds: 6));
  } on LocationUnavailableException {
    return null;
  }
});

class GeolocatorDeviceLocation implements DeviceLocation {
  static const _tag = 'DeviceLocation';

  @override
  Future<LocationAccess> access() async {
    try {
      if (!await geo.Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceDisabled;
      return _map(await geo.Geolocator.checkPermission());
    } catch (e, st) {
      AppLogger.e('Checking location permission failed', tag: _tag, error: e, stackTrace: st);
      return LocationAccess.denied;
    }
  }

  @override
  Future<LocationAccess> requestAccess() async {
    try {
      if (!await geo.Geolocator.isLocationServiceEnabled()) return LocationAccess.serviceDisabled;
      final current = await geo.Geolocator.checkPermission();
      if (current == geo.LocationPermission.deniedForever) return LocationAccess.deniedForever;
      if (current == geo.LocationPermission.whileInUse || current == geo.LocationPermission.always) {
        return LocationAccess.granted;
      }
      return _map(await geo.Geolocator.requestPermission());
    } catch (e, st) {
      // e.g. a second request while the first prompt is still open.
      AppLogger.w('Requesting location permission failed', tag: _tag, error: e, stackTrace: st);
      return LocationAccess.denied;
    }
  }

  @override
  Future<GeoPoint?> lastKnown() async {
    try {
      final position = await geo.Geolocator.getLastKnownPosition();
      if (position == null) return null;
      final point = GeoPoint(latitude: position.latitude, longitude: position.longitude);
      return point.isValid ? point : null;
    } catch (e) {
      AppLogger.d('No last known position: $e', tag: _tag);
      return null;
    }
  }

  @override
  Future<GeoPoint> current({Duration timeout = const Duration(seconds: 12)}) async {
    try {
      final position = await geo.Geolocator.getCurrentPosition(
        locationSettings: geo.LocationSettings(accuracy: geo.LocationAccuracy.high, timeLimit: timeout),
      );
      final point = GeoPoint(latitude: position.latitude, longitude: position.longitude);
      if (!point.isValid) throw const LocationUnavailableException('The device returned an invalid position.');
      return point;
    } on TimeoutException {
      Sentry.addBreadcrumb(Breadcrumb(category: 'location', message: 'Position timed out', level: SentryLevel.warning));
      throw const LocationUnavailableException('Getting a location fix took too long.');
    } on LocationUnavailableException {
      rethrow;
    } catch (e, st) {
      AppLogger.e('Reading the device position failed', tag: _tag, error: e, stackTrace: st);
      throw LocationUnavailableException('$e');
    }
  }

  @override
  Future<bool> openAppSettings() => geo.Geolocator.openAppSettings();

  @override
  Future<bool> openLocationSettings() => geo.Geolocator.openLocationSettings();

  static LocationAccess _map(geo.LocationPermission permission) => switch (permission) {
        geo.LocationPermission.always || geo.LocationPermission.whileInUse => LocationAccess.granted,
        geo.LocationPermission.deniedForever => LocationAccess.deniedForever,
        geo.LocationPermission.denied || geo.LocationPermission.unableToDetermine => LocationAccess.denied,
      };
}
