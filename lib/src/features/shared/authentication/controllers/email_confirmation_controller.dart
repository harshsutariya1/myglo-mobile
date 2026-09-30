import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/auth_repository.dart';

part 'email_confirmation_controller.g.dart';

/// Drives account creation with an emailed verification code.
///
/// The state is `true` once a code has been sent. Verifying and resending do
/// not change the state, so the code-entry UI stays on screen while they run
/// (the screen tracks their busy flags itself). Errors are thrown to the
/// caller, which maps them to user-facing text.
@riverpod
class EmailConfirmationController extends _$EmailConfirmationController {
  @override
  FutureOr<bool> build() {
    return false; // false means no code sent yet
  }

  Future<void> signUp({required String email, required String password}) async {
    AppLogger.d('EmailConfirmationController: Triggering registration for $email', tag: 'EmailConfirmation');
    state = const AsyncLoading();
    try {
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.signUp(email: email, password: password);
      AppLogger.i('EmailConfirmationController: Verification code emailed to $email', tag: 'EmailConfirmation');
      state = const AsyncData(true);
    } on AuthException catch (e, st) {
      AppLogger.w('EmailConfirmationController: AuthException in signUp: ${e.message}', tag: 'EmailConfirmation');
      state = AsyncError(e, st);
    } catch (e, st) {
      AppLogger.e('EmailConfirmationController: Error in signUp', tag: 'EmailConfirmation', error: e, stackTrace: st);
      state = AsyncError(e, st);
    }
  }

  /// Confirms the account with [code]. On success the user is signed in.
  Future<AuthResponse> verifyCode({
    required String email,
    required String code,
  }) async {
    AppLogger.d('EmailConfirmationController: Verifying code for $email', tag: 'EmailConfirmation');
    final response = await ref
        .read(authRepositoryProvider)
        .verifySignupCode(email: email, code: code);
    state = const AsyncData(true);
    return response;
  }

  /// Emails a new code (also used to start verification for an existing but
  /// unconfirmed account).
  Future<void> resendCode(String email) async {
    AppLogger.d('EmailConfirmationController: Resending code to $email', tag: 'EmailConfirmation');
    await ref.read(authRepositoryProvider).resendSignupCode(email);
    state = const AsyncData(true);
  }
}
