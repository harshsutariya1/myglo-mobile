import 'dart:math' as math;
import 'dart:ui' show Size;

import '../location/geo_point.dart';

/// Ground metres one logical pixel covers at the equator at zoom 0, for
/// Web Mercator maps drawn with 256-point tiles (Google and most others).
const double _metresPerPointAtZoom0 = 156543.03392;

/// The zoom at which a circle of [radiusMetres] around [centre] just fits in
/// a [viewport] of logical pixels, clamped to [minZoom]–[maxZoom].
///
/// Used to open a map on a whole area (e.g. a city) without first creating
/// the map to measure it.
double zoomToFitRadius({
  required GeoPoint centre,
  required double radiusMetres,
  required Size viewport,
  double minZoom = 3,
  double maxZoom = 18,
}) {
  // Not shortestSide: that ignores the sign, and a viewport squeezed to a
  // negative height (tiny landscape screens) has no room at all.
  final side = math.min(viewport.width, viewport.height);
  if (radiusMetres <= 0 || side <= 0 || !side.isFinite) return maxZoom;
  final latitude = centre.latitude.clamp(-85.0, 85.0) * math.pi / 180;
  final zoom = math.log(_metresPerPointAtZoom0 * math.cos(latitude) * side / (2 * radiusMetres)) / math.ln2;
  return zoom.clamp(minZoom, maxZoom).toDouble();
}
