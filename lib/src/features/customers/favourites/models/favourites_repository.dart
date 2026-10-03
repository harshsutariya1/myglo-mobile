import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../shared/authentication/models/auth_repository.dart';

final favouritesRepositoryProvider = Provider<FavouritesRepository>((ref) {
  return FavouritesRepository(ref.watch(supabaseClientProvider));
});

/// Postgres `unique_violation` SQLSTATE.
const _uniqueViolation = '23505';

/// A client's saved providers (`favourites` table). Row-level security limits
/// every query to the signed-in client's own rows, and a trigger rejects
/// anything other than client → provider.
class FavouritesRepository {
  FavouritesRepository(this._client);

  final SupabaseClient _client;

  /// Ids of the providers [clientId] has saved, most recently saved first.
  Future<List<String>> getFavouriteProviderIds(String clientId) async {
    final sw = Stopwatch()..start();
    try {
      final response = await _client
          .from('favourites')
          .select('provider_id')
          .eq('client_id', clientId)
          .order('created_at', ascending: false);
      sw.stop();
      final ids = (response as List).map((e) => e['provider_id'] as String).toList();
      AppLogger.api('favourites.select', count: ids.length, duration: sw.elapsed);
      return ids;
    } catch (e, st) {
      AppLogger.e('Failed to fetch favourites for $clientId', tag: 'FavouritesRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Saves [providerId]. Saving twice is a no-op, so a retried request is safe.
  Future<void> addFavourite({required String clientId, required String providerId}) async {
    final sw = Stopwatch()..start();
    try {
      await _client.from('favourites').insert({'client_id': clientId, 'provider_id': providerId});
      sw.stop();
      AppLogger.api('favourites.insert', endpoint: 'provider=$providerId', duration: sw.elapsed);
    } on PostgrestException catch (e) {
      if (e.code == _uniqueViolation) return;
      AppLogger.e('Failed to add favourite $providerId', tag: 'FavouritesRepository', error: e);
      rethrow;
    } catch (e, st) {
      AppLogger.e('Failed to add favourite $providerId', tag: 'FavouritesRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Removes [providerId] from [clientId]'s favourites, if present.
  Future<void> removeFavourite({required String clientId, required String providerId}) async {
    final sw = Stopwatch()..start();
    try {
      await _client.from('favourites').delete().eq('client_id', clientId).eq('provider_id', providerId);
      sw.stop();
      AppLogger.api('favourites.delete', endpoint: 'provider=$providerId', duration: sw.elapsed);
    } catch (e, st) {
      AppLogger.e('Failed to remove favourite $providerId', tag: 'FavouritesRepository', error: e, stackTrace: st);
      rethrow;
    }
  }
}
