import 'package:freezed_annotation/freezed_annotation.dart';

part 'admin_models.freezed.dart';
part 'admin_models.g.dart';

/// The signed-in admin's own status (`get_admin_status`).
@freezed
abstract class AdminStatus with _$AdminStatus {
  const AdminStatus._();

  const factory AdminStatus({
    @JsonKey(name: 'is_admin') @Default(false) bool isAdmin,
    @JsonKey(name: 'display_name') String? displayName,
    String? aal,
    @JsonKey(name: 'totp_verified_at') DateTime? totpVerifiedAt,
    @JsonKey(name: 'session_expires_at') DateTime? sessionExpiresAt,
    @JsonKey(name: 'reauth_seconds') @Default(300) int reauthSeconds,
  }) = _AdminStatus;

  factory AdminStatus.fromJson(Map<String, dynamic> json) => _$AdminStatusFromJson(json);
}

/// Headline numbers for the admin home (`admin_get_dashboard`).
@freezed
abstract class AdminDashboard with _$AdminDashboard {
  const factory AdminDashboard({
    @Default(0) int providers,
    @Default(0) int clients,
    @JsonKey(name: 'new_users_7d') @Default(0) int newUsers7d,
    @JsonKey(name: 'bookings_upcoming') @Default(0) int bookingsUpcoming,
    @JsonKey(name: 'bookings_pending') @Default(0) int bookingsPending,
    @JsonKey(name: 'bookings_7d') @Default(0) int bookings7d,
    @JsonKey(name: 'failed_jobs') @Default(0) int failedJobs,
    @JsonKey(name: 'generated_at') DateTime? generatedAt,
  }) = _AdminDashboard;

  factory AdminDashboard.fromJson(Map<String, dynamic> json) => _$AdminDashboardFromJson(json);
}

/// Admin-controlled platform configuration (`admin_get_platform_settings`).
@freezed
abstract class PlatformSettings with _$PlatformSettings {
  const PlatformSettings._();

  const factory PlatformSettings({
    /// Myglo's commission on bookings paid in the app, charged to providers.
    @JsonKey(name: 'platform_fee_percent') @Default(0) double platformFeePercent,

    /// Days without commission, from when a provider's card payments start.
    @JsonKey(name: 'fee_free_days') @Default(0) int feeFreeDays,
    @JsonKey(name: 'default_cancellation_window_hours') @Default(24) int defaultCancellationWindowHours,
    @JsonKey(name: 'default_cancellation_fee_percent') @Default(0) int defaultCancellationFeePercent,
    @JsonKey(name: 'map_provider') @Default('google') String mapProvider,
    @JsonKey(name: 'checkout_hold_minutes') @Default(15) int checkoutHoldMinutes,
    @JsonKey(name: 'card_request_response_hours') @Default(144) int cardRequestResponseHours,
    @JsonKey(name: 'card_max_advance_days') @Default(60) int cardMaxAdvanceDays,
    @JsonKey(name: 'auto_complete_after_hours') @Default(24) int autoCompleteAfterHours,
    @JsonKey(name: 'report_window_hours') @Default(24) int reportWindowHours,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
    @JsonKey(name: 'updated_by') String? updatedBy,
  }) = _PlatformSettings;

  factory PlatformSettings.fromJson(Map<String, dynamic> json) => _$PlatformSettingsFromJson(json);

  /// The editable values keyed as `admin_update_platform_settings` expects.
  Map<String, Object> toChanges() => {
        'platform_fee_percent': platformFeePercent,
        'fee_free_days': feeFreeDays,
        'default_cancellation_window_hours': defaultCancellationWindowHours,
        'default_cancellation_fee_percent': defaultCancellationFeePercent,
        'map_provider': mapProvider,
        'checkout_hold_minutes': checkoutHoldMinutes,
        'card_request_response_hours': cardRequestResponseHours,
        'card_max_advance_days': cardMaxAdvanceDays,
        'auto_complete_after_hours': autoCompleteAfterHours,
        'report_window_hours': reportWindowHours,
      };

  /// The values in [edited] that differ from these.
  Map<String, Object> changesTo(PlatformSettings edited) {
    final before = toChanges();
    return {
      for (final entry in edited.toChanges().entries)
        if (before[entry.key] != entry.value) entry.key: entry.value,
    };
  }
}

/// A client or provider in search results (`admin_search_users`).
@freezed
abstract class AdminUserSummary with _$AdminUserSummary {
  const AdminUserSummary._();

  const factory AdminUserSummary({
    @JsonKey(name: 'user_id') required String userId,
    required String role,
    @JsonKey(name: 'display_name') String? displayName,
    @JsonKey(name: 'business_name') String? businessName,
    String? email,
    String? phone,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'last_sign_in') DateTime? lastSignIn,
  }) = _AdminUserSummary;

  factory AdminUserSummary.fromJson(Map<String, dynamic> json) => _$AdminUserSummaryFromJson(json);

  bool get isProvider => role == 'provider';

  /// Business name for providers, person's name otherwise.
  String get title => (isProvider ? businessName : null) ?? displayName ?? email ?? 'Unnamed account';
}

/// Booking counts for one user.
@freezed
abstract class AdminBookingCounts with _$AdminBookingCounts {
  const factory AdminBookingCounts({
    @Default(0) int total,
    @Default(0) int upcoming,
    @Default(0) int completed,
    @Default(0) int cancelled,
    @JsonKey(name: 'no_show') @Default(0) int noShow,
    @Default(0) int declined,
  }) = _AdminBookingCounts;

  factory AdminBookingCounts.fromJson(Map<String, dynamic> json) => _$AdminBookingCountsFromJson(json);
}

/// A booking in a user's recent activity.
@freezed
abstract class AdminBookingSummary with _$AdminBookingSummary {
  const factory AdminBookingSummary({
    required String id,
    required String reference,
    required String status,
    @JsonKey(name: 'starts_at') required DateTime startsAt,
    @JsonKey(name: 'total_cents') @Default(0) int totalCents,
    @JsonKey(name: 'payment_method') required String paymentMethod,
    @JsonKey(name: 'payment_status') required String paymentStatus,
    @JsonKey(name: 'other_party') String? otherParty,
  }) = _AdminBookingSummary;

  factory AdminBookingSummary.fromJson(Map<String, dynamic> json) => _$AdminBookingSummaryFromJson(json);
}

/// Everything the admin sees about one client or provider (`admin_get_user`).
@freezed
abstract class AdminUserDetail with _$AdminUserDetail {
  const AdminUserDetail._();

  const factory AdminUserDetail({
    @JsonKey(name: 'user_id') required String userId,
    required String role,
    @JsonKey(name: 'first_name') String? firstName,
    @JsonKey(name: 'last_name') String? lastName,
    @JsonKey(name: 'business_name') String? businessName,
    String? email,
    @JsonKey(name: 'email_confirmed_at') DateTime? emailConfirmedAt,
    String? phone,
    @JsonKey(name: 'avatar_url') String? avatarUrl,
    String? address,
    @JsonKey(name: 'created_at') required DateTime createdAt,
    @JsonKey(name: 'last_sign_in') DateTime? lastSignIn,
    @JsonKey(name: 'banned_until') DateTime? bannedUntil,
    @Default(AdminBookingCounts()) AdminBookingCounts bookings,
    @JsonKey(name: 'booking_settings') Map<String, dynamic>? bookingSettings,
    @JsonKey(name: 'recent_bookings') @Default([]) List<AdminBookingSummary> recentBookings,
  }) = _AdminUserDetail;

  factory AdminUserDetail.fromJson(Map<String, dynamic> json) => _$AdminUserDetailFromJson(json);

  bool get isProvider => role == 'provider';

  String? get fullName {
    final name = [firstName, lastName].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).join(' ');
    return name.isEmpty ? null : name;
  }

  String get title => (isProvider ? businessName : null) ?? fullName ?? email ?? 'Unnamed account';
}

/// One entry of the admin audit log (`admin_list_audit_log`).
@freezed
abstract class AuditEntry with _$AuditEntry {
  const AuditEntry._();

  const factory AuditEntry({
    required int id,
    @JsonKey(name: 'admin_email') String? adminEmail,
    @JsonKey(name: 'admin_name') String? adminName,
    required String action,
    @JsonKey(name: 'target_type') String? targetType,
    @JsonKey(name: 'target_id') String? targetId,
    String? reason,
    Object? before,
    Object? after,
    @JsonKey(name: 'created_at') required DateTime createdAt,
  }) = _AuditEntry;

  factory AuditEntry.fromJson(Map<String, dynamic> json) => _$AuditEntryFromJson(json);

  String get actor => adminName ?? adminEmail ?? 'Unknown admin';

  /// Fields whose value changed, as (field, before, after).
  List<(String, Object?, Object?)> get changedFields {
    final b = before is Map ? before as Map : const {};
    final a = after is Map ? after as Map : const {};
    final keys = {...b.keys, ...a.keys}.map((k) => '$k').toList()..sort();
    return [
      for (final key in keys)
        if ('${b[key]}' != '${a[key]}') (key, b[key], a[key]),
    ];
  }
}

/// A browsable city as the admin manages it (`admin_list_service_cities`).
@freezed
abstract class AdminServiceCity with _$AdminServiceCity {
  const factory AdminServiceCity({
    @JsonKey(name: 'city_id') required String cityId,
    required String name,
    required String state,
    required double latitude,
    required double longitude,
    @JsonKey(name: 'radius_m') required int radiusM,
    @JsonKey(name: 'sort_order') @Default(0) int sortOrder,
    @JsonKey(name: 'is_active') @Default(true) bool isActive,
    @JsonKey(name: 'provider_count') @Default(0) int providerCount,
    @JsonKey(name: 'updated_at') DateTime? updatedAt,
  }) = _AdminServiceCity;

  factory AdminServiceCity.fromJson(Map<String, dynamic> json) => _$AdminServiceCityFromJson(json);
}
