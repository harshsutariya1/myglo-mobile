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
    @JsonKey(name: 'payment_status', unknownEnumValue: PaymentStatus.unknown) required PaymentStatus paymentStatus,
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

    /// The client's review of this booking, if they left one.
    @JsonKey(name: 'review_id') String? reviewId,
    @JsonKey(name: 'review_rating') int? reviewRating,

    /// Paid in the app: until when the time is held while the client pays.
    @JsonKey(name: 'hold_expires_at') DateTime? holdExpiresAt,

    /// When an unanswered request lapses (its start time for cash requests;
    /// earlier for card requests, before the hold on the card can lapse).
    @JsonKey(name: 'respond_by') DateTime? respondBy,

    /// The card that paid, e.g. `visa` and `4242`, and the wallet it was in
    /// (`apple_pay`, `google_pay`), once the payment went through.
    @JsonKey(name: 'card_brand') String? cardBrand,
    @JsonKey(name: 'card_last4') String? cardLast4,
    String? wallet,
    @JsonKey(name: 'amount_refunded_cents') @Default(0) int amountRefundedCents,

    /// Refunds on their way back to the client's card.
    @JsonKey(name: 'refund_pending_cents') @Default(0) int refundPendingCents,

    /// The provider's share of an in-app payment and where it is (provider
    /// only): `scheduled`, `held`, `processing`, `transferred`, `reversed`…
    @JsonKey(name: 'settlement_status') String? settlementStatus,
    @JsonKey(name: 'payout_cents') int? payoutCents,
  }) = _Booking;

  factory Booking.fromJson(Map<String, dynamic> json) => _$BookingFromJson(json);

  /// `Lash lift, Brow tint`.
  String get servicesSummary => items.isEmpty ? 'Appointment' : items.map((item) => item.name).join(', ');

  bool get isMobile => locationType == BookingLocationType.client;

  /// Paid (or being paid) in the app rather than in cash.
  bool get paidInApp => !paymentMethod.isCash;

  /// When an unanswered request lapses, as a wall clock in the provider's
  /// time zone (like [startsAtLocal]).
  DateTime get respondByLocal => respondBy == null ? startsAtLocal : BookingTime.wallClockOf(respondBy!, timeZone);

  /// `Apple Pay · Visa •• 4242`, or null before a card was used.
  String? get cardSummary {
    final brand = switch (cardBrand) {
      null || '' || 'unknown' => null,
      'amex' => 'Amex',
      'mastercard' => 'Mastercard',
      'eftpos_au' => 'eftpos',
      final other => '${other[0].toUpperCase()}${other.substring(1)}',
    };
    final card = [brand, if (cardLast4 != null) '•• $cardLast4'].whereType<String>().join(' ');
    final via = switch (wallet) {
      'apple_pay' => 'Apple Pay',
      'google_pay' => 'Google Pay',
      _ => null,
    };
    final parts = [via, if (card.isNotEmpty) card].whereType<String>();
    return parts.isEmpty ? null : parts.join(' · ');
  }

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

  /// The late-cancellation / no-show fee rate for this booking: the
  /// provider's rate snapshotted at booking time, and always 0 for cash
  /// (the server guarantees the same).
  int get lateFeePercent => paymentMethod.isCash ? 0 : cancellationFeePercent;

  /// The late-cancellation / no-show fee for this booking.
  int get lateFeeCents => (totalCents * lateFeePercent / 100).round();

  /// Started already, so the provider can mark it done or a no-show.
  bool hasStarted(DateTime now) => !startsAt.isAfter(now);

  /// Whether the client can report a problem with the appointment: from its
  /// start until [windowHours] after it ends (the server checks the same).
  bool canReportProblem(DateTime now, {required int windowHours}) =>
      (status == BookingStatus.confirmed || status == BookingStatus.completed || status == BookingStatus.noShow) &&
      hasStarted(now) &&
      !now.isAfter(endsAt.add(Duration(hours: windowHours)));

  /// Completed and still linked to its provider, so the client can review it
  /// (the server checks the same).
  bool get canReview => status == BookingStatus.completed && providerId != null;
}
