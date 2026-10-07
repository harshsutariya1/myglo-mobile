import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../shared/authentication/models/auth_repository.dart';
import '../../../shared/bookings/models/booking_failure.dart';
import 'business_stats.dart';

final businessStatsRepositoryProvider = Provider<BusinessStatsRepository>((ref) {
  return BusinessStatsRepository(ref.watch(supabaseClientProvider));
});

/// Aggregated business numbers for the signed-in provider. Totals are
/// computed in the database (one indexed pass over the month's bookings), so
/// no booking rows are downloaded to produce them.
class BusinessStatsRepository {
  BusinessStatsRepository(this._client);

  final SupabaseClient _client;

  static const _tag = 'BusinessStatsRepository';

  /// This month's numbers. Throws a [BookingFailure] when the caller isn't a
  /// signed-in provider; other failures are reported and rethrown.
  Future<BusinessStats> thisMonth() async {
    final sw = Stopwatch()..start();
    try {
      final rows = await _client.rpc('get_provider_business_stats') as List<dynamic>;
      sw.stop();
      AppLogger.api('rpc.get_provider_business_stats', duration: sw.elapsed);
      if (rows.isEmpty) throw StateError('get_provider_business_stats returned no row');
      return BusinessStats.fromJson(Map<String, dynamic>.from(rows.first as Map));
    } catch (e, st) {
      throwBookingError(e, st, tag: _tag, action: 'Loading business stats');
    }
  }
}
