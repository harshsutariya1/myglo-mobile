import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/user_repository.dart';
import 'user_profile_provider.dart';

class EditAccountController {
  final Ref _ref;

  EditAccountController(this._ref);

  Future<void> updateProfile({
    required String id,
    String? firstName,
    String? lastName,
    String? phone,
    String? providerName,
    String? addressText,
    File? newProfilePic,
  }) async {
    AppLogger.d('EditAccountController: Updating account profile for $id', tag: 'EditAccount');
    try {
      final userRepository = _ref.read(userRepositoryProvider);
      final userProfile = _ref.read(userProfileProvider).value;

      if (userProfile == null) {
        AppLogger.w('EditAccountController: Cannot update profile. No active user profile.', tag: 'EditAccount');
        return;
      }

      String? uploadedPicUrl;
      if (newProfilePic != null) {
        AppLogger.d('EditAccountController: Uploading new profile picture...', tag: 'EditAccount');
        uploadedPicUrl = await userRepository.uploadProfilePicture(
          id,
          newProfilePic,
        );
      }

      await userRepository.updateUserProfile(
        id: id,
        role: userProfile.role,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        providerName: providerName,
        addressText: addressText,
        profilePic: uploadedPicUrl,
      );

      AppLogger.i('EditAccountController: Profile updated successfully for $id', tag: 'EditAccount');
      // Invalidate the user profile provider to fetch new data
      _ref.invalidate(userProfileProvider);
    } catch (e, st) {
      AppLogger.e('EditAccountController: Failed to update profile', tag: 'EditAccount', error: e, stackTrace: st);
      rethrow;
    }
  }
}

final editAccountControllerProvider = Provider<EditAccountController>((ref) {
  return EditAccountController(ref);
});
