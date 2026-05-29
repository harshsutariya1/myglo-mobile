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
    File? newProfilePic,
  }) async {
    final userRepository = _ref.read(userRepositoryProvider);
    
    String? uploadedPicUrl;
    if (newProfilePic != null) {
      uploadedPicUrl = await userRepository.uploadProfilePicture(id, newProfilePic);
    }

    await userRepository.updateUserProfile(
      id: id,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      profilePic: uploadedPicUrl,
    );

    // Invalidate the user profile provider to fetch new data
    _ref.invalidate(userProfileProvider);
  }
}

final editAccountControllerProvider = Provider<EditAccountController>((ref) {
  return EditAccountController(ref);
});
