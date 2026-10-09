import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/location/geo_point.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../shared/authentication/models/auth_repository.dart';
import 'provider_listing.dart';

final exploreRepositoryProvider = Provider<ExploreRepository>((ref) {
  return ExploreRepository(ref.watch(supabaseClientProvider));
});

/// Finding providers: text search and what's on the map. Both go through
/// read-only RPCs that return public fields only.
///
/// A client's position is rounded to about 100 m before it's sent and is
/// only used to sort and measure that request; the server doesn't keep it.
class ExploreRepository {
  ExploreRepository(this._client);

  final SupabaseClient _client;

  static const _tag = 'ExploreRepository';

  /// Providers matching every word of [query] in their name, services or
  /// suburb, best match first (nearest first among equals when [near] is
  /// given).
  Future<List<ProviderListing>> search(
    String query, {
    GeoPoint? near,
    int limit = AppConfig.searchResultsLimit,
  }) async {
    final trimmed = query.trim();
    if (trimmed.length < AppConfig.searchMinLength) return const [];
    final origin = near?.coarse();
    final sw = Stopwatch()..start();
    try {
      final rows = await _client.rpc('search_providers', params: {
        'p_query': trimmed,
        'p_latitude': origin?.latitude,
        'p_longitude': origin?.longitude,
        'p_limit': limit,
      });
      sw.stop();
      final listings = _parse(rows);
      AppLogger.api('rpc.search_providers', count: listings.length, duration: sw.elapsed);
      return listings;
    } catch (e, st) {
      AppLogger.e('Provider search failed', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Providers pinned within [radiusMetres] of [center], nearest first.
  Future<List<ProviderListing>> providersAround(
    GeoPoint center, {
    required double radiusMetres,
    int limit = AppConfig.mapProvidersLimit,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final rows = await _client.rpc('map_providers', params: {
        'p_latitude': center.latitude,
        'p_longitude': center.longitude,
        'p_radius_m': radiusMetres,
        'p_limit': limit,
      });
      sw.stop();
      final listings = _parse(rows);
      AppLogger.api('rpc.map_providers', count: listings.length, duration: sw.elapsed);
      return listings;
    } catch (e, st) {
      AppLogger.e('Loading map providers failed', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  List<ProviderListing> _parse(Object? rows) {
    final listings = <ProviderListing>[];
    for (final row in (rows as List?) ?? const []) {
      try {
        listings.add(ProviderListing.fromJson(Map<String, dynamic>.from(row as Map)));
      } catch (e, st) {
        // One malformed row shouldn't hide every other provider.
        AppLogger.e('Skipping unreadable provider listing', tag: _tag, error: e, stackTrace: st);
      }
    }
    return listings;
  }
}
