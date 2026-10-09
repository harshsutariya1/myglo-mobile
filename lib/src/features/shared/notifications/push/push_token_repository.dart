import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/app_logger.dart';
import '../../authentication/models/auth_repository.dart';

final pushTokenRepositoryProvider = Provider<PushTokenRepository>((ref) {
  return PushTokenRepository(ref.watch(supabaseClientProvider));
});

/// Links this install's FCM token to the signed-in account, so the server
/// can push booking updates to it. Tokens are only reachable through these
/// RPCs; nobody can read them back.
class PushTokenRepository {
  PushTokenRepository(this._client);

  final SupabaseClient _client;

  static const _tag = 'PushTokenRepository';

  Future<void> register(String token, {required String platform}) async {
    final sw = Stopwatch()..start();
    try {
      await _client.rpc('register_push_token', params: {'p_token': token, 'p_platform': platform});
      sw.stop();
      AppLogger.api('rpc.register_push_token', duration: sw.elapsed);
    } catch (e, st) {
      AppLogger.e('Registering the push token failed', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> unregister(String token) async {
    try {
      await _client.rpc('unregister_push_token', params: {'p_token': token});
    } catch (e, st) {
      AppLogger.e('Unregistering the push token failed', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }
}
