import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_logger.dart';
import '../../shared/authentication/models/auth_repository.dart';
import '../../shared/reports/models/report.dart';
import 'admin_failure.dart';
import 'admin_models.dart';
import 'admin_moderation.dart';
import 'admin_payments.dart';

final adminRepositoryProvider = Provider<AdminRepository>(
  (ref) => AdminRepository(ref.watch(supabaseClientProvider)),
);

/// Admin data and actions. Every call is an `admin_*` RPC that checks, on
/// the server, that the caller is an admin with a valid two-factor session
/// (and a fresh code for sensitive changes); nothing here grants access.
class AdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;

  /// The caller's own admin status. Safe for anyone to call.
  Future<AdminStatus> getStatus() async {
    final row = await _rpc('get_admin_status');
    return AdminStatus.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<AdminDashboard> getDashboard() async {
    final row = await _rpc('admin_get_dashboard');
    return AdminDashboard.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<PlatformSettings> getPlatformSettings() async {
    final row = await _rpc('admin_get_platform_settings');
    return PlatformSettings.fromJson(Map<String, dynamic>.from(row as Map));
  }

  /// Applies [changes] (only the keys that changed). Needs a fresh two-factor
  /// code; the server audits it with [reason].
  Future<PlatformSettings> updatePlatformSettings(Map<String, Object> changes, {required String reason}) async {
    final row = await _rpc(
      'admin_update_platform_settings',
      params: {'p_changes': changes, 'p_reason': reason},
      detail: changes.keys.join(','),
    );
    return PlatformSettings.fromJson(Map<String, dynamic>.from(row as Map));
  }

  Future<List<AdminUserSummary>> searchUsers({String? query, String? role, int limit = 30, int offset = 0}) async {
    final rows = await _rpc('admin_search_users', params: {
      'p_query': (query?.trim().isEmpty ?? true) ? null : query!.trim(),
      'p_role': role,
      'p_limit': limit,
      'p_offset': offset,
    });
    return [for (final row in rows as List) AdminUserSummary.fromJson(Map<String, dynamic>.from(row as Map))];
  }

  Future<AdminUserDetail> getUser(String userId) async {
    final row = await _rpc('admin_get_user', params: {'p_user_id': userId}, detail: userId);
    return AdminUserDetail.fromJson(Map<String, dynamic>.from(row as Map));
  }

  /// A provider's Stripe payout account as Myglo last saw it, or null if they
  /// haven't started setting one up.
  Future<Map<String, dynamic>?> getPayoutAccount(String userId) async {
    final row = await _rpc('admin_get_payout_account', params: {'p_user_id': userId}, detail: userId);
    return row == null ? null : Map<String, dynamic>.from(row as Map);
  }

  /// Newest first; pass the last entry's id as [beforeId] for the next page.
  Future<List<AuditEntry>> listAuditLog({int? beforeId, int limit = 50, String? targetType, String? targetId}) async {
    final rows = await _rpc('admin_list_audit_log', params: {
      'p_before_id': beforeId,
      'p_limit': limit,
      'p_target_type': targetType,
      'p_target_id': targetId,
    });
    return [for (final row in rows as List) AuditEntry.fromJson(Map<String, dynamic>.from(row as Map))];
  }

  Future<List<AdminServiceCity>> listServiceCities() async {
    final rows = await _rpc('admin_list_service_cities');
    return [for (final row in rows as List) AdminServiceCity.fromJson(Map<String, dynamic>.from(row as Map))];
  }

  /// Adds a city ([cityId] null) or edits one. Returns its id.
  Future<String> saveServiceCity({
    String? cityId,
    required String name,
    required String state,
    required double latitude,
    required double longitude,
    required int radiusM,
    required bool isActive,
    String? reason,
  }) async {
    final id = await _rpc('admin_save_service_city', params: {
      'p_city_id': cityId,
      'p_name': name,
      'p_state': state,
      'p_latitude': latitude,
      'p_longitude': longitude,
      'p_radius_m': radiusM,
      'p_is_active': isActive,
      'p_reason': reason,
    }, detail: cityId ?? 'new');
    return id as String;
  }

  Future<void> reorderServiceCities(List<String> cityIds) =>
      _rpc('admin_reorder_service_cities', params: {'p_city_ids': cityIds});

  Future<AdminPaymentsOverview> paymentsOverview() async =>
      AdminPaymentsOverview.fromJson(Map<String, dynamic>.from(await _rpc('admin_payments_overview') as Map));

  /// Bookings paid in the app, newest first. [filter]: `held`, `failed`,
  /// `disputed`, `refunded`, or null for all.
  Future<List<AdminPaymentSummary>> listPayments({String? filter, String? query, int limit = 30, int offset = 0}) async {
    final rows = await _rpc('admin_list_payments', params: {
      'p_filter': filter,
      'p_query': (query?.trim().isEmpty ?? true) ? null : query!.trim(),
      'p_limit': limit,
      'p_offset': offset,
    });
    return [for (final row in rows as List) AdminPaymentSummary.fromJson(Map<String, dynamic>.from(row as Map))];
  }

  Future<AdminBookingPayment> getBookingPayment(String bookingId) async => AdminBookingPayment.fromJson(
        Map<String, dynamic>.from(
          await _rpc('admin_get_booking_payment', params: {'p_booking_id': bookingId}, detail: bookingId) as Map,
        ),
      );

  /// Refunds [amountCents]; with [recover], takes the provider's part back
  /// if they were already paid. Needs a fresh two-factor code.
  Future<void> refundBooking(String bookingId, {required int amountCents, required String reason, bool recover = true}) =>
      _rpc('admin_refund_booking', params: {
        'p_booking_id': bookingId,
        'p_amount_cents': amountCents,
        'p_reason': reason,
        'p_recover': recover,
      }, detail: bookingId);

  /// Cancels on Myglo's behalf with a full refund. Needs a fresh two-factor code.
  Future<void> cancelBooking(String bookingId, {required String reason}) =>
      _rpc('admin_cancel_booking', params: {'p_booking_id': bookingId, 'p_reason': reason}, detail: bookingId);

  /// Holds (or lets go of) the provider's share. Needs a fresh two-factor code.
  Future<void> setSettlementHold(String bookingId, {required bool hold, required String reason}) => _rpc(
        'admin_set_settlement_hold',
        params: {'p_booking_id': bookingId, 'p_hold': hold, 'p_reason': reason},
        detail: bookingId,
      );

  Future<void> retryJob(String jobId, {required String reason}) =>
      _rpc('admin_retry_job', params: {'p_job_id': jobId, 'p_reason': reason}, detail: jobId);

  /// Reports newest first. [status]: `open`, `resolved`, `dismissed`, or
  /// null for all.
  Future<List<AdminReport>> listReports({String? status = 'open', int limit = 30, int offset = 0}) async {
    final rows = await _rpc('admin_list_reports', params: {'p_status': status, 'p_limit': limit, 'p_offset': offset});
    return [for (final row in rows as List) AdminReport.fromJson(Map<String, dynamic>.from(row as Map))];
  }

  /// Closes a report as `resolved` or `dismissed`. A booking with no other
  /// open reports gets its provider's share released.
  Future<void> resolveReport(String reportId, {required bool dismiss, required String note}) => _rpc(
        'admin_resolve_report',
        params: {'p_report_id': reportId, 'p_status': dismiss ? 'dismissed' : 'resolved', 'p_note': note},
        detail: reportId,
      );

  /// Hides (or shows again) a post, comment or review. Needs a fresh
  /// two-factor code.
  Future<void> setContentHidden(ReportTarget target, String id, {required bool hidden, required String reason}) => _rpc(
        'admin_set_content_hidden',
        params: {'p_target_type': target.key, 'p_target_id': id, 'p_hidden': hidden, 'p_reason': reason},
        detail: '${target.key}=$id',
      );

  Future<AdminModerationState> getModerationState(String userId) async => AdminModerationState.fromJson(
        Map<String, dynamic>.from(
          await _rpc('admin_get_moderation_state', params: {'p_user_id': userId}, detail: userId) as Map,
        ),
      );

  /// Suspends an account (or lifts it), optionally cancelling and fully
  /// refunding its upcoming bookings. Returns how many were cancelled.
  /// Needs a fresh two-factor code.
  Future<int> setSuspension(
    String userId, {
    required bool suspended,
    required String reason,
    bool cancelUpcoming = false,
  }) async {
    final cancelled = await _rpc('admin_set_suspension', params: {
      'p_user_id': userId,
      'p_suspended': suspended,
      'p_reason': reason,
      'p_cancel_upcoming': cancelUpcoming,
    }, detail: userId);
    return cancelled is num ? cancelled.toInt() : 0;
  }

  /// Stops (or lets again) clients booking a provider. Needs a fresh
  /// two-factor code.
  Future<void> setBookingsBlocked(String providerId, {required bool blocked, required String reason}) => _rpc(
        'admin_set_bookings_blocked',
        params: {'p_provider_id': providerId, 'p_blocked': blocked, 'p_reason': reason},
        detail: providerId,
      );

  Future<dynamic> _rpc(String fn, {Map<String, dynamic>? params, String? detail}) async {
    final sw = Stopwatch()..start();
    try {
      final result = await _client.rpc(fn, params: params);
      sw.stop();
      AppLogger.api('rpc.$fn', endpoint: detail, duration: sw.elapsed);
      return result;
    } catch (e, st) {
      throwAdminError(e, st, action: fn);
    }
  }
}
