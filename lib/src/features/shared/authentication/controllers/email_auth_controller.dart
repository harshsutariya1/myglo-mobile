import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/auth_repository.dart';

part 'email_auth_controller.g.dart';

@riverpod
class EmailAuthController extends _$EmailAuthController {
  @override
  FutureOr<void> build() {
    // Initial state is data(null) meaning no action is currently in progress
  }

  Future<void> login(String email, String password) async {
    AppLogger.d('EmailAuthController: Initiating login for $email', tag: 'AuthController');
    state = const AsyncLoading();
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.signInWithPassword(email: email, password: password);
      AppLogger.i('EmailAuthController: Login successful for $email', tag: 'AuthController');
      state = const AsyncData(null);
    } catch (e, st) {
      AppLogger.e('EmailAuthController: Login failed for $email', tag: 'AuthController', error: e, stackTrace: st);
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<void> continueWithEmail(String email) async {
    AppLogger.d('EmailAuthController: Sending OTP for $email', tag: 'AuthController');
    state = const AsyncLoading();
    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.signInWithOtp(email);
      AppLogger.i('EmailAuthController: OTP sent successfully for $email', tag: 'AuthController');
      state = const AsyncData(null);
    } catch (e, st) {
      AppLogger.e('EmailAuthController: Failed sending OTP for $email', tag: 'AuthController', error: e, stackTrace: st);
      state = AsyncError(e, st);
      rethrow;
    }
  }

  Future<bool> checkUserExists(String email) async {
    AppLogger.d('EmailAuthController: Checking if user exists for $email', tag: 'AuthController');
    state = const AsyncLoading();
    try {
      final repository = ref.read(authRepositoryProvider);
      final exists = await repository.checkUserExists(email);
      AppLogger.d('EmailAuthController: checkUserExists($email) = $exists', tag: 'AuthController');
      state = const AsyncData(null);
      return exists;
    } catch (e, st) {
      AppLogger.e('EmailAuthController: Error checking user existence for $email', tag: 'AuthController', error: e, stackTrace: st);
      state = AsyncError(e, st);
      rethrow;
    }
  }
}
