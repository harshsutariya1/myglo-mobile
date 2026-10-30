import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils/app_logger.dart';
import '../../shared/authentication/models/auth_repository.dart';
import 'admin_failure.dart';
import 'admin_models.dart';

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
