// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: type=lint

part of 'booking_settings.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ProviderBookingSettings _$ProviderBookingSettingsFromJson(
  Map<String, dynamic> json,
) => _ProviderBookingSettings(
  providerId: json['provider_id'] as String,
  timeZone: json['time_zone'] as String? ?? BookingTime.defaultTimeZone,
  acceptsBookings: json['accepts_bookings'] as bool? ?? true,
  requiresApproval: json['requires_approval'] as bool? ?? false,
  slotIntervalMinutes: (json['slot_interval_minutes'] as num?)?.toInt() ?? 15,
  bufferMinutes: (json['buffer_minutes'] as num?)?.toInt() ?? 0,
  minNoticeMinutes: (json['min_notice_minutes'] as num?)?.toInt() ?? 120,
  maxAdvanceDays: (json['max_advance_days'] as num?)?.toInt() ?? 60,
  cancellationWindowHours:
      (json['cancellation_window_hours'] as num?)?.toInt() ?? 24,
  cancellationFeePercent:
      (json['cancellation_fee_percent'] as num?)?.toInt() ?? 0,
  offersStudio: json['offers_studio'] as bool? ?? true,
  offersMobile: json['offers_mobile'] as bool? ?? false,
  travelRadiusKm: (json['travel_radius_km'] as num?)?.toDouble(),
  availabilityVersion: (json['availability_version'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$ProviderBookingSettingsToJson(
  _ProviderBookingSettings instance,
) => <String, dynamic>{
  'provider_id': instance.providerId,
  'time_zone': instance.timeZone,
  'accepts_bookings': instance.acceptsBookings,
  'requires_approval': instance.requiresApproval,
  'slot_interval_minutes': instance.slotIntervalMinutes,
  'buffer_minutes': instance.bufferMinutes,
  'min_notice_minutes': instance.minNoticeMinutes,
  'max_advance_days': instance.maxAdvanceDays,
  'cancellation_window_hours': instance.cancellationWindowHours,
  'cancellation_fee_percent': instance.cancellationFeePercent,
  'offers_studio': instance.offersStudio,
  'offers_mobile': instance.offersMobile,
  'travel_radius_km': instance.travelRadiusKm,
  'availability_version': instance.availabilityVersion,
};
