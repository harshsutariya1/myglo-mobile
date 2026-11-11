import 'package:freezed_annotation/freezed_annotation.dart';

import 'booking_time.dart';

part 'booking_settings.freezed.dart';
part 'booking_settings.g.dart';

/// A provider's public booking rules (`provider_booking_settings`).
@freezed
abstract class ProviderBookingSettings with _$ProviderBookingSettings {
  const ProviderBookingSettings._();

  const factory ProviderBookingSettings({
    @JsonKey(name: 'provider_id') required String providerId,
    @JsonKey(name: 'time_zone') @Default(BookingTime.defaultTimeZone) String timeZone,
    @JsonKey(name: 'accepts_bookings') @Default(true) bool acceptsBookings,

    /// The provider hid their business: it isn't shown anywhere in the
    /// marketplace and can't be booked. Bookings they already have carry on.
    @JsonKey(name: 'hidden_from_marketplace') @Default(false) bool hiddenFromMarketplace,

    /// Bookings paid in the app wait for the provider to accept instead of
    /// confirming instantly. Cash bookings are always requests, whatever this
    /// says (see BookingTerms).
    @JsonKey(name: 'requires_approval') @Default(false) bool requiresApproval,
    @JsonKey(name: 'slot_interval_minutes') @Default(15) int slotIntervalMinutes,
    @JsonKey(name: 'buffer_minutes') @Default(0) int bufferMinutes,
    @JsonKey(name: 'min_notice_minutes') @Default(120) int minNoticeMinutes,
    @JsonKey(name: 'max_advance_days') @Default(60) int maxAdvanceDays,
    @JsonKey(name: 'cancellation_window_hours') @Default(24) int cancellationWindowHours,
    @JsonKey(name: 'cancellation_fee_percent') @Default(0) int cancellationFeePercent,
    @JsonKey(name: 'offers_studio') @Default(true) bool offersStudio,
    @JsonKey(name: 'offers_mobile') @Default(false) bool offersMobile,

    /// How far a mobile provider travels; null means no limit.
    @JsonKey(name: 'travel_radius_km') double? travelRadiusKm,

    /// Moves whenever availability may have changed (see the migration).
    @JsonKey(name: 'availability_version') @Default(0) int availabilityVersion,

    /// The provider's choice to take cash. Ignored while card payments aren't
    /// ready: cash is then always accepted (see [takesCash]).
    @JsonKey(name: 'accepts_cash') @Default(true) bool acceptsCash,

    /// The provider's choice to take payment in the app.
    @JsonKey(name: 'accepts_card') @Default(true) bool acceptsCard,

    /// Set by the server once the provider's Stripe account can receive payouts.
    @JsonKey(name: 'card_ready') @Default(false) bool cardReady,
  }) = _ProviderBookingSettings;

  factory ProviderBookingSettings.fromJson(Map<String, dynamic> json) => _$ProviderBookingSettingsFromJson(json);

  /// Clients can make new bookings: not paused and not hidden. The server
  /// decides (`private.is_unlisted`); this only explains it up front.
  bool get takesNewBookings => acceptsBookings && !hiddenFromMarketplace;

  /// Last day a client may book, counted from [today] (provider-local).
  DateTime lastBookableDay(DateTime today) => today.add(Duration(days: maxAdvanceDays));

  /// Clients can pay in the app. Mirrors `private.provider_takes_card`.
  bool get takesCard => acceptsCard && cardReady;

  /// Clients can pay cash. Mirrors `private.provider_takes_cash`: always true
  /// while card payments aren't available, so a provider is never unbookable.
  bool get takesCash => acceptsCash || !takesCard;
}
