import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/location/geo_point.dart';
import '../models/explore_repository.dart';
import '../models/provider_listing.dart';

/// A circle the map has already loaded every provider in.
class LoadedArea {
  const LoadedArea(this.center, this.radiusMetres);

  final GeoPoint center;
  final double radiusMetres;

  /// Whether the circle around [center] with [radiusMetres] lies inside this one.
  bool covers(GeoPoint center, double radiusMetres) =>
      this.center.distanceKmTo(center) * 1000 + radiusMetres <= this.radiusMetres;
}

class MapProvidersState {
  const MapProvidersState({
    this.providers = const {},
    this.loaded = const [],
    this.loading = false,
    this.error,
  });

  /// Everything loaded so far, by id. Kept while panning so pins don't flash.
  final Map<String, ProviderListing> providers;
  final List<LoadedArea> loaded;
  final bool loading;

  /// Why the latest load failed, until the next one succeeds.
  final Object? error;

  MapProvidersState copyWith({
    Map<String, ProviderListing>? providers,
    List<LoadedArea>? loaded,
    bool? loading,
    Object? error,
    bool clearError = false,
  }) =>
      MapProvidersState(
        providers: providers ?? this.providers,
        loaded: loaded ?? this.loaded,
        loading: loading ?? this.loading,
        error: clearError ? null : error ?? this.error,
      );
}

final mapProvidersProvider =
    NotifierProvider.autoDispose<MapProvidersController, MapProvidersState>(MapProvidersController.new);

/// Loads the providers around wherever the map is looking, skipping areas
/// it has already loaded.
class MapProvidersController extends Notifier<MapProvidersState> {
  static const double minRadiusMetres = 2000;
  static const double maxRadiusMetres = 100000;

  int _sequence = 0;
  ({GeoPoint center, double radius})? _last;

  @override
  MapProvidersState build() => const MapProvidersState();

  /// Makes sure everything within [radiusMetres] of [center] is loaded.
  Future<void> loadAround(GeoPoint center, double radiusMetres) async {
    // A little beyond the edges, so short pans don't need another request.
    final radius = (radiusMetres * 1.25).clamp(minRadiusMetres, maxRadiusMetres).toDouble();
    if (state.loaded.any((area) => area.covers(center, radius))) return;
    _last = (center: center, radius: radius);
    final sequence = ++_sequence;
    state = state.copyWith(loading: true);
    try {
      final results = await ref.read(exploreRepositoryProvider).providersAround(center, radiusMetres: radius);
      if (!ref.mounted || sequence != _sequence) return;
      // A full page may have been cut off at the limit: only claim the area
      // out to the furthest provider that came back.
      final complete = results.length < AppConfig.mapProvidersLimit;
      final reach = complete
          ? radius
          : results.map((listing) => (listing.distanceKm ?? 0) * 1000).fold<double>(0, math.max);
      state = MapProvidersState(
        providers: {...state.providers, for (final listing in results) listing.id: listing},
        loaded: [...state.loaded, if (reach > 0) LoadedArea(center, reach)],
      );
    } catch (error) {
      if (!ref.mounted || sequence != _sequence) return;
      state = state.copyWith(loading: false, error: error);
    }
  }

  /// Repeats the last load that failed.
  Future<void> retry() async {
    final last = _last;
    if (last == null) return;
    state = state.copyWith(clearError: true);
    await loadAround(last.center, last.radius / 1.25);
  }
}
