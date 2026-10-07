import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/realtime/postgres_changes.dart';
import '../../../../core/utils/app_logger.dart';
import '../../authentication/models/auth_repository.dart';
import 'app_notification.dart';

final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  return NotificationsRepository(ref.watch(supabaseClientProvider));
});

/// The signed-in user's in-app notifications. Row level security limits
/// every query to the user's own rows; only `read_at` is writable.
class NotificationsRepository {
  NotificationsRepository(this._client);

  final SupabaseClient _client;

  static const _table = 'notifications';
  static const _tag = 'NotificationsRepository';

  Future<List<AppNotification>> fetchLatest(String userId, {int limit = 60}) async {
    final sw = Stopwatch()..start();
    try {
      final rows = await _client
          .from(_table)
          .select()
          .eq('recipient_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      sw.stop();
      AppLogger.api('$_table.select', count: rows.length, duration: sw.elapsed);
      return [for (final row in rows) AppNotification.fromJson(row)];
    } catch (e, st) {
      AppLogger.e('Failed to load notifications', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Marks [ids] read, or every unread notification when null.
  Future<void> markRead({List<String>? ids}) async {
    try {
      await _client.rpc('mark_notifications_read', params: {'p_ids': ids});
    } catch (e, st) {
      AppLogger.e('Failed to mark notifications read', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> delete(String id) async {
    try {
      await _client.from(_table).delete().eq('id', id);
    } catch (e, st) {
      AppLogger.e('Failed to delete notification $id', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  /// New and updated notifications for [userId], live.
  Stream<RealtimeChange> watch(String userId) => watchPostgresChanges(
        _client,
        table: _table,
        filter: PostgresChangeFilter(type: PostgresChangeFilterType.eq, column: 'recipient_id', value: userId),
      );
}
