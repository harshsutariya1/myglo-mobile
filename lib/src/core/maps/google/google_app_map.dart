import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../location/geo_point.dart';
import '../../utils/app_logger.dart';
import '../app_map.dart';

/// [AppMap] drawn with the Google Maps SDK. The only place in the app that
/// talks to it.
class GoogleAppMap extends StatefulWidget {
  const GoogleAppMap({
    super.key,
    required this.initialCamera,
    required this.markers,
    required this.style,
    required this.onCreated,
    required this.onCameraMoveStarted,
    required this.onCameraMove,
    required this.onCameraIdle,
    required this.onTap,
    required this.showMyLocation,
    required this.padding,
    required this.interactive,
    required this.lite,
  });

  final MapCamera initialCamera;
  final List<AppMapMarker> markers;
  final String style;
  final ValueChanged<AppMapController>? onCreated;
  final VoidCallback? onCameraMoveStarted;
  final ValueChanged<MapCamera>? onCameraMove;
  final ValueChanged<MapCamera>? onCameraIdle;
  final ValueChanged<GeoPoint>? onTap;
  final bool showMyLocation;
  final EdgeInsets padding;
  final bool interactive;
  final bool lite;

  @override
  State<GoogleAppMap> createState() => _GoogleAppMapState();
}

class _GoogleAppMapState extends State<GoogleAppMap> implements AppMapController {
  static const _tag = 'GoogleAppMap';

  GoogleMapController? _controller;
  late MapCamera _camera = widget.initialCamera;

  /// Uploaded marker pictures by [MarkerImage.key], so an unchanged pin keeps
  /// the same descriptor and the SDK doesn't redraw it.
  final Map<String, BitmapDescriptor> _icons = {};

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  static LatLng _latLng(GeoPoint point) => LatLng(point.latitude, point.longitude);

  static GeoPoint _point(LatLng latLng) => GeoPoint(latitude: latLng.latitude, longitude: latLng.longitude);

  Set<Marker> _markers() {
    final used = <String>{};
    final markers = <Marker>{};
    for (final marker in widget.markers) {
      final image = marker.image;
      used.add(image.key);
      final icon = _icons.putIfAbsent(
        image.key,
        () => BitmapDescriptor.bytes(image.png, imagePixelRatio: image.pixelRatio),
      );
      markers.add(Marker(
        markerId: MarkerId(marker.id),
        position: _latLng(marker.point),
        icon: icon,
        anchor: image.anchor,
        zIndexInt: marker.zIndex,
        consumeTapEvents: true,
        onTap: marker.onTap,
        infoWindow: InfoWindow.noText,
      ));
    }
    _icons.removeWhere((key, _) => !used.contains(key));
    return markers;
  }

  @override
  Future<void> animateTo(GeoPoint target, {double? zoom}) async {
    final controller = _controller;
    if (controller == null || !target.isValid) return;
    await _guard('animateTo', () => controller.animateCamera(
          zoom == null ? CameraUpdate.newLatLng(_latLng(target)) : CameraUpdate.newLatLngZoom(_latLng(target), zoom),
        ));
  }

  @override
  Future<void> fitPoints(Iterable<GeoPoint> points, {double paddingPx = 72}) async {
    final controller = _controller;
    final valid = points.where((point) => point.isValid).toList();
    if (controller == null || valid.isEmpty) return;
    if (valid.length == 1) return animateTo(valid.single, zoom: 15);

    var south = valid.first.latitude, north = south, west = valid.first.longitude, east = west;
    for (final point in valid.skip(1)) {
      south = point.latitude < south ? point.latitude : south;
      north = point.latitude > north ? point.latitude : north;
      west = point.longitude < west ? point.longitude : west;
      east = point.longitude > east ? point.longitude : east;
    }
    final bounds = LatLngBounds(southwest: LatLng(south, west), northeast: LatLng(north, east));
    await _guard('fitPoints', () => controller.animateCamera(CameraUpdate.newLatLngBounds(bounds, paddingPx)));
  }

  @override
  Future<MapBounds?> visibleBounds() async {
    final controller = _controller;
    if (controller == null) return null;
    try {
      final region = await controller.getVisibleRegion();
      return MapBounds(southwest: _point(region.southwest), northeast: _point(region.northeast));
    } catch (e, st) {
      AppLogger.w('Reading the visible region failed', tag: _tag, error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> _guard(String action, Future<void> Function() run) async {
    try {
      await run();
    } on PlatformException catch (e, st) {
      // e.g. a camera update before the map has been laid out.
      AppLogger.w('Map $action failed', tag: _tag, error: e, stackTrace: st);
    } catch (e, st) {
      AppLogger.e('Map $action failed', tag: _tag, error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lite = widget.lite && defaultTargetPlatform == TargetPlatform.android;
    final map = GoogleMap(
      initialCameraPosition: CameraPosition(target: _latLng(widget.initialCamera.target), zoom: widget.initialCamera.zoom),
      style: widget.style,
      markers: _markers(),
      padding: widget.padding,
      myLocationEnabled: widget.showMyLocation,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      mapToolbarEnabled: false,
      compassEnabled: false,
      rotateGesturesEnabled: false,
      tiltGesturesEnabled: false,
      indoorViewEnabled: false,
      buildingsEnabled: true,
      trafficEnabled: false,
      liteModeEnabled: lite,
      scrollGesturesEnabled: widget.interactive,
      zoomGesturesEnabled: widget.interactive,
      onMapCreated: (controller) {
        _controller = controller;
        widget.onCreated?.call(this);
      },
      onCameraMoveStarted: widget.onCameraMoveStarted,
      onCameraMove: (position) {
        _camera = MapCamera(target: _point(position.target), zoom: position.zoom);
        widget.onCameraMove?.call(_camera);
      },
      onCameraIdle: () => widget.onCameraIdle?.call(_camera),
      onTap: widget.onTap == null ? null : (latLng) => widget.onTap!(_point(latLng)),
    );
    // Previews pass taps through to whatever they sit in (e.g. a card).
    return widget.interactive ? map : IgnorePointer(child: map);
  }
}
