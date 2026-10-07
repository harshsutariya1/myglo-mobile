import 'package:freezed_annotation/freezed_annotation.dart';

import 'booking_enums.dart';
import 'booking_time.dart';
import 'client_address.dart';

part 'booking.freezed.dart';
part 'booking.g.dart';

/// Reads a Postgres `timestamp without time zone` as a provider-local wall
/// clock (see [BookingTime]).
class WallClockConverter implements JsonConverter<DateTime, String> {
  const WallClockConverter();

  @override
  DateTime fromJson(String json) => BookingTime.parseWallClock(json);

  @override
  String toJson(DateTime object) => object.toIso8601String().replaceFirst('Z', '');
}

/// One service on a booking, as it was when booked.
@freezed
abstract class BookingItem with _$BookingItem {
  const factory BookingItem({
    @JsonKey(name: 'service_id') String? serviceId,
    required String name,
    String? category,
    @JsonKey(name: 'duration_minutes') required int durationMinutes,
    @JsonKey(name: 'price_cents') required int priceCents,
  }) = _BookingItem;

  factory BookingItem.fromJson(Map<String, dynamic> json) => _$BookingItemFromJson(json);
}

/// A booking as both parties see it (`booking_details` view). Row level
/// security only ever returns bookings the signed-in user is a party to.
@freezed
abstract class Booking with _$Booking {
  const Booking._();

  const factory Booking({
    required String id,
    required String reference,
    @JsonKey(name: 'client_id') String? clientId,
    @JsonKey(name: 'provider_id') String? providerId,
    required BookingStatus status,
    @JsonKey(name: 'starts_at') required DateTime startsAt,
    @JsonKey(name: 'ends_at') required DateTime endsAt,
    @JsonKey(name: 'time_zone') required String timeZone,
    @WallClockConverter() @JsonKey(name: 'starts_at_local') required DateTime startsAtLocal,
    @WallClockConverter() @JsonKey(name: 'ends_at_local') required DateTime endsAtLocal,
    @JsonKey(name: 'duration_minutes') required int durationMinutes,
    @JsonKey(name: 'location_type') required BookingLocationType locationType,
    @JsonKey(name: 'address_text') required String addressText,
    ClientAddress? address,
    @JsonKey(name: 'access_notes') String? accessNotes,
    double? latitude,
    double? longitude,
    @JsonKey(name: 'distance_km') double? distanceKm,
    @JsonKey(name: 'provider_name') required String providerName,
    @JsonKey(name: 'provider_avatar_url') String? providerAvatarUrl,
    @JsonKey(name: 'client_name') required String clientName,
    @JsonKey(name: 'client_avatar_url') String? clientAvatarUrl,
    @JsonKey(name: 'client_phone') required String clientPhone,
    @JsonKey(name: 'client_notes') String? clientNotes,
    @JsonKey(name: 'subtotal_cents') required int subtotalCents,
    @JsonKey(name: 'total_cents') required int totalCents,
    @Default('AUD') String currency,
    @JsonKey(name: 'payment_method') required PaymentMethod paymentMethod,
    @JsonKey(name: 'payment_status') required PaymentStatus paymentStatus,
    @JsonKey(name: 'requires_approval') required bool requiresApproval,
    @JsonKey(name: 'cancellation_window_hours') required int cancellationWindowHours,
    @JsonKey(name: 'cancellation_fee_percent') required int cancellationFeePercent,
    @JsonKey(name: 'free_cancellation_until') required DateTime freeCancellationUntil,
    @JsonKey(name: 'decline_reason') String? declineReason,
    @JsonKey(name: 'responded_at') DateTime? respondedAt,
    @JsonKey(name: 'cancelled_by') CancelledBy? cancelledBy,
    @JsonKey(name: 'cancellation_reason') String? cancellationReason,
    @JsonKey(name: 'cancelled_at') DateTime? cancelledAt,
    @JsonKey(name: 'late_cancellation') @Default(false) bool lateCancellation,
    @JsonKey(name: 'cancellation_fee_cents') @Default(0) int cancellationFeeCents,
    @JsonKey(name: 'completed_at') DateTime? completedAt,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'updated_at') required DateTime updatedAt,
    @Default(<BookingItem>[]) List<BookingItem> items,

    /// Myglo's commission on this booking. Only the provider can see it
    /// (null for the client, who pays no booking fee).
    @JsonKey(name: 'platform_fee_cents') int? platformFeeCents,
  }) = _Booking;

  factory Booking.fromJson(Map<String, dynamic> json) => _$BookingFromJson(json);

  /// `Lash lift, Brow tint`.
  String get servicesSummary => items.isEmpty ? 'Appointment' : items.map((item) => item.name).join(', ');

  bool get isMobile => locationType == BookingLocationType.client;

  /// The provider's UTC offset at the time of the appointment.
  Duration get utcOffset => BookingTime.offsetBetween(startsAt, startsAtLocal);

  /// `Gold Coast time (AEST)`.
  String get timeZoneLabel => BookingTime.label(timeZone, offset: utcOffset);

  /// Hasn't finished yet and still holds the provider's time.
  bool isUpcoming(DateTime now) => status.isActive && endsAt.isAfter(now);

  /// Not yet started, so it can still be cancelled.
  bool canCancel(DateTime now) => status.isActive && startsAt.isAfter(now);

  /// A client cancelling now would be a late cancellation (confirmed
  /// bookings inside the provider's window; requests are always free).
  bool isLateToCancel(DateTime now) => status == BookingStatus.confirmed && !now.isBefore(freeCancellationUntil);

  /// The provider's late-cancellation / no-show fee for this booking.
  int get lateFeeCents => (totalCents * cancellationFeePercent / 100).round();

  /// Started already, so the provider can mark it done or a no-show.
  bool hasStarted(DateTime now) => !startsAt.isAfter(now);
}
