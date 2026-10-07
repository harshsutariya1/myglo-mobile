// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: type=lint

part of 'booking.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_BookingItem _$BookingItemFromJson(Map<String, dynamic> json) => _BookingItem(
  serviceId: json['service_id'] as String?,
  name: json['name'] as String,
  category: json['category'] as String?,
  durationMinutes: (json['duration_minutes'] as num).toInt(),
  priceCents: (json['price_cents'] as num).toInt(),
);

Map<String, dynamic> _$BookingItemToJson(_BookingItem instance) =>
    <String, dynamic>{
      'service_id': instance.serviceId,
      'name': instance.name,
      'category': instance.category,
      'duration_minutes': instance.durationMinutes,
      'price_cents': instance.priceCents,
    };

_Booking _$BookingFromJson(Map<String, dynamic> json) => _Booking(
  id: json['id'] as String,
  reference: json['reference'] as String,
  clientId: json['client_id'] as String?,
  providerId: json['provider_id'] as String?,
  status: $enumDecode(_$BookingStatusEnumMap, json['status']),
  startsAt: DateTime.parse(json['starts_at'] as String),
  endsAt: DateTime.parse(json['ends_at'] as String),
  timeZone: json['time_zone'] as String,
  startsAtLocal: const WallClockConverter().fromJson(
    json['starts_at_local'] as String,
  ),
  endsAtLocal: const WallClockConverter().fromJson(
    json['ends_at_local'] as String,
  ),
  durationMinutes: (json['duration_minutes'] as num).toInt(),
  locationType: $enumDecode(
    _$BookingLocationTypeEnumMap,
    json['location_type'],
  ),
  addressText: json['address_text'] as String,
  address: json['address'] == null
      ? null
      : ClientAddress.fromJson(json['address'] as Map<String, dynamic>),
  accessNotes: json['access_notes'] as String?,
  latitude: (json['latitude'] as num?)?.toDouble(),
  longitude: (json['longitude'] as num?)?.toDouble(),
  distanceKm: (json['distance_km'] as num?)?.toDouble(),
  providerName: json['provider_name'] as String,
  providerAvatarUrl: json['provider_avatar_url'] as String?,
  clientName: json['client_name'] as String,
  clientAvatarUrl: json['client_avatar_url'] as String?,
  clientPhone: json['client_phone'] as String,
  clientNotes: json['client_notes'] as String?,
  subtotalCents: (json['subtotal_cents'] as num).toInt(),
  totalCents: (json['total_cents'] as num).toInt(),
  currency: json['currency'] as String? ?? 'AUD',
  paymentMethod: $enumDecode(_$PaymentMethodEnumMap, json['payment_method']),
  paymentStatus: $enumDecode(_$PaymentStatusEnumMap, json['payment_status']),
  requiresApproval: json['requires_approval'] as bool,
  cancellationWindowHours: (json['cancellation_window_hours'] as num).toInt(),
  cancellationFeePercent: (json['cancellation_fee_percent'] as num).toInt(),
  freeCancellationUntil: DateTime.parse(
    json['free_cancellation_until'] as String,
  ),
  declineReason: json['decline_reason'] as String?,
  respondedAt: json['responded_at'] == null
      ? null
      : DateTime.parse(json['responded_at'] as String),
  cancelledBy: $enumDecodeNullable(_$CancelledByEnumMap, json['cancelled_by']),
  cancellationReason: json['cancellation_reason'] as String?,
  cancelledAt: json['cancelled_at'] == null
      ? null
      : DateTime.parse(json['cancelled_at'] as String),
  lateCancellation: json['late_cancellation'] as bool? ?? false,
  cancellationFeeCents: (json['cancellation_fee_cents'] as num?)?.toInt() ?? 0,
  completedAt: json['completed_at'] == null
      ? null
      : DateTime.parse(json['completed_at'] as String),
  createdAt: DateTime.parse(json['created_at'] as String),
  updatedAt: DateTime.parse(json['updated_at'] as String),
  items:
      (json['items'] as List<dynamic>?)
          ?.map((e) => BookingItem.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const <BookingItem>[],
  platformFeeCents: (json['platform_fee_cents'] as num?)?.toInt(),
);

Map<String, dynamic> _$BookingToJson(_Booking instance) => <String, dynamic>{
  'id': instance.id,
  'reference': instance.reference,
  'client_id': instance.clientId,
  'provider_id': instance.providerId,
  'status': _$BookingStatusEnumMap[instance.status]!,
  'starts_at': instance.startsAt.toIso8601String(),
  'ends_at': instance.endsAt.toIso8601String(),
  'time_zone': instance.timeZone,
  'starts_at_local': const WallClockConverter().toJson(instance.startsAtLocal),
  'ends_at_local': const WallClockConverter().toJson(instance.endsAtLocal),
  'duration_minutes': instance.durationMinutes,
  'location_type': _$BookingLocationTypeEnumMap[instance.locationType]!,
  'address_text': instance.addressText,
  'address': instance.address?.toJson(),
  'access_notes': instance.accessNotes,
  'latitude': instance.latitude,
  'longitude': instance.longitude,
  'distance_km': instance.distanceKm,
  'provider_name': instance.providerName,
  'provider_avatar_url': instance.providerAvatarUrl,
  'client_name': instance.clientName,
  'client_avatar_url': instance.clientAvatarUrl,
  'client_phone': instance.clientPhone,
  'client_notes': instance.clientNotes,
  'subtotal_cents': instance.subtotalCents,
  'total_cents': instance.totalCents,
  'currency': instance.currency,
  'payment_method': _$PaymentMethodEnumMap[instance.paymentMethod]!,
  'payment_status': _$PaymentStatusEnumMap[instance.paymentStatus]!,
  'requires_approval': instance.requiresApproval,
  'cancellation_window_hours': instance.cancellationWindowHours,
  'cancellation_fee_percent': instance.cancellationFeePercent,
  'free_cancellation_until': instance.freeCancellationUntil.toIso8601String(),
  'decline_reason': instance.declineReason,
  'responded_at': instance.respondedAt?.toIso8601String(),
  'cancelled_by': _$CancelledByEnumMap[instance.cancelledBy],
  'cancellation_reason': instance.cancellationReason,
  'cancelled_at': instance.cancelledAt?.toIso8601String(),
  'late_cancellation': instance.lateCancellation,
  'cancellation_fee_cents': instance.cancellationFeeCents,
  'completed_at': instance.completedAt?.toIso8601String(),
  'created_at': instance.createdAt.toIso8601String(),
  'updated_at': instance.updatedAt.toIso8601String(),
  'items': instance.items.map((e) => e.toJson()).toList(),
  'platform_fee_cents': instance.platformFeeCents,
};

const _$BookingStatusEnumMap = {
  BookingStatus.pending: 'pending',
  BookingStatus.confirmed: 'confirmed',
  BookingStatus.declined: 'declined',
  BookingStatus.cancelled: 'cancelled',
  BookingStatus.completed: 'completed',
  BookingStatus.noShow: 'no_show',
  BookingStatus.expired: 'expired',
};

const _$BookingLocationTypeEnumMap = {
  BookingLocationType.studio: 'studio',
  BookingLocationType.client: 'client',
};

const _$PaymentMethodEnumMap = {
  PaymentMethod.cash: 'cash',
  PaymentMethod.card: 'card',
  PaymentMethod.applePay: 'apple_pay',
  PaymentMethod.googlePay: 'google_pay',
  PaymentMethod.afterpay: 'afterpay',
};

const _$PaymentStatusEnumMap = {
  PaymentStatus.pending: 'pending',
  PaymentStatus.paid: 'paid',
  PaymentStatus.refunded: 'refunded',
  PaymentStatus.voided: 'void',
};

const _$CancelledByEnumMap = {
  CancelledBy.client: 'client',
  CancelledBy.provider: 'provider',
  CancelledBy.system: 'system',
};
