import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/business_model.dart';
import '../domain/customer_model.dart';
import '../domain/all_user_model.dart';
import '../domain/user_role.dart';
import 'auth_repository.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  return UserRepository(ref.watch(supabaseClientProvider));
});

class UserRepository {
  final SupabaseClient _client;

  UserRepository(this._client);

  /// Registers user role atomically using RPC
  Future<void> registerUserRole({
    required String id,
    required String email,
    required String role,
  }) async {
    await _client.rpc(
      'register_user_role',
      params: {'p_id': id, 'p_email': email, 'p_role': role},
    );
  }

  /// Updates onboarding details atomically using RPC
  Future<void> updateOnboardingDetails({
    required String id,
    required String role,
    required String firstName,
    required String lastName,
    String? phone,
    String? profilePic,
    String? businessName,
  }) async {
    await _client.rpc(
      'update_onboarding_details',
      params: {
        'p_id': id,
        'p_role': role,
        'p_first_name': firstName,
        'p_last_name': lastName,
        'p_phone': phone,
        'p_profile_pic': profilePic,
        'p_business_name': businessName,
      },
    );
  }

  /// Updates specific profile details in all_users and role-based tables
  Future<void> updateUserProfile({
    required String id,
    required UserRole role,
    String? firstName,
    String? lastName,
    String? phone,
    String? profilePic,
    String? businessName,
  }) async {
    final updates = <String, dynamic>{};
    if (firstName != null) updates['first_name'] = firstName;
    if (lastName != null) updates['last_name'] = lastName;
    if (phone != null) updates['phone_number'] = phone;
    if (profilePic != null) updates['profile_pic'] = profilePic;

    if (updates.isNotEmpty) {
      await _client.from('all_users').update(updates).eq('id', id);
    }

    if (role == UserRole.business) {
      final businessUpdates = Map<String, dynamic>.from(updates);
      if (businessName != null) businessUpdates['business_name'] = businessName;
      if (businessUpdates.isNotEmpty) {
        await _client.from('businesses').update(businessUpdates).eq('id', id);
      }
    } else if (updates.isNotEmpty) {
      await _client.from('customers').update(updates).eq('id', id);
    }
  }

  /// Uploads a profile picture and returns the public URL
  Future<String> uploadProfilePicture(String userId, File imageFile) async {
    final path = '$userId.jpg';
    await _client.storage
        .from('profile-pics')
        .upload(path, imageFile, fileOptions: const FileOptions(upsert: true));
    final baseUrl = _client.storage.from('profile-pics').getPublicUrl(path);
    return '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Fetches an AllUserModel profile from the DB
  Future<AllUserModel?> getAllUser(String id) async {
    final response = await _client
        .from('all_users')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return AllUserModel.fromJson(response);
  }

  /// Fetches a Customer profile from the DB
  Future<CustomerModel?> getCustomer(String id) async {
    final response = await _client
        .from('customers')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return CustomerModel.fromJson(response);
  }

  /// Fetches a Business profile from the DB
  Future<BusinessModel?> getBusiness(String id) async {
    final response = await _client
        .from('businesses')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return BusinessModel.fromJson(response);
  }
}
