import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../domain/user_role.dart';
import '../../data/user_repository.dart';
import '../../data/auth_repository.dart';
import '../../application/user_profile_provider.dart';

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
    required String? businessName,
    required File? profileImage,
  }) async {
    state = const AsyncLoading();
    try {
      final authRepository = ref.read(authRepositoryProvider);
      final userRepository = ref.read(userRepositoryProvider);

      final user = authRepository.currentUser;
      if (user == null) throw Exception('No authenticated user found');

      String? profilePicUrl;

      if (profileImage != null) {
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
        businessName: role == UserRole.business ? businessName : null,
      );

      ref.invalidate(userProfileProvider);
      state = const AsyncData(null);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}
