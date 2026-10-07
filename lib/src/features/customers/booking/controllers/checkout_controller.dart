import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/bookings/models/booking.dart';
import '../../../shared/bookings/models/booking_enums.dart';
import '../../../shared/bookings/models/booking_failure.dart';
import '../../../shared/bookings/models/booking_repository.dart';
import '../models/booking_draft.dart';
import '../models/service_selection.dart';

/// Places the booking for one provider's funnel.
final checkoutControllerProvider =
    AsyncNotifierProvider.autoDispose.family<CheckoutController, Booking?, String>(CheckoutController.new);

class CheckoutController extends AsyncNotifier<Booking?> {
  CheckoutController(this.providerId);

  final String providerId;

  @override
  Booking? build() => null;

  /// Creates the booking. Returns it, or null after storing a
  /// [BookingFailure] in the state. Ignored while a submission is running.
  Future<Booking?> submit({
    required ServiceSelection selection,
    required BookingDraft draft,
    required String phone,
  }) async {
    if (state.isLoading) return null;
    final slot = draft.slot;
    final location = draft.locationType;
    if (selection.isEmpty || slot == null || location == null || !draft.hasLocation) {
      state = AsyncError(const BookingFailure(BookingFailureCode.invalidRequest), StackTrace.current);
      return null;
    }

    state = const AsyncLoading();
    final request = BookingRequest(
      bookingId: draft.attemptId,
      providerId: providerId,
      serviceIds: [for (final service in selection.services) service.id],
      startsAt: slot.startsAt,
      locationType: location,
      phone: phone,
      expectedTotalCents: selection.totalCents,
      paymentMethod: draft.paymentMethod,
      address: location == BookingLocationType.client ? draft.address : null,
      point: location == BookingLocationType.client ? draft.verifiedPoint : null,
      accessNotes: draft.accessNotes,
      notes: draft.notes,
    );

    try {
      final booking = await ref.read(bookingRepositoryProvider).createBooking(request);
      if (ref.mounted) state = AsyncData(booking);
      return booking;
    } catch (e, st) {
      if (ref.mounted) state = AsyncError(BookingFailure.from(e), st);
      return null;
    }
  }

  /// Clears a shown error.
  void reset() {
    if (!state.isLoading) state = const AsyncData(null);
  }
}
