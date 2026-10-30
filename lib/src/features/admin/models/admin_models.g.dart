// GENERATED CODE - DO NOT MODIFY BY HAND

// ignore_for_file: type=lint

part of 'admin_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AdminStatus _$AdminStatusFromJson(Map<String, dynamic> json) => _AdminStatus(
  isAdmin: json['is_admin'] as bool? ?? false,
  displayName: json['display_name'] as String?,
  aal: json['aal'] as String?,
  totpVerifiedAt: json['totp_verified_at'] == null
      ? null
      : DateTime.parse(json['totp_verified_at'] as String),
  sessionExpiresAt: json['session_expires_at'] == null
      ? null
      : DateTime.parse(json['session_expires_at'] as String),
  reauthSeconds: (json['reauth_seconds'] as num?)?.toInt() ?? 300,
);

Map<String, dynamic> _$AdminStatusToJson(_AdminStatus instance) =>
    <String, dynamic>{
      'is_admin': instance.isAdmin,
      'display_name': instance.displayName,
      'aal': instance.aal,
      'totp_verified_at': instance.totpVerifiedAt?.toIso8601String(),
      'session_expires_at': instance.sessionExpiresAt?.toIso8601String(),
      'reauth_seconds': instance.reauthSeconds,
    };

_AdminDashboard _$AdminDashboardFromJson(Map<String, dynamic> json) =>
    _AdminDashboard(
      providers: (json['providers'] as num?)?.toInt() ?? 0,
      clients: (json['clients'] as num?)?.toInt() ?? 0,
      newUsers7d: (json['new_users_7d'] as num?)?.toInt() ?? 0,
      bookingsUpcoming: (json['bookings_upcoming'] as num?)?.toInt() ?? 0,
      bookingsPending: (json['bookings_pending'] as num?)?.toInt() ?? 0,
      bookings7d: (json['bookings_7d'] as num?)?.toInt() ?? 0,
      failedJobs: (json['failed_jobs'] as num?)?.toInt() ?? 0,
      generatedAt: json['generated_at'] == null
          ? null
          : DateTime.parse(json['generated_at'] as String),
    );

Map<String, dynamic> _$AdminDashboardToJson(_AdminDashboard instance) =>
    <String, dynamic>{
      'providers': instance.providers,
      'clients': instance.clients,
      'new_users_7d': instance.newUsers7d,
      'bookings_upcoming': instance.bookingsUpcoming,
      'bookings_pending': instance.bookingsPending,
      'bookings_7d': instance.bookings7d,
      'failed_jobs': instance.failedJobs,
      'generated_at': instance.generatedAt?.toIso8601String(),
    };

_PlatformSettings _$PlatformSettingsFromJson(
  Map<String, dynamic> json,
) => _PlatformSettings(
  platformFeePercent: (json['platform_fee_percent'] as num?)?.toDouble() ?? 0,
  feeFreeDays: (json['fee_free_days'] as num?)?.toInt() ?? 0,
  defaultCancellationWindowHours:
      (json['default_cancellation_window_hours'] as num?)?.toInt() ?? 24,
  defaultCancellationFeePercent:
      (json['default_cancellation_fee_percent'] as num?)?.toInt() ?? 0,
  mapProvider: json['map_provider'] as String? ?? 'google',
  checkoutHoldMinutes: (json['checkout_hold_minutes'] as num?)?.toInt() ?? 15,
  cardRequestResponseHours:
      (json['card_request_response_hours'] as num?)?.toInt() ?? 144,
  cardMaxAdvanceDays: (json['card_max_advance_days'] as num?)?.toInt() ?? 60,
  autoCompleteAfterHours:
      (json['auto_complete_after_hours'] as num?)?.toInt() ?? 24,
  reportWindowHours: (json['report_window_hours'] as num?)?.toInt() ?? 24,
  updatedAt: json['updated_at'] == null
      ? null
      : DateTime.parse(json['updated_at'] as String),
  updatedBy: json['updated_by'] as String?,
);

Map<String, dynamic> _$PlatformSettingsToJson(
  _PlatformSettings instance,
) => <String, dynamic>{
  'platform_fee_percent': instance.platformFeePercent,
  'fee_free_days': instance.feeFreeDays,
  'default_cancellation_window_hours': instance.defaultCancellationWindowHours,
  'default_cancellation_fee_percent': instance.defaultCancellationFeePercent,
  'map_provider': instance.mapProvider,
  'checkout_hold_minutes': instance.checkoutHoldMinutes,
  'card_request_response_hours': instance.cardRequestResponseHours,
  'card_max_advance_days': instance.cardMaxAdvanceDays,
  'auto_complete_after_hours': instance.autoCompleteAfterHours,
  'report_window_hours': instance.reportWindowHours,
  'updated_at': instance.updatedAt?.toIso8601String(),
  'updated_by': instance.updatedBy,
};

_AdminUserSummary _$AdminUserSummaryFromJson(Map<String, dynamic> json) =>
    _AdminUserSummary(
      userId: json['user_id'] as String,
      role: json['role'] as String,
      displayName: json['display_name'] as String?,
      businessName: json['business_name'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      avatarUrl: json['avatar_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastSignIn: json['last_sign_in'] == null
          ? null
          : DateTime.parse(json['last_sign_in'] as String),
    );

Map<String, dynamic> _$AdminUserSummaryToJson(_AdminUserSummary instance) =>
    <String, dynamic>{
      'user_id': instance.userId,
      'role': instance.role,
      'display_name': instance.displayName,
      'business_name': instance.businessName,
      'email': instance.email,
      'phone': instance.phone,
      'avatar_url': instance.avatarUrl,
      'created_at': instance.createdAt.toIso8601String(),
      'last_sign_in': instance.lastSignIn?.toIso8601String(),
    };

_AdminBookingCounts _$AdminBookingCountsFromJson(Map<String, dynamic> json) =>
    _AdminBookingCounts(
      total: (json['total'] as num?)?.toInt() ?? 0,
      upcoming: (json['upcoming'] as num?)?.toInt() ?? 0,
      completed: (json['completed'] as num?)?.toInt() ?? 0,
      cancelled: (json['cancelled'] as num?)?.toInt() ?? 0,
      noShow: (json['no_show'] as num?)?.toInt() ?? 0,
      declined: (json['declined'] as num?)?.toInt() ?? 0,
    );

Map<String, dynamic> _$AdminBookingCountsToJson(_AdminBookingCounts instance) =>
    <String, dynamic>{
      'total': instance.total,
      'upcoming': instance.upcoming,
      'completed': instance.completed,
      'cancelled': instance.cancelled,
      'no_show': instance.noShow,
      'declined': instance.declined,
    };

_AdminBookingSummary _$AdminBookingSummaryFromJson(Map<String, dynamic> json) =>
    _AdminBookingSummary(
      id: json['id'] as String,
      reference: json['reference'] as String,
      status: json['status'] as String,
      startsAt: DateTime.parse(json['starts_at'] as String),
      totalCents: (json['total_cents'] as num?)?.toInt() ?? 0,
      paymentMethod: json['payment_method'] as String,
      paymentStatus: json['payment_status'] as String,
      otherParty: json['other_party'] as String?,
    );

Map<String, dynamic> _$AdminBookingSummaryToJson(
  _AdminBookingSummary instance,
) => <String, dynamic>{
  'id': instance.id,
  'reference': instance.reference,
  'status': instance.status,
  'starts_at': instance.startsAt.toIso8601String(),
  'total_cents': instance.totalCents,
  'payment_method': instance.paymentMethod,
  'payment_status': instance.paymentStatus,
  'other_party': instance.otherParty,
};

_AdminUserDetail _$AdminUserDetailFromJson(
  Map<String, dynamic> json,
) => _AdminUserDetail(
  userId: json['user_id'] as String,
  role: json['role'] as String,
  firstName: json['first_name'] as String?,
  lastName: json['last_name'] as String?,
  businessName: json['business_name'] as String?,
  email: json['email'] as String?,
  emailConfirmedAt: json['email_confirmed_at'] == null
      ? null
      : DateTime.parse(json['email_confirmed_at'] as String),
  phone: json['phone'] as String?,
  avatarUrl: json['avatar_url'] as String?,
  address: json['address'] as String?,
  createdAt: DateTime.parse(json['created_at'] as String),
  lastSignIn: json['last_sign_in'] == null
      ? null
      : DateTime.parse(json['last_sign_in'] as String),
  bannedUntil: json['banned_until'] == null
      ? null
      : DateTime.parse(json['banned_until'] as String),
  bookings: json['bookings'] == null
      ? const AdminBookingCounts()
      : AdminBookingCounts.fromJson(json['bookings'] as Map<String, dynamic>),
  bookingSettings: json['booking_settings'] as Map<String, dynamic>?,
  recentBookings:
      (json['recent_bookings'] as List<dynamic>?)
          ?.map((e) => AdminBookingSummary.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$AdminUserDetailToJson(
  _AdminUserDetail instance,
) => <String, dynamic>{
  'user_id': instance.userId,
  'role': instance.role,
  'first_name': instance.firstName,
  'last_name': instance.lastName,
  'business_name': instance.businessName,
  'email': instance.email,
  'email_confirmed_at': instance.emailConfirmedAt?.toIso8601String(),
  'phone': instance.phone,
  'avatar_url': instance.avatarUrl,
  'address': instance.address,
  'created_at': instance.createdAt.toIso8601String(),
  'last_sign_in': instance.lastSignIn?.toIso8601String(),
  'banned_until': instance.bannedUntil?.toIso8601String(),
  'bookings': instance.bookings.toJson(),
  'booking_settings': instance.bookingSettings,
  'recent_bookings': instance.recentBookings.map((e) => e.toJson()).toList(),
};

_AuditEntry _$AuditEntryFromJson(Map<String, dynamic> json) => _AuditEntry(
  id: (json['id'] as num).toInt(),
  adminEmail: json['admin_email'] as String?,
  adminName: json['admin_name'] as String?,
  action: json['action'] as String,
  targetType: json['target_type'] as String?,
  targetId: json['target_id'] as String?,
  reason: json['reason'] as String?,
  before: json['before'],
  after: json['after'],
  createdAt: DateTime.parse(json['created_at'] as String),
);

Map<String, dynamic> _$AuditEntryToJson(_AuditEntry instance) =>
    <String, dynamic>{
      'id': instance.id,
      'admin_email': instance.adminEmail,
      'admin_name': instance.adminName,
      'action': instance.action,
      'target_type': instance.targetType,
      'target_id': instance.targetId,
      'reason': instance.reason,
      'before': instance.before,
      'after': instance.after,
      'created_at': instance.createdAt.toIso8601String(),
    };

_AdminServiceCity _$AdminServiceCityFromJson(Map<String, dynamic> json) =>
    _AdminServiceCity(
      cityId: json['city_id'] as String,
      name: json['name'] as String,
      state: json['state'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      radiusM: (json['radius_m'] as num).toInt(),
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      providerCount: (json['provider_count'] as num?)?.toInt() ?? 0,
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$AdminServiceCityToJson(_AdminServiceCity instance) =>
    <String, dynamic>{
      'city_id': instance.cityId,
      'name': instance.name,
      'state': instance.state,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'radius_m': instance.radiusM,
      'sort_order': instance.sortOrder,
      'is_active': instance.isActive,
      'provider_count': instance.providerCount,
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
