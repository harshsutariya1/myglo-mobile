import 'dart:async';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../shared/authentication/models/user_repository.dart';
import '../../../shared/authentication/models/user_role.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';

part 'edit_customer_profile_controller.g.dart';

@riverpod
class EditCustomerProfileController extends _$EditCustomerProfileController {
  @override
  FutureOr<void> build() {
    // Initial state is data(null)
  }

  Future<bool> saveProfile({
    required String id,
    required String firstName,
    required String lastName,
    required String phone,
    required String bio,
    required bool isEmailPublic,
    required bool isPhonePublic,
    File? newProfilePic,
  }) async {
    AppLogger.d('EditCustomerProfileController: Saving profile for customer $id', tag: 'EditCustomerProfile');
    state = const AsyncLoading();
    try {
      final userRepo = ref.read(userRepositoryProvider);
      
      String? profilePicUrl;
      if (newProfilePic != null) {
        AppLogger.d('EditCustomerProfileController: Uploading new customer profile picture...', tag: 'EditCustomerProfile');
        profilePicUrl = await userRepo.uploadProfilePicture(id, newProfilePic);
      }

      await userRepo.updateUserProfile(
        id: id,
        role: UserRole.customer,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        bio: bio,
        isEmailPublic: isEmailPublic,
        isPhonePublic: isPhonePublic,
        profilePic: profilePicUrl,
      );
      
      AppLogger.i('EditCustomerProfileController: Profile saved successfully for customer $id', tag: 'EditCustomerProfile');
      // Invalidate the profile provider so it re-fetches
      ref.invalidate(userProfileProvider);
      
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      AppLogger.e('EditCustomerProfileController: Error saving profile for customer $id', tag: 'EditCustomerProfile', error: e, stackTrace: st);
      state = AsyncError(e, st);
      return false;
    }
  }
}
