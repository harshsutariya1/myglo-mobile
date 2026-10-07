import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/location/geo_point.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';
import '../../../shared/authentication/models/user_repository.dart';
import '../../../shared/authentication/models/user_role.dart';
import '../../../shared/bookings/controllers/booking_controllers.dart';
import '../../../shared/bookings/models/booking_failure.dart';
import '../../../shared/bookings/models/booking_settings.dart';
import '../../../shared/bookings/models/working_hours.dart';
import '../models/provider_schedule_repository.dart';
import '../models/time_off.dart';

/// The signed-in provider's id, or null for anyone else.
final currentProviderIdProvider = Provider.autoDispose<String?>((ref) {
  return ref.watch(userProfileProvider.select((p) => p.value?.isProvider == true ? p.value?.rawUser.id : null));
});

/// The signed-in provider's own booking rules, live.
final ownBookingSettingsProvider = Provider.autoDispose<AsyncValue<ProviderBookingSettings?>>((ref) {
  final providerId = ref.watch(currentProviderIdProvider);
  if (providerId == null) return const AsyncData(null);
  return ref.watch(bookingSettingsProvider(providerId));
});

/// The signed-in provider's weekly hours.
final ownWorkingHoursProvider = FutureProvider.autoDispose<WeeklySchedule>((ref) async {
  final providerId = ref.watch(currentProviderIdProvider);
  if (providerId == null) return WeeklySchedule(const []);
  return ref.watch(workingHoursProvider(providerId).future);
});

/// The signed-in provider's upcoming time off.
final ownTimeOffProvider = FutureProvider.autoDispose<List<TimeOffBlock>>((ref) async {
  final providerId = ref.watch(currentProviderIdProvider);
  if (providerId == null) return const [];
  // Refreshes with the availability signal, i.e. after every change.
  await ref.watch(bookingSettingsProvider(providerId).future);
  return ref.watch(providerScheduleRepositoryProvider).upcomingTimeOff(providerId);
});

/// Changes to the signed-in provider's availability. Each method throws a
/// [BookingFailure] with a message ready to show.
final providerScheduleActionsProvider = Provider<ProviderScheduleActions>(ProviderScheduleActions.new);

class ProviderScheduleActions {
  ProviderScheduleActions(this._ref);

  final Ref _ref;

  ProviderScheduleRepository get _repository => _ref.read(providerScheduleRepositoryProvider);

  String _providerId() {
    final id = _ref.read(userProfileProvider).value;
    if (id == null || !id.isProvider) throw const BookingFailure(BookingFailureCode.providersOnly);
    return id.rawUser.id;
  }

  Future<ProviderBookingSettings> updateSettings(Map<String, Object?> changes) =>
      _guard(() => _repository.updateSettings(_providerId(), changes));

  Future<WeeklySchedule> saveWorkingHours(WeeklySchedule schedule) => _guard(() async {
        final error = schedule.validationError;
        if (error != null) throw const BookingFailure(BookingFailureCode.workingHoursInvalid);
        final saved = await _repository.setWorkingHours(schedule);
        _ref.invalidate(workingHoursProvider(_providerId()));
        return saved;
      });

  Future<TimeOffBlock> addTimeOff({required DateTime startsAt, required DateTime endsAt, String? reason}) =>
      _guard(() async {
        final block = await _repository.addTimeOff(
          providerId: _providerId(),
          startsAt: startsAt,
          endsAt: endsAt,
          reason: reason,
        );
        _ref.invalidate(ownTimeOffProvider);
        return block;
      });

  Future<void> deleteTimeOff(String id) => _guard(() async {
        await _repository.deleteTimeOff(id);
        _ref.invalidate(ownTimeOffProvider);
      });

  /// Saves where the provider is based: the address clients see for studio
  /// appointments, and the point distances for home visits are measured from.
  Future<void> setBusinessLocation({required String addressText, required GeoPoint point}) => _guard(() async {
        await _ref.read(userRepositoryProvider).updateUserProfile(
              id: _providerId(),
              role: UserRole.provider,
              addressText: addressText,
              latitude: point.latitude,
              longitude: point.longitude,
            );
        _ref.invalidate(userProfileProvider);
      });

  Future<T> _guard<T>(Future<T> Function() action) async {
    try {
      return await action();
    } catch (e, st) {
      if (e is! BookingFailure) {
        AppLogger.w('Schedule change failed', tag: 'ProviderSchedule', error: e, stackTrace: st);
      }
      throw BookingFailure.from(e);
    }
  }
}
