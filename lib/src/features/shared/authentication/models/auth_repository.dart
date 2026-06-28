import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  Future<void> signInWithOtp(String email) async {
    await _client.auth.signInWithOtp(email: email);
  }

  Future<void> verifyOtp(String email, String token) async {
    await _client.auth.verifyOTP(
      type: OtpType.magiclink,
      token: token,
      email: email,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) async {
    try {
      return await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
    } on AuthException catch (e) {
      throw AuthException(e.message, statusCode: e.statusCode);
    } catch (e) {
      throw Exception('Unexpected error during sign in: $e');
    }
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? emailRedirectTo,
  }) async {
    try {
      return await _client.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: emailRedirectTo,
      );
    } on AuthException catch (e) {
      throw AuthException(e.message, statusCode: e.statusCode);
    } catch (e) {
      throw Exception('Unexpected error during sign up: $e');
    }
  }

  Future<void> updateUserRole({required String role}) async {
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw AuthException('No authenticated user found');
      }
      await _client.auth.updateUser(UserAttributes(data: {'role': role}));
    } on AuthException catch (e) {
      throw AuthException(e.message, statusCode: e.statusCode);
    } catch (e) {
      throw Exception('Unexpected error during role update: $e');
    }
  }

  User? get currentUser => _client.auth.currentUser;

  Future<bool> checkUserExists(String email) async {
    try {
      final res = await _client.rpc(
        'check_user_exists',
        params: {'p_email': email},
      );
      return res == true;
    } catch (e) {
      throw Exception('Failed to check user existence: $e');
    }
  }
}
