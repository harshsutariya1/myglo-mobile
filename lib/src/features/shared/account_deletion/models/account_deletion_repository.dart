import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/app_logger.dart';
import '../../../../core/utils/network_error.dart';
import '../../authentication/models/auth_repository.dart';
import 'account_deletion_status.dart';

final accountDeletionRepositoryProvider = Provider<AccountDeletionRepository>(
  (ref) => AccountDeletionRepository(ref.watch(supabaseClientProvider)),
);

/// Why deleting the account didn't work.
enum AccountDeletionFailureCode {
  wrongPassword,
  tooManyAttempts,

  /// Something changed since the screen loaded; see [AccountDeletionFailure.blockers].
  blocked,

  /// The password check is too old (over 10 minutes) by the time it arrived.
  reauthRequired,
  signedOut,
  offline,
  unavailable,
  unknown,
}

class AccountDeletionFailure implements Exception {
  const AccountDeletionFailure(this.code, {this.blockers = const []});

  final AccountDeletionFailureCode code;
  final List<AccountDeletionBlocker> blockers;

  static AccountDeletionFailure from(Object error) {
    if (error is AccountDeletionFailure) return error;
    if (error is FunctionException) {
      final details = error.details is Map ? Map<String, dynamic>.from(error.details as Map) : const <String, dynamic>{};
      return switch (details['error']) {
        'deletion_blocked' => AccountDeletionFailure(
            AccountDeletionFailureCode.blocked,
            blockers: [
              for (final b in (details['blockers'] as List? ?? const []))
                if (b is Map) AccountDeletionBlocker.fromJson(Map<String, dynamic>.from(b)),
            ],
          ),
        'reauth_required' => const AccountDeletionFailure(AccountDeletionFailureCode.reauthRequired),
        'not_authenticated' => const AccountDeletionFailure(AccountDeletionFailureCode.signedOut),
        'deletion_unavailable' => const AccountDeletionFailure(AccountDeletionFailureCode.unavailable),
        _ => AccountDeletionFailure(
            error.status >= 500 || error.status == 404
                ? AccountDeletionFailureCode.unavailable
                : AccountDeletionFailureCode.unknown,
          ),
      };
    }
    if (error is AuthException) {
      if (error.code == 'invalid_credentials') {
        return const AccountDeletionFailure(AccountDeletionFailureCode.wrongPassword);
      }
      if (error.code == 'over_request_rate_limit' || error.statusCode == '429') {
        return const AccountDeletionFailure(AccountDeletionFailureCode.tooManyAttempts);
      }
    }
    if (isConnectivityError(error)) return const AccountDeletionFailure(AccountDeletionFailureCode.offline);
    return const AccountDeletionFailure(AccountDeletionFailureCode.unknown);
  }

  String get message => switch (code) {
        AccountDeletionFailureCode.wrongPassword => "That password isn't right.",
        AccountDeletionFailureCode.tooManyAttempts => 'Too many attempts. Wait a few minutes and try again.',
        AccountDeletionFailureCode.blocked => 'Something needs sorting before your account can be deleted.',
        AccountDeletionFailureCode.reauthRequired => 'Please enter your password again.',
        AccountDeletionFailureCode.signedOut => "You've been signed out. Sign in and try again.",
        AccountDeletionFailureCode.offline => "You're offline. Check your connection and try again.",
        AccountDeletionFailureCode.unavailable => "Your account can't be deleted right now. Please try again shortly.",
        AccountDeletionFailureCode.unknown => 'Something went wrong. Please try again.',
      };

  /// Failures the user can fix themselves; anything else is reported.
  bool get isExpected => code != AccountDeletionFailureCode.unavailable && code != AccountDeletionFailureCode.unknown;

  @override
  String toString() => 'AccountDeletionFailure($code)';
}

/// Deleting the signed-in user's account. The database decides what may be
/// deleted and does it (`delete-account` Edge Function); the app only asks.
class AccountDeletionRepository {
  AccountDeletionRepository(this._client);

  final SupabaseClient _client;

  static const _tag = 'AccountDeletion';

  Future<AccountDeletionStatus> getStatus() async {
    final sw = Stopwatch()..start();
    try {
      final row = await _client.rpc('get_my_account_deletion_status');
      sw.stop();
      AppLogger.api('rpc.get_my_account_deletion_status', duration: sw.elapsed);
      return AccountDeletionStatus.fromJson(Map<String, dynamic>.from(row as Map));
    } catch (e, st) {
      AppLogger.e('Loading account deletion status failed', tag: _tag, error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Checks the password by signing in again, which gives the session the
  /// fresh password check the server requires before deleting.
  Future<void> confirmPassword(String password) async {
    final email = _client.auth.currentUser?.email;
    if (email == null || email.isEmpty) {
      throw const AccountDeletionFailure(AccountDeletionFailureCode.signedOut);
    }
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } catch (e, st) {
      final failure = AccountDeletionFailure.from(e);
      if (failure.isExpected) {
        AppLogger.w('Password check before deletion refused: ${failure.code}', tag: _tag);
      } else {
        AppLogger.e('Password check before deletion failed', tag: _tag, error: e, stackTrace: st);
      }
      Error.throwWithStackTrace(failure, st);
    }
  }

  /// Deletes the account. Call [confirmPassword] first.
  Future<void> deleteAccount() async {
    final sw = Stopwatch()..start();
    try {
      await _client.functions.invoke('delete-account', body: const <String, dynamic>{});
      sw.stop();
      AppLogger.api('fn.delete-account', duration: sw.elapsed);
    } catch (e, st) {
      final failure = AccountDeletionFailure.from(e);
      if (failure.isExpected) {
        AppLogger.w('Account deletion refused: ${failure.code}', tag: _tag, error: e);
      } else {
        AppLogger.e('Account deletion failed', tag: _tag, error: e, stackTrace: st);
      }
      Error.throwWithStackTrace(failure, st);
    }
  }
}
