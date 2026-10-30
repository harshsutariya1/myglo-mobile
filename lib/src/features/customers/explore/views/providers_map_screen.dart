import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/location/device_location.dart';
import '../../../../core/location/geo_point.dart';
import '../../../../core/maps/app_map.dart';
import '../../../../core/maps/map_clustering.dart';
import '../../../../core/maps/map_zoom.dart';
import '../../../../core/maps/marker_icons.dart';
import '../../../../core/routing/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/network_error.dart';
import '../../../../core/widgets/snackbar_utils.dart';
import '../../home/controllers/home_controller.dart';
import '../controllers/map_providers_controller.dart';
import '../models/provider_listing.dart';
import 'provider_search_screen.dart' show SearchPill;
import 'widgets/map_provider_card.dart';

/// Providers on a map for clients: simple brand pins (grouped into bubbles where
/// they crowd together), a swipeable card for each along the bottom, and a
/// "near me" button. Moving the map loads whatever is in view.
///
/// Opens on the area the client picked on the home screen: the whole of a
/// chosen city, or around them when they chose their current location.
class ProvidersMapScreen extends ConsumerStatefulWidget {
  const ProvidersMapScreen({super.key});

  @override
  ConsumerState<ProvidersMapScreen> createState() => _ProvidersMapScreenState();
}

class _ProvidersMapScreenState extends ConsumerState<ProvidersMapScreen> {
  static const double _carouselHeight = MapProviderCard.height + 12;

  /// Height of the back button and search bar over the top of the map.
  static const double _topBarHeight = 64;

  /// How long to wait for the home screen's area before opening on the
  /// default view instead.
  static const Duration _startAreaTimeout = Duration(seconds: 4);

  AppMapController? _map;
  MarkerIconFactory? _icons;
  MapCamera _camera = const MapCamera(target: AppConfig.mapDefaultCenter, zoom: AppConfig.mapDefaultZoom);

  /// Keeps the home area alive (and waits for it) until the map has opened.
  ProviderSubscription<AsyncValue<HomeArea>>? _homeArea;
  Timer? _startTimeout;
  bool _started = false;

  /// Where the client is, once they've allowed location. Only used here.
  GeoPoint? _userPoint;
  bool _locationGranted = false;
  bool _locating = false;

  /// The user has moved the map themselves, so a late location fix
  /// shouldn't yank it away.
  bool _userMovedMap = false;

  List<ProviderListing> _listings = const [];
  List<AppMapMarker> _markers = const [];
  String? _selectedId;
  double _clusteredAtZoom = -1;
  int _markerSequence = 0;

  final PageController _pages = PageController(viewportFraction: 0.9);

  /// Set while the carousel is being moved by code, so it doesn't reselect.
  bool _syncingPage = false;

  @override
  void initState() {
    super.initState();
    // Home is normally underneath and already knows its area (picked up in
    // didChangeDependencies); otherwise wait for it, but not for long.
    _homeArea = ref.listenManual(homeAreaProvider, (_, next) {
      if (!next.isLoading) _start(next.value, rebuild: true);
    });
    _startTimeout = Timer(_startAreaTimeout, () => _start(null, rebuild: true));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      final area = ref.read(homeAreaProvider);
      if (!area.isLoading) _start(area.value, rebuild: false);
    }
    final ratio = MediaQuery.devicePixelRatioOf(context);
    if (_icons?.pixelRatio != ratio) {
      final icons = _icons = MarkerIconFactory(pixelRatio: ratio);
      // Draw the pins while the first providers load.
      unawaited(icons.warmUp());
      _clusteredAtZoom = -1;
      unawaited(_rebuildMarkers());
    }
  }

  @override
  void dispose() {
    _startTimeout?.cancel();
    _homeArea?.close();
    _pages.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Start
  // ---------------------------------------------------------------------------

  /// Opens the map on the home screen's [area] (null: the default view),
  /// then loads its providers and sets up location. Runs once.
  ///
  /// [rebuild] is false when called before the first build, where the new
  /// camera is picked up anyway.
  void _start(HomeArea? area, {required bool rebuild}) {
    if (_started || !mounted) return;
    _started = true;
    _startTimeout?.cancel();
    _homeArea?.close();
    _homeArea = null;

    final city = area?.city;
    final origin = area?.origin;
    final camera = switch ((city, origin)) {
      (final city?, _) => MapCamera(
          target: city.centre,
          zoom: zoomToFitRadius(
            centre: city.centre,
            radiusMetres: city.radiusMetres,
            viewport: _visibleMapSize(),
            maxZoom: AppConfig.mapNearbyZoom,
          ),
        ),
      (_, final origin?) when origin.isInAustralia => MapCamera(target: origin, zoom: AppConfig.mapNearbyZoom),
      _ => null,
    };
    // A chosen city, rather than around the client (including a city shown
    // only because their location wasn't available).
    final browsingCity = city != null && !(area?.locationUnavailable ?? false);

    if (camera != null && !_userMovedMap) {
      _camera = camera;
      unawaited(_map?.animateTo(camera.target, zoom: camera.zoom));
    }
    if (rebuild) setState(() {});

    // Providers can't change mid-build, so load after this frame. Also loads
    // when the map itself can't be shown, so the cards still work.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(ref
          .read(mapProvidersProvider.notifier)
          .loadAround(city?.centre ?? _camera.target, city?.radiusMetres ?? 15000));
      unawaited(_initLocation(aroundClient: !browsingCity));
    });
  }

  /// The part of the map not covered by the search bar and cards.
  Size _visibleMapSize() {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    return Size(
      size.width,
      size.height - padding.top - _topBarHeight - padding.bottom - 16 - _carouselHeight,
    );
  }

  // ---------------------------------------------------------------------------
  // Location
  // ---------------------------------------------------------------------------

  /// Uses the client's location if they allow it. Looking around themselves
  /// ([aroundClient]), the map asks once when it opens (they came here to see
  /// what's near them) and centres on them. Looking at a chosen city it never
  /// asks or moves, and only shows the "you are here" dot if access was
  /// already allowed; "near me" is still a tap away.
  Future<void> _initLocation({required bool aroundClient}) async {
    final location = ref.read(deviceLocationProvider);
    var access = await location.access();
    if (aroundClient && access == LocationAccess.denied) access = await location.requestAccess();
    if (!mounted || access != LocationAccess.granted) return;
    setState(() => _locationGranted = true);
    if (!aroundClient) return;

    final last = await location.lastKnown();
    if (!mounted) return;
    if (last != null) _setUserPoint(last, recentre: !_userMovedMap);
    try {
      final fresh = await location.current(timeout: const Duration(seconds: 10));
      if (mounted) _setUserPoint(fresh, recentre: last == null && !_userMovedMap);
    } on LocationUnavailableException {
      // The last known position (or the default view) will do.
    }
  }

  void _setUserPoint(GeoPoint point, {required bool recentre}) {
    setState(() {
      _userPoint = point;
      _listings = _sorted(ref.read(mapProvidersProvider).providers.values);
    });
    if (recentre && point.isInAustralia) {
      unawaited(_map?.animateTo(point, zoom: AppConfig.mapNearbyZoom));
    }
  }

  Future<void> _locateMe() async {
    if (_locating) return;
    HapticFeedback.selectionClick();
    final location = ref.read(deviceLocationProvider);
    var access = await location.access();
    if (access == LocationAccess.denied) access = await location.requestAccess();
    if (!mounted) return;

    switch (access) {
      case LocationAccess.granted:
        setState(() {
          _locationGranted = true;
          _locating = true;
        });
        try {
          final point = await location.current();
          if (!mounted) return;
          _setUserPoint(point, recentre: false);
          await _map?.animateTo(point, zoom: AppConfig.mapNearbyZoom);
        } on LocationUnavailableException {
          if (mounted) context.showAppSnackBar("We couldn't find your location. Please try again.", isError: true);
        } finally {
          if (mounted) setState(() => _locating = false);
        }
      case LocationAccess.deniedForever:
        context.showAppSnackBar(
          'Allow location access in Settings to see salons near you.',
          action: SnackBarAction(label: 'Settings', onPressed: location.openAppSettings),
        );
      case LocationAccess.serviceDisabled:
        context.showAppSnackBar(
          'Turn on location services to see salons near you.',
          action: SnackBarAction(label: 'Turn on', onPressed: location.openLocationSettings),
        );
      case LocationAccess.denied:
        break;
    }
  }

  // ---------------------------------------------------------------------------
  // Map
  // ---------------------------------------------------------------------------

  Future<void> _onCameraIdle(MapCamera camera) async {
    _camera = camera;
    final bounds = await _map?.visibleBounds();
    if (!mounted) return;
    unawaited(ref
        .read(mapProvidersProvider.notifier)
        .loadAround(bounds?.center ?? camera.target, bounds?.coverRadiusMetres ?? 15000));
    if ((camera.zoom - _clusteredAtZoom).abs() >= 0.4) unawaited(_rebuildMarkers());
  }

  List<ProviderListing> _sorted(Iterable<ProviderListing> listings) {
    final origin = _userPoint ?? _camera.target;
    double distance(ProviderListing listing) => listing.point?.distanceKmTo(origin) ?? double.infinity;
    return listings.where((listing) => listing.point != null).toList()
      ..sort((a, b) => distance(a).compareTo(distance(b)));
  }

  /// Redraws the pins for the current zoom and selection. Pictures are
  /// cached, so after the first pass this is quick.
  Future<void> _rebuildMarkers() async {
    final icons = _icons;
    if (icons == null) return;
    final sequence = ++_markerSequence;
    final zoom = _camera.zoom;
    final selectedId = _selectedId;
    final listings = _listings;

    final selected = listings.where((listing) => listing.id == selectedId).firstOrNull;
    final others = [for (final listing in listings) if (listing.id != selectedId) listing];
    final clusters = clusterByScreenDistance(others, (listing) => listing.point!, zoom: zoom);

    try {
      // All at once: pins share a few cached pictures, so this is normally
      // instant, and anything not drawn yet is drawn once, in parallel.
      final markers = await Future.wait([
        for (final cluster in clusters)
          cluster.isSingle ? _pin(icons, cluster.items.single, selected: false) : _clusterMarker(icons, cluster),
        if (selected != null) _pin(icons, selected, selected: true),
      ]);
      if (!mounted || sequence != _markerSequence) return;
      setState(() {
        _markers = markers;
        _clusteredAtZoom = zoom;
      });
    } catch (e, st) {
      AppLogger.e('Drawing map pins failed', tag: 'ProvidersMap', error: e, stackTrace: st);
    }
  }

  Future<AppMapMarker> _pin(MarkerIconFactory icons, ProviderListing listing, {required bool selected}) async {
    final image = await icons.providerPin(ProviderPinSpec(
      tone: selected ? PinTone.selected : (listing.acceptsBookings ? PinTone.standard : PinTone.muted),
      approximate: listing.approximateLocation,
    ));
    return AppMapMarker(
      id: listing.id,
      point: listing.point!,
      image: image,
      zIndex: selected ? 10 : 2,
      semanticLabel: listing.name,
      onTap: () => _select(listing, moveCamera: false),
    );
  }

  Future<AppMapMarker> _clusterMarker(MarkerIconFactory icons, MapCluster<ProviderListing> cluster) async {
    return AppMapMarker(
      id: 'cluster:${cluster.items.map((listing) => listing.id).join(',')}',
      point: cluster.center,
      image: await icons.cluster(cluster.items.length),
      zIndex: 1,
      onTap: () => _openCluster(cluster),
    );
  }

  void _openCluster(MapCluster<ProviderListing> cluster) {
    HapticFeedback.selectionClick();
    // Already at street level: they're in the same building, so just show
    // the first one; the carousel lists the rest.
    if (_camera.zoom >= AppConfig.mapStreetZoom - 0.5) {
      _select(cluster.items.first, moveCamera: false);
      return;
    }
    unawaited(_map?.fitPoints(cluster.items.map((listing) => listing.point!), paddingPx: 96));
  }

  void _select(ProviderListing listing, {required bool moveCamera}) {
    if (_selectedId != listing.id) {
      HapticFeedback.selectionClick();
      setState(() => _selectedId = listing.id);
      unawaited(_rebuildMarkers());
    }
    if (moveCamera) unawaited(_map?.animateTo(listing.point!));
    final page = _listings.indexWhere((candidate) => candidate.id == listing.id);
    if (page >= 0 && _pages.hasClients && _pages.page?.round() != page) {
      _syncingPage = true;
      _pages
          .animateToPage(page, duration: const Duration(milliseconds: 320), curve: Curves.easeOutCubic)
          .whenComplete(() => _syncingPage = false);
    }
  }

  void _onPageChanged(int page) {
    if (_syncingPage || page >= _listings.length) return;
    _select(_listings[page], moveCamera: true);
  }

  void _openProfile(ProviderListing listing) {
    context.pushNamed(AppRoute.publicProviderProfile.name, pathParameters: {'id': listing.id});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final padding = MediaQuery.paddingOf(context);
    final state = ref.watch(mapProvidersProvider);

    ref.listen(mapProvidersProvider.select((s) => s.providers), (previous, next) {
      if (identical(previous, next)) return;
      setState(() => _listings = _sorted(next.values));
      _clusteredAtZoom = -1;
      unawaited(_rebuildMarkers());
      // Keep the card for the selected pin in view after the list reorders.
      final page = _listings.indexWhere((listing) => listing.id == _selectedId);
      if (page >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || !_pages.hasClients) return;
          _syncingPage = true;
          _pages.jumpToPage(page);
          _syncingPage = false;
        });
      }
    });

    final hasCards = _listings.isNotEmpty;
    final bottomInset = padding.bottom + 16 + (hasCards ? _carouselHeight : 0);

    return AnnotatedRegion(
      value: SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: scheme.surface,
        body: Stack(
          children: [
            Positioned.fill(
              child: AppMap(
                initialCamera: _camera,
                markers: _markers,
                showMyLocation: _locationGranted,
                padding: EdgeInsets.only(top: padding.top + _topBarHeight, bottom: bottomInset),
                onCreated: (controller) {
                  _map = controller;
                  final user = _userPoint;
                  if (user != null && user.isInAustralia && !_userMovedMap) {
                    unawaited(controller.animateTo(user, zoom: AppConfig.mapNearbyZoom));
                  }
                },
                onCameraMoveStarted: () => _userMovedMap = true,
                onCameraIdle: _onCameraIdle,
                onTap: (_) {
                  if (_selectedId == null) return;
                  setState(() => _selectedId = null);
                  unawaited(_rebuildMarkers());
                },
              ),
            ),
            Positioned(
              top: padding.top + 8,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  Row(
                    children: [
                      _RoundButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                        onPressed: () => context.pop(),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => context.pushNamed(AppRoute.providerSearch.name),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 16, offset: const Offset(0, 6)),
                              ],
                            ),
                            child: Material(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(28),
                              child: const IgnorePointer(child: SearchPill()),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  _StatusChip(
                    state: state,
                    empty: !state.loading && state.error == null && state.loaded.isNotEmpty && _listings.isEmpty,
                    onRetry: () => ref.read(mapProvidersProvider.notifier).retry(),
                  ),
                ],
              ),
            ),
            AnimatedPositioned(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              right: 16,
              bottom: bottomInset + 4,
              child: _RoundButton(
                icon: _locationGranted ? Icons.my_location_rounded : Icons.location_searching_rounded,
                tooltip: 'Show salons near me',
                busy: _locating,
                highlighted: true,
                onPressed: _locateMe,
              ),
            ),
            if (hasCards)
              Positioned(
                left: 0,
                right: 0,
                bottom: padding.bottom + 12,
                height: _carouselHeight,
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _listings.length,
                  onPageChanged: _onPageChanged,
                  itemBuilder: (context, index) {
                    final listing = _listings[index];
                    final user = _userPoint;
                    return MapProviderCard(
                      listing: listing,
                      selected: listing.id == _selectedId,
                      distanceKm: user == null || listing.point == null ? null : user.distanceKmTo(listing.point!),
                      onTap: () => _openProfile(listing),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.busy = false,
    this.highlighted = false,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
  final bool busy;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.14), blurRadius: 16, offset: const Offset(0, 6))],
      ),
      child: Material(
        color: scheme.surface,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: IconButton(
          tooltip: tooltip,
          onPressed: busy ? null : onPressed,
          constraints: const BoxConstraints.tightFor(width: 52, height: 52),
          icon: busy
              ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary))
              : Icon(icon, color: highlighted ? scheme.primary : scheme.onSurface),
        ),
      ),
    );
  }
}

/// Loading / failed / nothing-here notice under the search bar.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state, required this.empty, required this.onRetry});

  final MapProvidersState state;
  final bool empty;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final error = state.error;
    final Widget? chip = switch ((state.loading, error, empty)) {
      (true, _, _) => _chip(
          context,
          key: 'loading',
          leading: SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary)),
          label: 'Finding salons…',
        ),
      (_, final Object error?, _) => _chip(
          context,
          key: 'error',
          leading: const Icon(Icons.cloud_off_rounded, size: 16, color: AppTheme.destructive),
          label: isConnectivityError(error) ? "You're offline" : "Couldn't load salons",
          action: TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: scheme.secondary,
              visualDensity: VisualDensity.compact,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text('Retry'),
          ),
        ),
      (_, _, true) => _chip(
          context,
          key: 'empty',
          leading: Icon(Icons.zoom_out_map_rounded, size: 16, color: scheme.secondary),
          label: 'No salons here yet. Try zooming out.',
        ),
      _ => null,
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: chip ?? const SizedBox.shrink(key: ValueKey('none')),
    );
  }

  Widget _chip(BuildContext context, {required String key, required Widget leading, required String label, Widget? action}) {
    final scheme = context.colorScheme;
    return Container(
      key: ValueKey(key),
      padding: EdgeInsets.fromLTRB(14, action == null ? 9 : 2, action == null ? 14 : 4, action == null ? 9 : 2),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(999),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leading,
          const SizedBox(width: 8),
          Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurface)),
          ?action,
        ],
      ),
    );
  }
}
