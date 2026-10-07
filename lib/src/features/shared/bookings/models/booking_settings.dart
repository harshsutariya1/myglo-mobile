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

    /// Requests wait for the provider to accept instead of confirming
    /// instantly.
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
  }) = _ProviderBookingSettings;

  factory ProviderBookingSettings.fromJson(Map<String, dynamic> json) => _$ProviderBookingSettingsFromJson(json);

  /// Last day a client may book, counted from [today] (provider-local).
  DateTime lastBookableDay(DateTime today) => today.add(Duration(days: maxAdvanceDays));
}
