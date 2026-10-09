import 'dart:ui' show Color;

/// The Myglo look for maps: warm, quiet base colours that let the pink
/// provider pins stand out, with businesses' own map icons hidden so other
/// salons don't compete with Myglo listings.
abstract final class MapStyle {
  /// Base land colour, also used behind a map while it loads.
  static const Color landColor = Color(0xFFF6F1EE);

  /// Google Maps JSON style.
  static const String light = '''
[
  {"elementType": "geometry", "stylers": [{"color": "#f6f1ee"}]},
  {"elementType": "labels.text.fill", "stylers": [{"color": "#6f6060"}]},
  {"elementType": "labels.text.stroke", "stylers": [{"color": "#ffffff"}, {"weight": 3}]},
  {"featureType": "administrative", "elementType": "geometry.stroke", "stylers": [{"color": "#e3d6d1"}]},
  {"featureType": "administrative.land_parcel", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi.business", "stylers": [{"visibility": "off"}]},
  {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#9a8a8a"}]},
  {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#dfecd9"}]},
  {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#ffffff"}]},
  {"featureType": "road", "elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
  {"featureType": "road.arterial", "elementType": "labels.text.fill", "stylers": [{"color": "#8c7b7b"}]},
  {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#fde2d6"}]},
  {"featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [{"color": "#f6cdbd"}]},
  {"featureType": "road.local", "elementType": "labels.text.fill", "stylers": [{"color": "#a39494"}]},
  {"featureType": "transit", "stylers": [{"visibility": "off"}]},
  {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#cfe4f0"}]},
  {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#7c98a8"}]}
]
''';
}
