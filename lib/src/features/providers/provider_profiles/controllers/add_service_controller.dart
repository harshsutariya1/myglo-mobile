import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/service_repository.dart';
import '../../../shared/authentication/controllers/user_profile_provider.dart';
import 'provider_services_controller.dart';

part 'add_service_controller.g.dart';

@riverpod
class AddServiceController extends _$AddServiceController {
  @override
  FutureOr<void> build() {
    // Initial state
  }

  Future<bool> addService({
    required String name,
    required String description,
    required double price,
    required int durationMinutes,
    String? category,
    File? imageFile,
  }) async {
    final userProfile = ref.read(userProfileProvider).value;
    if (userProfile == null) {
      state = AsyncError('User not logged in', StackTrace.current);
      return false;
    }

    state = const AsyncLoading();

    try {
      final repository = ref.read(serviceRepositoryProvider);
      
      String? imageUrl;
      String? imagePath;
      if (imageFile != null) {
        imagePath = '${userProfile.rawUser.id}/${const Uuid().v4()}.jpg';
        imageUrl = await repository.uploadServiceImage(imagePath, imageFile);
      }

      try {
        await repository.createService(
          providerId: userProfile.rawUser.id,
          name: name,
          description: description,
          price: price,
          durationMinutes: durationMinutes,
          category: category,
          imageUrl: imageUrl,
        );
      } catch (e) {
        if (imagePath != null) {
          try {
            await repository.deleteServiceImage(imagePath);
          } catch (_) {
            // Ignore deletion errors during rollback so original error is thrown
          }
        }
        rethrow;
      }
      
      
      // Invalidate the provider services so the profile screen refreshes
      ref.invalidate(providerServicesProvider(userProfile.rawUser.id));

      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      print('=== ERROR ADDING SERVICE ===');
      print(e);
      print(st);
      print('============================');
      state = AsyncError(e, st);
      return false;
    }
  }
}
