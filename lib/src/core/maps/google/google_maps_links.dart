import '../../location/geo_point.dart';

/// Links that open a place in Google Maps, outside the app
/// (https://developers.google.com/maps/documentation/urls/get-started).
abstract final class GoogleMapsLinks {
  /// The Google Maps app on Android.
  static const String androidPackage = 'com.google.android.apps.maps';

  /// A pin on [point] if there is one, otherwise a search for [address].
  /// Null when there's nothing to show.
  static ({Uri web, Uri iosApp})? place({GeoPoint? point, String? address}) {
    final query = _query(point, address);
    if (query == null) return null;
    return (
      // Opens the Google Maps app on Android (and in the browser elsewhere).
      web: Uri.https('www.google.com', '/maps/search/', {'api': '1', 'query': query}),
      iosApp: Uri(scheme: 'comgooglemaps', host: '', queryParameters: {'q': query}),
    );
  }

  static String? _query(GeoPoint? point, String? address) {
    if (point != null && point.isValid) {
      return '${point.latitude.toStringAsFixed(6)},${point.longitude.toStringAsFixed(6)}';
    }
    final text = address?.trim() ?? '';
    return text.isEmpty ? null : text;
  }
}
