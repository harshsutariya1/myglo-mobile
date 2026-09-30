import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/utils/app_logger.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.watch(supabaseClientProvider));
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  return ref.watch(supabaseClientProvider).auth.onAuthStateChange;
});

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  Future<void> signOut() async {
    final currentUserId = _client.auth.currentUser?.id;
    AppLogger.auth('Signing out user', userId: currentUserId);
    try {
      await _client.auth.signOut();
      AppLogger.auth('User signed out successfully', userId: currentUserId);
    } catch (e, st) {
      AppLogger.e('Sign out error', tag: 'Auth', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    AppLogger.auth('Attempting email/password sign-in', email: email);
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      AppLogger.auth(
        'Sign-in successful',
        email: email,
        userId: response.user?.id,
      );
      return response;
    } on AuthException catch (e) {
      AppLogger.w('Sign-in AuthException: ${e.message} (status: ${e.statusCode})', tag: 'Auth');
      throw AuthException(e.message, statusCode: e.statusCode);
    } catch (e, st) {
      AppLogger.e('Unexpected error during sign-in', tag: 'Auth', error: e, stackTrace: st);
      throw Exception('Unexpected error during sign in: $e');
    }
  }

  /// Creates the account. Supabase emails a verification *code* (the "Confirm
  /// signup" template renders `{{ .Token }}`); the account stays unconfirmed
  /// until [verifySignupCode] succeeds.
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) async {
    AppLogger.auth('Attempting registration', email: email);
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
      );
      AppLogger.auth(
        'Sign-up request complete',
        email: email,
        userId: response.user?.id,
      );
      return response;
    } on AuthException catch (e) {
      AppLogger.w('Sign-up AuthException: ${e.message} (status: ${e.statusCode})', tag: 'Auth');
      throw AuthException(e.message, statusCode: e.statusCode);
    } catch (e, st) {
      AppLogger.e('Unexpected error during sign up', tag: 'Auth', error: e, stackTrace: st);
      throw Exception('Unexpected error during sign up: $e');
    }
  }

  /// Confirms the account with the code from the sign-up email and signs the
  /// user in. Throws [AuthException] for a wrong or expired code.
  Future<AuthResponse> verifySignupCode({
    required String email,
    required String code,
  }) async {
    AppLogger.auth('Verifying signup code', email: email);
    try {
      final response = await _client.auth.verifyOTP(
        type: OtpType.signup,
        email: email,
        token: code,
      );
      AppLogger.auth(
        'Signup code verified',
        email: email,
        userId: response.user?.id,
      );
      return response;
    } on AuthException catch (e) {
      AppLogger.w('Signup code rejected: ${e.message} (code: ${e.code})', tag: 'Auth');
      rethrow;
    } catch (e, st) {
      AppLogger.e('Unexpected error verifying signup code', tag: 'Auth', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Emails a fresh signup code. Supabase allows one email per address per
  /// minute; a sooner request fails with `over_email_send_rate_limit`.
  Future<void> resendSignupCode(String email) async {
    AppLogger.auth('Resending signup code', email: email);
    try {
      await _client.auth.resend(type: OtpType.signup, email: email);
    } on AuthException catch (e) {
      AppLogger.w('Resend signup code AuthException: ${e.message} (code: ${e.code})', tag: 'Auth');
      rethrow;
    } catch (e, st) {
      AppLogger.e('Unexpected error resending signup code', tag: 'Auth', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> updateUserRole({required String role}) async {
    final user = _client.auth.currentUser;
    AppLogger.auth('Updating user role metadata', userId: user?.id, role: role);
    try {
      if (user == null) {
        throw AuthException('No authenticated user found');
      }
      await _client.auth.updateUser(UserAttributes(data: {'role': role}));
      AppLogger.auth('User role metadata updated', userId: user.id, role: role);
    } on AuthException catch (e) {
      AppLogger.w('Role update AuthException: ${e.message}', tag: 'Auth');
      throw AuthException(e.message, statusCode: e.statusCode);
    } catch (e, st) {
      AppLogger.e('Unexpected error during role update', tag: 'Auth', error: e, stackTrace: st);
      throw Exception('Unexpected error during role update: $e');
    }
  }

  User? get currentUser => _client.auth.currentUser;

  Future<bool> checkUserExists(String email) async {
    AppLogger.d('Checking user existence via RPC for: $email', tag: 'Auth');
    try {
      final res = await _client.rpc(
        'check_user_exists',
        params: {'p_email': email},
      );
      final exists = res == true;
      AppLogger.d('User existence check result: $exists', tag: 'Auth');
      return exists;
    } catch (e, st) {
      AppLogger.e('Failed to check user existence for $email', tag: 'Auth', error: e, stackTrace: st);
      throw Exception('Failed to check user existence: $e');
    }
  }
}
