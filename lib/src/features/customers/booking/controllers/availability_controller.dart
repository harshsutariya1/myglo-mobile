import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/bookings/controllers/booking_controllers.dart';
import '../../../shared/bookings/models/availability_repository.dart';
import '../../../shared/bookings/models/available_slot.dart';

/// One stretch of a provider's availability for a set of services.
@immutable
class SlotRequest {
  SlotRequest({required this.providerId, required List<String> serviceIds, required this.from, required this.to})
      : serviceIds = List.unmodifiable([...serviceIds]..sort());

  final String providerId;

  /// Sorted, so the same services in any order share a cache entry.
  final List<String> serviceIds;

  /// Provider-local dates, inclusive.
  final DateTime from;
  final DateTime to;

  @override
  bool operator ==(Object other) =>
      other is SlotRequest &&
      other.providerId == providerId &&
      listEquals(other.serviceIds, serviceIds) &&
      other.from == from &&
      other.to == to;

  @override
  int get hashCode => Object.hash(providerId, Object.hashAll(serviceIds), from, to);
}

/// Free start times for a [SlotRequest].
///
/// Refetches by itself whenever the provider's availability changes (their
/// hours, time off, settings or someone else's booking): the settings stream
/// carries a version that moves with every such change, over realtime.
final availableSlotsProvider = FutureProvider.autoDispose.family<SlotCalendar, SlotRequest>((ref, request) async {
  final settings = await ref.watch(bookingSettingsProvider(request.providerId).future);
  if (settings == null || !settings.acceptsBookings || request.serviceIds.isEmpty || request.to.isBefore(request.from)) {
    return SlotCalendar.empty;
  }
  final slots = await ref.watch(availabilityRepositoryProvider).getAvailableSlots(
        providerId: request.providerId,
        serviceIds: request.serviceIds,
        from: request.from,
        to: request.to,
      );
  return SlotCalendar(slots);
});
