import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../shared/authentication/models/auth_repository.dart';
import '../../../shared/bookings/models/booking_failure.dart';
import '../../../shared/bookings/models/booking_settings.dart';
import '../../../shared/bookings/models/working_hours.dart';
import 'time_off.dart';

final providerScheduleRepositoryProvider = Provider<ProviderScheduleRepository>((ref) {
  return ProviderScheduleRepository(ref.watch(supabaseClientProvider));
});

/// A provider's own availability: booking rules, weekly hours and time off.
/// Row level security limits every write to the signed-in provider's rows.
class ProviderScheduleRepository {
  ProviderScheduleRepository(this._client);

  final SupabaseClient _client;

  static const _tag = 'ProviderScheduleRepository';

  /// Saves the changed booking rules (column name → value) and returns the
  /// updated settings.
  Future<ProviderBookingSettings> updateSettings(String providerId, Map<String, Object?> changes) async {
    final sw = Stopwatch()..start();
    try {
      final row = await _client
          .from('provider_booking_settings')
          .update(changes)
          .eq('provider_id', providerId)
          .select()
          .single();
      sw.stop();
      AppLogger.api('provider_booking_settings.update', endpoint: changes.keys.join(','), duration: sw.elapsed);
      return ProviderBookingSettings.fromJson(row);
    } catch (e, st) {
      throwBookingError(e, st, tag: _tag, action: 'Updating booking settings');
    }
  }

  /// Replaces the whole weekly schedule in one transaction.
  Future<WeeklySchedule> setWorkingHours(WeeklySchedule schedule) async {
    final sw = Stopwatch()..start();
    try {
      final rows = await _client.rpc('set_working_hours', params: {'p_hours': schedule.toJson()});
      sw.stop();
      AppLogger.api('rpc.set_working_hours', count: schedule.ranges.length, duration: sw.elapsed);
      return WeeklySchedule([
        for (final row in rows as List) WorkingHoursRange.fromJson(Map<String, dynamic>.from(row as Map)),
      ]);
    } catch (e, st) {
      throwBookingError(e, st, tag: _tag, action: 'Saving working hours');
    }
  }

  /// Time off that hasn't finished yet, soonest first.
  Future<List<TimeOffBlock>> upcomingTimeOff(String providerId, {DateTime? now}) async {
    final sw = Stopwatch()..start();
    try {
      final rows = await _client
          .from('provider_time_off')
          .select()
          .eq('provider_id', providerId)
          .gte('ends_at', (now ?? DateTime.now()).toUtc().toIso8601String())
          .order('starts_at')
          .limit(200);
      sw.stop();
      AppLogger.api('provider_time_off.select', count: rows.length, duration: sw.elapsed);
      return [for (final row in rows) TimeOffBlock.fromJson(row)];
    } catch (e, st) {
      AppLogger.e('Failed to load time off', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<TimeOffBlock> addTimeOff({
    required String providerId,
    required DateTime startsAt,
    required DateTime endsAt,
    String? reason,
  }) async {
    try {
      final row = await _client
          .from('provider_time_off')
          .insert({
            'provider_id': providerId,
            'starts_at': startsAt.toUtc().toIso8601String(),
            'ends_at': endsAt.toUtc().toIso8601String(),
            'reason': reason,
          })
          .select()
          .single();
      AppLogger.i('Time off added', tag: _tag);
      return TimeOffBlock.fromJson(row);
    } catch (e, st) {
      throwBookingError(e, st, tag: _tag, action: 'Adding time off');
    }
  }

  Future<void> deleteTimeOff(String id) async {
    try {
      await _client.from('provider_time_off').delete().eq('id', id);
    } catch (e, st) {
      AppLogger.e('Failed to delete time off $id', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }
}
