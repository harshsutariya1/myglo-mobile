import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'provider_details_model.dart';
import 'profile_model.dart';
import 'user_role.dart';
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
    String? providerName,
    String? addressText,
    double? latitude,
    double? longitude,
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
        'p_provider_name': providerName,
        'p_address_text': addressText,
        'p_latitude': latitude,
        'p_longitude': longitude,
      },
    );
  }

  /// Updates specific profile details in profiles and role-based tables
  Future<void> updateUserProfile({
    required String id,
    required UserRole role,
    String? firstName,
    String? lastName,
    String? phone,
    String? profilePic,
    String? bio,
    bool? isEmailPublic,
    bool? isPhonePublic,
    String? providerName,
    String? addressText,
    double? latitude,
    double? longitude,
  }) async {
    final updates = <String, dynamic>{};
    if (firstName != null) updates['first_name'] = firstName;
    if (lastName != null) updates['last_name'] = lastName;
    if (phone != null) updates['phone_number'] = phone;
    if (profilePic != null) updates['profile_pic'] = profilePic;
    if (bio != null) updates['bio'] = bio;
    if (isEmailPublic != null) updates['is_email_public'] = isEmailPublic;
    if (isPhonePublic != null) updates['is_phone_public'] = isPhonePublic;

    if (updates.isNotEmpty) {
      await _client.from('profiles').update(updates).eq('id', id);
    }

    if (role == UserRole.provider) {
      final providerUpdates = <String, dynamic>{};
      if (providerName != null) providerUpdates['provider_name'] = providerName;
      if (addressText != null) providerUpdates['address_text'] = addressText;
      if (latitude != null) providerUpdates['latitude'] = latitude;
      if (longitude != null) providerUpdates['longitude'] = longitude;
      
      if (providerUpdates.isNotEmpty) {
        await _client.from('provider_details').update(providerUpdates).eq('id', id);
      }
    }
  }

  /// Uploads a profile picture and returns the public URL
  Future<String> uploadProfilePicture(String userId, File imageFile) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/${const Uuid().v4()}.jpg';
    
    // Compress the image before uploading to save storage and bandwidth
    var compressedFile = await FlutterImageCompress.compressAndGetFile(
      imageFile.absolute.path,
      targetPath,
      quality: 70, // 70% quality is a good balance for profile pics
      minWidth: 512, // Profile pics don't need to be huge
      minHeight: 512,
    );

    if (compressedFile == null) {
      throw Exception('Failed to compress profile picture');
    }

    final path = '$userId.jpg';
    await _client.storage
        .from('profile-pics')
        .upload(path, File(compressedFile.path), fileOptions: const FileOptions(upsert: true));
    final baseUrl = _client.storage.from('profile-pics').getPublicUrl(path);
    return '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Fetches a ProfileModel profile from the DB for the currently authenticated user
  Future<ProfileModel?> getProfile(String id) async {
    final response = await _client
        .from('profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return ProfileModel.fromJson(response);
  }

  /// Fetches a ProfileModel profile from the DB for other users
  Future<ProfileModel?> getPublicProfile(String id) async {
    final response = await _client
        .from('public_profiles')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return ProfileModel.fromJson(response);
  }

  /// Fetches a Provider details profile from the DB
  Future<ProviderDetailsModel?> getProviderDetails(String id) async {
    final response = await _client
        .from('provider_details')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (response == null) return null;
    return ProviderDetailsModel.fromJson(response);
  }
}
