import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/auth_repository.dart';

part 'email_confirmation_controller.g.dart';

@riverpod
class EmailConfirmationController extends _$EmailConfirmationController {
  @override
  FutureOr<bool> build() {
    return false; // false means email not sent yet
  }

  Future<void> signUp({required String email, required String password}) async {
    state = const AsyncLoading();
    try {
      final authRepository = ref.read(authRepositoryProvider);
      await authRepository.signUp(
        email: email,
        password: password,
        emailRedirectTo: 'https://www.myglo.app/welcome',
      );
      state = const AsyncData(true); // true means email sent
    } on AuthException catch (e, st) {
      state = AsyncError(e, st);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }

  Future<AuthResponse?> checkConfirmation({
    required String email,
    required String password,
  }) async {
    state = const AsyncLoading();
    try {
      final authRepository = ref.read(authRepositoryProvider);
      final response = await authRepository.signInWithPassword(
        email: email,
        password: password,
      );
      state = const AsyncData(true);
      return response;
    } on AuthException catch (e, st) {
      state = AsyncError(e, st);
      if (e.message.contains('Email not confirmed')) {
        rethrow; // Reraise for UI to catch and show popup
      }
      return null;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}
