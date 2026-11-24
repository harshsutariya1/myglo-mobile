import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/network_error.dart';
import '../../authentication/models/auth_repository.dart';
import 'blocked_user.dart';

final blocksRepositoryProvider = Provider<BlocksRepository>((ref) => BlocksRepository(ref.watch(supabaseClientProvider)));

/// Why blocking or unblocking didn't work, in words the user can read.
class BlockFailure implements Exception {
  const BlockFailure(this.message, {this.expected = true});

  final String message;

  /// The user can fix it (offline, blocked too many); anything else is
  /// reported to Sentry.
  final bool expected;

  static BlockFailure from(Object error) {
    if (isConnectivityError(error)) {
      return const BlockFailure("You're offline. Check your connection and try again.");
    }
    if (error is PostgrestException) {
      switch (error.message) {
        case 'too_many_blocks':
          return const BlockFailure("You've blocked the most accounts Myglo allows. Unblock someone first.");
        case 'user_not_found':
          return const BlockFailure('That account no longer exists.');
        case 'account_suspended':
          return const BlockFailure('Your account is suspended.');
      }
    }
    return const BlockFailure('Something went wrong. Please try again.', expected: false);
  }

  @override
  String toString() => 'BlockFailure($message)';
}

/// Blocking accounts (`block_user`, `unblock_user`, `list_blocked_users`).
/// The server applies a block both ways: posts, comments, follows and new
/// bookings between the two accounts. The person blocked isn't told.
class BlocksRepository {
  BlocksRepository(this._client);

  final SupabaseClient _client;

  static const _tag = 'Blocks';

  Future<void> block(String userId) => _run('block_user', {'p_user_id': userId});

  Future<void> unblock(String userId) => _run('unblock_user', {'p_user_id': userId});

  Future<List<BlockedUser>> list() async {
    final sw = Stopwatch()..start();
    try {
      final rows = await _client.rpc('list_blocked_users') as List<dynamic>;
      sw.stop();
      AppLogger.api('rpc.list_blocked_users', count: rows.length, duration: sw.elapsed);
      return [for (final row in rows) BlockedUser.fromJson(Map<String, dynamic>.from(row as Map))];
    } catch (e, st) {
      AppLogger.e('Loading blocked accounts failed', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> _run(String fn, Map<String, dynamic> params) async {
    final sw = Stopwatch()..start();
    try {
      await _client.rpc(fn, params: params);
      sw.stop();
      AppLogger.api('rpc.$fn', duration: sw.elapsed);
    } catch (e, st) {
      final failure = BlockFailure.from(e);
      if (failure.expected) {
        AppLogger.w('$fn refused: ${failure.message}', tag: _tag);
      } else {
        AppLogger.e('$fn failed', tag: _tag, error: e, stackTrace: st);
      }
      Error.throwWithStackTrace(failure, st);
    }
  }
}
