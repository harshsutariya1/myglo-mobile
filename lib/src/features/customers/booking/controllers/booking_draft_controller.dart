import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../../core/location/geo_point.dart';
import '../../../shared/bookings/models/available_slot.dart';
import '../../../shared/bookings/models/booking_enums.dart';
import '../../../shared/bookings/models/client_address.dart';
import '../models/booking_draft.dart';
import 'service_selection_controller.dart';

/// The booking funnel's choices for one provider.
///
/// Every funnel screen watches it (the service list at the root of the flow
/// included), so it lives exactly as long as the flow: going back a step keeps
/// the chosen time and address, and leaving the flow starts the next visit
/// fresh.
final bookingDraftProvider =
    NotifierProvider.autoDispose.family<BookingDraftController, BookingDraft, String>(BookingDraftController.new);

class BookingDraftController extends Notifier<BookingDraft> {
  BookingDraftController(this.providerId);

  final String providerId;

  static const Uuid _uuid = Uuid();

  @override
  BookingDraft build() {
    // Different services mean a different length, so the chosen time may no
    // longer fit: make the client pick again.
    ref.listen(selectedServiceIdsProvider(providerId), (previous, next) {
      if (previous != null && !listEquals(previous, next) && state.slot != null) {
        _update(state.copyWith(slot: null));
      }
    });
    return BookingDraft(attemptId: _uuid.v4());
  }

  void selectSlot(AvailableSlot slot) {
    if (state.slot != slot) _update(state.copyWith(slot: slot));
  }

  void clearSlot() {
    if (state.slot != null) _update(state.copyWith(slot: null));
  }

  void selectLocation(BookingLocationType type) {
    if (state.locationType != type) _update(state.copyWith(locationType: type));
  }

  /// Stores the client's address. A changed address has to be checked again.
  void setAddress(ClientAddress address, {required String accessNotes}) {
    final changed = address != state.address;
    _update(state.copyWith(
      address: address,
      accessNotes: accessNotes,
      verifiedPoint: changed ? null : state.verifiedPoint,
      distanceKm: changed ? null : state.distanceKm,
    ));
  }

  /// [address] was located at [point] and is inside the travel area.
  void markAddressVerified(ClientAddress address, GeoPoint point, {double? distanceKm}) {
    _update(state.copyWith(address: address, verifiedPoint: point, distanceKm: distanceKm));
  }

  void setPhone(String phone) {
    if (state.phone != phone) _update(state.copyWith(phone: phone));
  }

  void setNotes(String notes) {
    if (state.notes != notes) _update(state.copyWith(notes: notes));
  }

  void selectPaymentMethod(PaymentMethod method) {
    if (state.paymentMethod != method) _update(state.copyWith(paymentMethod: method));
  }

  void _update(BookingDraft next) => state = next.copyWith(attemptId: _uuid.v4());
}
