import 'dart:async';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../shared/authentication/models/user_repository.dart';
import '../../../shared/authentication/models/user_role.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';

part 'edit_provider_profile_controller.g.dart';

@riverpod
class EditProviderProfileController extends _$EditProviderProfileController {
  @override
  FutureOr<void> build() {
    // Initial state is data(null)
  }

  Future<bool> saveProfile({
    required String id,
    required String firstName,
    required String lastName,
    required String providerName,
    required String addressText,
    required String phone,
    required String bio,
    required bool isEmailPublic,
    required bool isPhonePublic,
    File? newProfilePic,
  }) async {
    AppLogger.d('EditProviderProfileController: Saving profile for provider $id', tag: 'EditProviderProfile');
    state = const AsyncLoading();
    try {
      final userRepo = ref.read(userRepositoryProvider);

      String? profilePicUrl;
      if (newProfilePic != null) {
        AppLogger.d('EditProviderProfileController: Uploading new provider picture...', tag: 'EditProviderProfile');
        profilePicUrl = await userRepo.uploadProfilePicture(id, newProfilePic);
      }

      await userRepo.updateUserProfile(
        id: id,
        role: UserRole.provider,
        firstName: firstName,
        lastName: lastName,
        providerName: providerName.isEmpty ? null : providerName,
        addressText: addressText.isEmpty ? null : addressText,
        phone: phone,
        bio: bio,
        isEmailPublic: isEmailPublic,
        isPhonePublic: isPhonePublic,
        profilePic: profilePicUrl,
      );

      AppLogger.i('EditProviderProfileController: Profile saved successfully for provider $id', tag: 'EditProviderProfile');
      // Invalidate the profile provider so it re-fetches
      ref.invalidate(userProfileProvider);

      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      AppLogger.e('EditProviderProfileController: Error saving profile for provider $id', tag: 'EditProviderProfile', error: e, stackTrace: st);
      state = AsyncError(e, st);
      return false;
    }
  }
}
