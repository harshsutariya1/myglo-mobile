import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/user_repository.dart';
import 'user_profile_provider.dart';

class EditAccountController {
  final Ref _ref;

  EditAccountController(this._ref);

  Future<void> updateProfile({
    required String id,
    String? firstName,
    String? lastName,
    String? phone,
    String? businessName,
    File? newProfilePic,
  }) async {
    final userRepository = _ref.read(userRepositoryProvider);
    final userProfile = _ref.read(userProfileProvider).value;
    
    if (userProfile == null) return;
    
    String? uploadedPicUrl;
    if (newProfilePic != null) {
      uploadedPicUrl = await userRepository.uploadProfilePicture(id, newProfilePic);
    }

    await userRepository.updateUserProfile(
      id: id,
      role: userProfile.role,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      businessName: businessName,
      profilePic: uploadedPicUrl,
    );

    // Invalidate the user profile provider to fetch new data
    _ref.invalidate(userProfileProvider);
  }
}

final editAccountControllerProvider = Provider<EditAccountController>((ref) {
  return EditAccountController(ref);
});
