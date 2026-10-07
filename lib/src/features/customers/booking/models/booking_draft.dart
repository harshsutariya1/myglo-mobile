import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../../core/location/geo_point.dart';
import '../../../shared/bookings/models/available_slot.dart';
import '../../../shared/bookings/models/booking_enums.dart';
import '../../../shared/bookings/models/client_address.dart';

part 'booking_draft.freezed.dart';

/// Everything chosen so far in the booking funnel for one provider (the
/// services themselves live in the service selection).
@freezed
abstract class BookingDraft with _$BookingDraft {
  const BookingDraft._();

  const factory BookingDraft({
    /// Idempotency key for `create_booking`. Renewed whenever the booking
    /// changes, so a retry of the same booking can never become a different
    /// one.
    required String attemptId,
    AvailableSlot? slot,
    BookingLocationType? locationType,
    ClientAddress? address,

    /// Where [address] was located, once it passed the travel-area check.
    GeoPoint? verifiedPoint,
    double? distanceKm,
    @Default('') String accessNotes,

    /// Contact number for this booking; null until the client edits it (the
    /// profile's number is used until then).
    String? phone,
    @Default('') String notes,
    @Default(PaymentMethod.cash) PaymentMethod paymentMethod,
  }) = _BookingDraft;

  bool get hasSlot => slot != null;

  /// A location is chosen and, for home visits, the address was checked.
  bool get hasLocation => switch (locationType) {
        BookingLocationType.studio => true,
        BookingLocationType.client => address != null && verifiedPoint != null,
        null => false,
      };
}
