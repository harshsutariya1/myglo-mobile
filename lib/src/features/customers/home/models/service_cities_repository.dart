import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../shared/authentication/models/auth_repository.dart';
import 'service_city.dart';

final serviceCitiesRepositoryProvider = Provider<ServiceCitiesRepository>((ref) {
  return ServiceCitiesRepository(ref.watch(supabaseClientProvider));
});

/// The curated list of cities clients can browse, read through the
/// `list_service_cities` RPC (clients can't read the table directly).
class ServiceCitiesRepository {
  ServiceCitiesRepository(this._client);

  final SupabaseClient _client;

  static const _tag = 'ServiceCitiesRepository';

  /// Active cities in display order, each with its current provider count.
  Future<List<ServiceCity>> listCities() async {
    final sw = Stopwatch()..start();
    try {
      final rows = await _client.rpc('list_service_cities');
      sw.stop();
      final cities = <ServiceCity>[];
      for (final row in (rows as List?) ?? const []) {
        try {
          cities.add(ServiceCity.fromJson(Map<String, dynamic>.from(row as Map)));
        } catch (e, st) {
          // One bad row shouldn't hide every other city.
          AppLogger.e('Skipping unreadable service city', tag: _tag, error: e, stackTrace: st);
        }
      }
      AppLogger.api('rpc.list_service_cities', count: cities.length, duration: sw.elapsed);
      return cities;
    } catch (e, st) {
      AppLogger.e('Loading service cities failed', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }
}
