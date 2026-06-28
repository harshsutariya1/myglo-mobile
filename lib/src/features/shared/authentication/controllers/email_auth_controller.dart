import 'dart:developer' as developer;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/auth_repository.dart';

part 'email_auth_controller.g.dart';

@riverpod
class EmailAuthController extends _$EmailAuthController {
  @override
  FutureOr<void> build() {
    // Initial state is data(null) meaning no action is currently in progress
  }

  Future<void> login(String email, String password) async {
    state = const AsyncLoading();
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.signInWithPassword(email: email, password: password);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      // Re-throw to allow the UI to catch it if necessary, or let the UI watch the state.
      // Usually, in Riverpod controllers, throwing is okay if UI catches, but we also save the error in state.
      rethrow;
    }
  }

  Future<void> continueWithEmail(String email) async {
    state = const AsyncLoading();
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.signInWithOtp(email);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<bool> checkUserExists(String email) async {
    state = const AsyncLoading();
    try {
      final repository = ref.read(authRepositoryProvider);
      final exists = await repository.checkUserExists(email);
      state = const AsyncData(null);
      return exists;
    } catch (e, st) {
      developer.log('Error checking user existence in controller: $e');
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
