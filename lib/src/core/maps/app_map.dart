import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../location/geo_point.dart';
import '../platform/system_bridge.dart';
import '../theme/app_theme.dart';
import 'google/google_app_map.dart';
import 'map_style.dart';

/// Where a map is looking.
@immutable
class MapCamera {
  const MapCamera({required this.target, required this.zoom});

  final GeoPoint target;
  final double zoom;

  @override
  bool operator ==(Object other) => other is MapCamera && other.target == target && other.zoom == zoom;

  @override
  int get hashCode => Object.hash(target, zoom);

  @override
  String toString() => 'MapCamera($target, zoom $zoom)';
}

/// The rectangle a map is showing.
@immutable
class MapBounds {
  const MapBounds({required this.southwest, required this.northeast});

  final GeoPoint southwest;
  final GeoPoint northeast;

  GeoPoint get center => GeoPoint(
        latitude: (southwest.latitude + northeast.latitude) / 2,
        longitude: (southwest.longitude + northeast.longitude) / 2,
      );

  /// Radius of the smallest circle around [center] that covers these bounds.
  double get coverRadiusMetres => center.distanceKmTo(northeast) * 1000;
}

/// A ready-made marker picture (PNG), rendered at [pixelRatio] so it stays
/// crisp. [key] identifies the picture, so maps only re-upload it when it
/// actually changes.
@immutable
class MarkerImage {
  const MarkerImage({required this.key, required this.png, required this.pixelRatio, required this.anchor});

  final String key;
  final Uint8List png;
  final double pixelRatio;

  /// The point of the picture that sits on the location, in 0–1 fractions
  /// (`Offset(0.5, 1)` is bottom centre).
  final Offset anchor;

  @override
  bool operator ==(Object other) => other is MarkerImage && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// A pin on an [AppMap].
@immutable
class AppMapMarker {
  const AppMapMarker({
    required this.id,
    required this.point,
    required this.image,
    this.onTap,
    this.zIndex = 0,
    this.semanticLabel,
  });

  final String id;
  final GeoPoint point;
  final MarkerImage image;
  final VoidCallback? onTap;

  /// Higher draws on top (e.g. the selected pin).
  final int zIndex;
  final String? semanticLabel;
}

/// Moves a live [AppMap].
abstract interface class AppMapController {
  Future<void> animateTo(GeoPoint target, {double? zoom});

  /// Frames every point, keeping [paddingPx] clear around them.
  Future<void> fitPoints(Iterable<GeoPoint> points, {double paddingPx = 72});

  /// What's on screen right now, or null if the map isn't ready.
  Future<MapBounds?> visibleBounds();
}

/// The app's map. Screens use this instead of a vendor SDK so the map
/// provider can change without touching them (Google Maps for now; a server
/// `map_provider` flag is the planned switch point).
///
/// Shows [MapUnavailableView] when no Maps key was built into the app,
/// instead of a blank or crashing map.
class AppMap extends ConsumerWidget {
  const AppMap({
    super.key,
    required this.initialCamera,
    this.markers = const [],
    this.onCreated,
    this.onCameraMoveStarted,
    this.onCameraMove,
    this.onCameraIdle,
    this.onTap,
    this.showMyLocation = false,
    this.padding = EdgeInsets.zero,
    this.interactive = true,
    this.lite = false,
  });

  final MapCamera initialCamera;
  final List<AppMapMarker> markers;
  final ValueChanged<AppMapController>? onCreated;

  /// The user (or an animation) started moving the map.
  final VoidCallback? onCameraMoveStarted;
  final ValueChanged<MapCamera>? onCameraMove;

  /// The map came to rest, with where it ended up.
  final ValueChanged<MapCamera>? onCameraIdle;
  final ValueChanged<GeoPoint>? onTap;

  /// Draws the blue "you are here" dot. Only works once location access is
  /// granted; pass false until then.
  final bool showMyLocation;

  /// Space covered by overlays (search bar, cards), so the map's centre,
  /// logo and fitted points stay in the visible part.
  final EdgeInsets padding;

  /// False for small previews that just show a place.
  final bool interactive;

  /// A light static rendering for previews (Android lite mode).
  final bool lite;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(mapsAvailableProvider)) {
      AsyncData(value: true) => GoogleAppMap(
          initialCamera: initialCamera,
          markers: markers,
          style: MapStyle.light,
          onCreated: onCreated,
          onCameraMoveStarted: onCameraMoveStarted,
          onCameraMove: onCameraMove,
          onCameraIdle: onCameraIdle,
          onTap: onTap,
          showMyLocation: showMyLocation,
          padding: padding,
          interactive: interactive,
          lite: lite,
        ),
      AsyncLoading() => const ColoredBox(color: MapStyle.landColor),
      _ => const MapUnavailableView(),
    };
  }
}

/// Stand-in for a map when maps can't be shown on this build.
class MapUnavailableView extends StatelessWidget {
  const MapUnavailableView({super.key});

  @override
  Widget build(BuildContext context) {
    final muted = context.colorScheme.onSurface.withValues(alpha: 0.55);
    return ColoredBox(
      color: MapStyle.landColor,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 32, color: muted),
              const SizedBox(height: 8),
              Text(
                'Map unavailable',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
