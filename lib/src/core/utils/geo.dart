import 'dart:math' as math;

/// Great-circle distance helpers for GeoJSON point coordinates.
class Geo {
  Geo._();

  static const double _earthRadiusKm = 6371.0088;

  /// Distance in kilometres between two GeoJSON points, or `null` when either
  /// point is missing or malformed.
  ///
  /// GeoJSON orders coordinates as `[longitude, latitude]`.
  static double? distanceKm(List<double>? a, List<double>? b) {
    final from = _latLng(a);
    final to = _latLng(b);
    if (from == null || to == null) return null;

    final dLat = _rad(to.lat - from.lat);
    final dLng = _rad(to.lng - from.lng);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(from.lat)) * math.cos(_rad(to.lat)) * math.pow(math.sin(dLng / 2), 2);
    return 2 * _earthRadiusKm * math.asin(math.min(1, math.sqrt(h)));
  }

  static ({double lat, double lng})? _latLng(List<double>? point) {
    if (point == null || point.length < 2) return null;
    final lng = point[0];
    final lat = point[1];
    if (lat.isNaN || lng.isNaN || lat.abs() > 90 || lng.abs() > 180) return null;
    return (lat: lat, lng: lng);
  }

  static double _rad(double degrees) => degrees * math.pi / 180;
}
