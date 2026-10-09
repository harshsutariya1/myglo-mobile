import 'dart:math' as math;

import '../location/geo_point.dart';

/// Pins close enough together on screen to be drawn as one bubble.
class MapCluster<T> {
  const MapCluster(this.items, this.center);

  final List<T> items;

  /// The middle of the grouped pins.
  final GeoPoint center;

  bool get isSingle => items.length == 1;
}

/// Groups [items] whose pins would sit within [radiusPx] logical pixels of
/// each other at [zoom], so crowded areas show a count instead of a pile of
/// overlapping pins. Zooming in splits clusters apart.
///
/// Greedy and order-preserving: each cluster starts from the first item not
/// yet placed (pass the most important first) and takes everything near it.
/// Fine for the few hundred pins one map area holds.
List<MapCluster<T>> clusterByScreenDistance<T>(
  List<T> items,
  GeoPoint Function(T item) pointOf, {
  required double zoom,
  double radiusPx = 52,
}) {
  final scale = 256 * math.pow(2, zoom).toDouble();
  final pixels = [for (final item in items) _project(pointOf(item), scale)];
  final placed = List<bool>.filled(items.length, false);
  final clusters = <MapCluster<T>>[];
  final radiusSquared = radiusPx * radiusPx;

  for (var i = 0; i < items.length; i++) {
    if (placed[i]) continue;
    placed[i] = true;
    final members = <int>[i];
    for (var j = i + 1; j < items.length; j++) {
      if (placed[j]) continue;
      final dx = pixels[i].x - pixels[j].x;
      final dy = pixels[i].y - pixels[j].y;
      if (dx * dx + dy * dy <= radiusSquared) {
        placed[j] = true;
        members.add(j);
      }
    }
    var latitude = 0.0, longitude = 0.0;
    for (final index in members) {
      final point = pointOf(items[index]);
      latitude += point.latitude;
      longitude += point.longitude;
    }
    clusters.add(MapCluster(
      [for (final index in members) items[index]],
      GeoPoint(latitude: latitude / members.length, longitude: longitude / members.length),
    ));
  }
  return clusters;
}

/// Web Mercator world pixel coordinates at a zoom with [scale] = 256·2^zoom,
/// the projection Google (and most) map tiles use.
math.Point<double> _project(GeoPoint point, double scale) {
  final sinLatitude = math.sin(point.latitude * math.pi / 180).clamp(-0.9999, 0.9999);
  final x = (point.longitude + 180) / 360 * scale;
  final y = (0.5 - math.log((1 + sinLatitude) / (1 - sinLatitude)) / (4 * math.pi)) * scale;
  return math.Point(x, y);
}
