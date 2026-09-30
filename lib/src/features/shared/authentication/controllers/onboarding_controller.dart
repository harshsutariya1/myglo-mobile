import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/user_role.dart';
import '../models/user_repository.dart';
import '../models/auth_repository.dart';
import 'user_profile_provider.dart';

part 'onboarding_controller.g.dart';

@riverpod
class OnboardingController extends _$OnboardingController {
  @override
  FutureOr<void> build() {
    // initial state
  }

  Future<void> submitDetails({
    required UserRole role,
    required String firstName,
    required String lastName,
    required String? phone,
    required String? providerName,
    required String? addressText,
    required File? profileImage,
  }) async {
    AppLogger.d('OnboardingController: Submitting details for $firstName $lastName (Role: ${role.name})', tag: 'Onboarding');
    state = const AsyncLoading();
    try {
      final authRepository = ref.read(authRepositoryProvider);
      final userRepository = ref.read(userRepositoryProvider);

      final user = authRepository.currentUser;
      if (user == null) {
        throw Exception('No authenticated user found');
      }

      String? profilePicUrl;
      if (profileImage != null) {
        AppLogger.d('OnboardingController: Uploading onboarding profile picture...', tag: 'Onboarding');
        profilePicUrl = await userRepository.uploadProfilePicture(
          user.id,
          profileImage,
        );
      }

      await userRepository.updateOnboardingDetails(
        id: user.id,
        role: role.name,
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        profilePic: profilePicUrl,
        providerName: role == UserRole.provider ? providerName : null,
        addressText: role == UserRole.provider ? addressText : null,
      );

      AppLogger.i('OnboardingController: Onboarding completed successfully for user ${user.id}', tag: 'Onboarding');
      ref.invalidate(userProfileProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      AppLogger.e('OnboardingController: Failed to complete onboarding', tag: 'Onboarding', error: e, stackTrace: st);
      state = AsyncError(e, st);
    }
  }
}
