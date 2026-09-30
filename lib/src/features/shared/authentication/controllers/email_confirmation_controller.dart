import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/auth_repository.dart';

part 'email_confirmation_controller.g.dart';

@riverpod
class EmailConfirmationController extends _$EmailConfirmationController {
  @override
  FutureOr<bool> build() {
    return false; // false means email not sent yet
  }

  Future<void> signUp({required String email, required String password}) async {
    AppLogger.d('EmailConfirmationController: Triggering registration for $email', tag: 'EmailConfirmation');
    state = const AsyncLoading();
    try {
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.signUp(
        email: email,
        password: password,
        emailRedirectTo: AppConfig.emailConfirmationRedirectUrl,
      );
      AppLogger.i('EmailConfirmationController: Verification email sent successfully to $email', tag: 'EmailConfirmation');
      state = const AsyncData(true);
    } on AuthException catch (e, st) {
      AppLogger.w('EmailConfirmationController: AuthException in signUp: ${e.message}', tag: 'EmailConfirmation');
      state = AsyncError(e, st);
    } catch (e, st) {
      AppLogger.e('EmailConfirmationController: Error in signUp', tag: 'EmailConfirmation', error: e, stackTrace: st);
      state = AsyncError(e, st);
    }
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    AppLogger.d('EmailConfirmationController: Triggering sign in for $email', tag: 'EmailConfirmation');
    state = const AsyncLoading();
    try {
      final authRepository = ref.read(authRepositoryProvider);
      final response = await authRepository.signInWithPassword(
        email: email,
        password: password,
      );
      AppLogger.i('EmailConfirmationController: Sign in successful for $email', tag: 'EmailConfirmation');
      state = const AsyncData(true);
      return response;
    } on AuthException catch (e, st) {
      AppLogger.w('EmailConfirmationController: AuthException in signIn: ${e.message}', tag: 'EmailConfirmation');
      state = AsyncError(e, st);
      rethrow;
    } catch (e, st) {
      AppLogger.e('EmailConfirmationController: Error in signIn', tag: 'EmailConfirmation', error: e, stackTrace: st);
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
