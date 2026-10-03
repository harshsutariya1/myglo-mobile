import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/utils/app_logger.dart';
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
    AppLogger.d('Registering user role via RPC (id: $id, role: $role)', tag: 'UserRepository');
    final sw = Stopwatch()..start();
    try {
      await _client.rpc(
        'register_user_role',
        params: {'p_id': id, 'p_email': email, 'p_role': role},
      );
      sw.stop();
      AppLogger.api('register_user_role RPC success', duration: sw.elapsed);
    } catch (e, st) {
      AppLogger.e('Failed to register user role via RPC', tag: 'UserRepository', error: e, stackTrace: st);
      rethrow;
    }
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
    AppLogger.d('Updating onboarding details via RPC for user $id ($role)', tag: 'UserRepository');
    final sw = Stopwatch()..start();
    try {
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
      sw.stop();
      AppLogger.api('update_onboarding_details RPC success', duration: sw.elapsed);
    } catch (e, st) {
      AppLogger.e('Failed to update onboarding details', tag: 'UserRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

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

    if (role == UserRole.provider) {
      if (providerName != null) updates['provider_name'] = providerName;
      if (addressText != null) updates['address_text'] = addressText;
      if (latitude != null && longitude != null) {
        updates['coordinates'] = {
          'type': 'Point',
          'coordinates': [longitude, latitude]
        };
      }
    }

    if (updates.isEmpty) {
      AppLogger.d('No profile updates detected for user $id', tag: 'UserRepository');
      return;
    }

    AppLogger.d('Updating profile for user $id (keys: ${updates.keys.toList()})', tag: 'UserRepository');
    final sw = Stopwatch()..start();
    try {
      await _client.from('profiles').update(updates).eq('id', id);
      sw.stop();
      AppLogger.api('profiles.update', endpoint: 'id=$id', duration: sw.elapsed);
    } catch (e, st) {
      AppLogger.e('Failed updating user profile', tag: 'UserRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Uploads a profile picture and returns the public URL
  Future<String> uploadProfilePicture(String userId, File imageFile) async {
    AppLogger.d('Compressing profile image for user $userId...', tag: 'UserRepository');
    final tempDir = await getTemporaryDirectory();
    final targetPath = '${tempDir.path}/${const Uuid().v4()}.jpg';
    
    // Compress the image before uploading to save storage and bandwidth
    final compressedFile = await FlutterImageCompress.compressAndGetFile(
      imageFile.absolute.path,
      targetPath,
      quality: 70, // 70% quality is a good balance for profile pics
      minWidth: 512, // Profile pics don't need to be huge
      minHeight: 512,
    );

    if (compressedFile == null) {
      AppLogger.e('Failed to compress profile picture', tag: 'UserRepository');
      throw Exception('Failed to compress profile picture');
    }

    final path = '$userId.jpg';
    AppLogger.d('Uploading compressed profile image to storage ($path)...', tag: 'UserRepository');
    final sw = Stopwatch()..start();
    try {
      await _client.storage
          .from('profile-pics')
          .upload(path, File(compressedFile.path), fileOptions: const FileOptions(upsert: true));
      final baseUrl = _client.storage.from('profile-pics').getPublicUrl(path);
      final finalUrl = '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';
      sw.stop();
      AppLogger.api('storage.upload profile-pics', endpoint: path, duration: sw.elapsed);
      return finalUrl;
    } catch (e, st) {
      AppLogger.e('Failed to upload profile picture to storage', tag: 'UserRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Fetches a ProfileModel profile from the DB for the currently authenticated user
  Future<ProfileModel?> getProfile(String id) async {
    AppLogger.d('Fetching private profile for user: $id', tag: 'UserRepository');
    final sw = Stopwatch()..start();
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', id)
          .maybeSingle();
      sw.stop();
      AppLogger.api('profiles.select(single)', endpoint: 'id=$id', duration: sw.elapsed);
      if (response == null) return null;
      return ProfileModel.fromJson(response);
    } catch (e, st) {
      AppLogger.e('Error fetching profile for $id', tag: 'UserRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Fetches a ProfileModel profile from the DB for other users
  Future<ProfileModel?> getPublicProfile(String id) async {
    AppLogger.d('Fetching public profile for user: $id', tag: 'UserRepository');
    final sw = Stopwatch()..start();
    try {
      final response = await _client
          .from('public_profiles')
          .select()
          .eq('id', id)
          .maybeSingle();
      sw.stop();
      AppLogger.api('public_profiles.select(single)', endpoint: 'id=$id', duration: sw.elapsed);
      if (response == null) return null;
      return ProfileModel.fromJson(response);
    } catch (e, st) {
      AppLogger.e('Error fetching public profile for $id', tag: 'UserRepository', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Public (masked) profiles for [ids] in one request, keyed by id. Accounts
  /// that no longer exist are simply absent.
  Future<Map<String, ProfileModel>> getPublicProfiles(Iterable<String> ids) async {
    final unique = ids.toSet().toList();
    if (unique.isEmpty) return const {};
    final sw = Stopwatch()..start();
    try {
      final response = await _client.from('public_profiles').select().inFilter('id', unique);
      sw.stop();
      final profiles = (response as List).map((e) => ProfileModel.fromJson(e));
      AppLogger.api('public_profiles.select(batch)', count: unique.length, duration: sw.elapsed);
      return {for (final profile in profiles) profile.id: profile};
    } catch (e, st) {
      AppLogger.e('Failed to fetch public profiles', tag: 'UserRepository', error: e, stackTrace: st);
      rethrow;
    }
  }
}
