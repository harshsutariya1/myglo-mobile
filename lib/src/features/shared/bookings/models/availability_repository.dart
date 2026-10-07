import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/location/geo_point.dart';
import '../../../../core/realtime/postgres_changes.dart';
import '../../../../core/utils/app_logger.dart';
import '../../authentication/models/auth_repository.dart';
import 'available_slot.dart';
import 'booking_failure.dart';
import 'booking_settings.dart';
import 'booking_time.dart';
import 'working_hours.dart';

final availabilityRepositoryProvider = Provider<AvailabilityRepository>((ref) {
  return AvailabilityRepository(ref.watch(supabaseClientProvider));
});

/// Result of checking an address against a mobile provider's travel area.
class ServiceAreaCheck {
  const ServiceAreaCheck({required this.withinArea, this.distanceKm, this.radiusKm});

  final bool withinArea;

  /// Straight-line distance from the provider, when they've set a location.
  final double? distanceKm;

  /// The provider's limit; null when they travel any distance.
  final double? radiusKm;
}

/// What clients can see of a provider's availability: their booking rules
/// and free start times. Other clients' bookings are never exposed, only
/// their effect on free times.
class AvailabilityRepository {
  AvailabilityRepository(this._client);

  final SupabaseClient _client;

  static const _settingsTable = 'provider_booking_settings';

  Future<ProviderBookingSettings?> getSettings(String providerId) async {
    final sw = Stopwatch()..start();
    try {
      final row = await _client.from(_settingsTable).select().eq('provider_id', providerId).maybeSingle();
      sw.stop();
      AppLogger.api('$_settingsTable.select', endpoint: 'provider=$providerId', duration: sw.elapsed);
      return row == null ? null : ProviderBookingSettings.fromJson(row);
    } catch (e, st) {
      AppLogger.e('Failed to load booking settings for $providerId', tag: 'AvailabilityRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// [providerId]'s settings, updated live. Every change to their hours,
  /// time off, settings or bookings moves `availabilityVersion`, which is how
  /// a client picking a time learns that slots changed.
  Stream<ProviderBookingSettings?> watchSettings(String providerId) async* {
    var latest = await getSettings(providerId);
    yield latest;
    await for (final change in watchPostgresChanges(
      _client,
      table: _settingsTable,
      event: PostgresChangeEvent.update,
      filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'provider_id', value: providerId),
    )) {
      if (change.isResync) {
        try {
          latest = await getSettings(providerId);
        } catch (_) {
          // Already reported; keep the last known settings until the next change.
          continue;
        }
      } else {
        try {
          latest = ProviderBookingSettings.fromJson(change.payload!.newRecord);
        } catch (e, st) {
          AppLogger.e('Unreadable realtime settings payload', tag: 'AvailabilityRepository', error: e, stackTrace: st);
          continue;
        }
      }
      yield latest;
    }
  }

  /// [providerId]'s published weekly opening hours.
  Future<WeeklySchedule> getWorkingHours(String providerId) async {
    final sw = Stopwatch()..start();
    try {
      final rows = await _client
          .from('provider_working_hours')
          .select('weekday, opens_at, closes_at')
          .eq('provider_id', providerId)
          .order('weekday')
          .order('opens_at');
      sw.stop();
      AppLogger.api('provider_working_hours.select', count: rows.length, duration: sw.elapsed);
      return WeeklySchedule([for (final row in rows) WorkingHoursRange.fromJson(row)]);
    } catch (e, st) {
      AppLogger.e('Failed to load working hours for $providerId', tag: 'AvailabilityRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Free start times for [serviceIds] between two provider-local dates
  /// (inclusive, at most 62 days apart).
  Future<List<AvailableSlot>> getAvailableSlots({
    required String providerId,
    required List<String> serviceIds,
    required DateTime from,
    required DateTime to,
  }) async {
    final sw = Stopwatch()..start();
    try {
      final rows = await _client.rpc('get_available_slots', params: {
        'p_provider_id': providerId,
        'p_service_ids': serviceIds,
        'p_from': BookingTime.isoDate(from),
        'p_to': BookingTime.isoDate(to),
      });
      sw.stop();
      final slots = [
        for (final row in rows as List) AvailableSlot.fromJson(Map<String, dynamic>.from(row as Map)),
      ];
      AppLogger.api('rpc.get_available_slots', count: slots.length, duration: sw.elapsed);
      return slots;
    } catch (e, st) {
      throwBookingError(e, st, tag: 'AvailabilityRepository', action: 'Loading slots for $providerId');
    }
  }

  /// Whether [point] is inside [providerId]'s travel area.
  Future<ServiceAreaCheck> checkServiceArea({required String providerId, required GeoPoint point}) async {
    try {
      final rows = await _client.rpc('check_service_area', params: {
        'p_provider_id': providerId,
        'p_latitude': point.latitude,
        'p_longitude': point.longitude,
      });
      final row = Map<String, dynamic>.from((rows as List).single as Map);
      return ServiceAreaCheck(
        withinArea: row['within_area'] as bool,
        distanceKm: (row['distance_km'] as num?)?.toDouble(),
        radiusKm: (row['radius_km'] as num?)?.toDouble(),
      );
    } catch (e, st) {
      throwBookingError(e, st, tag: 'AvailabilityRepository', action: 'Checking the service area of $providerId');
    }
  }
}
