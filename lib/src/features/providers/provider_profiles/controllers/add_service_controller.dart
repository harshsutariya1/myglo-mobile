import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/utils/app_logger.dart';
import '../models/service_model.dart';
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

  /// Row id reused across re-submissions of the same service so a retry after a
  /// dropped connection cannot create a duplicate. Cleared once it succeeds.
  String? _pendingServiceId;

  Future<bool> addService({
    required String name,
    required String description,
    required double price,
    required int durationMinutes,
    String? category,
    File? imageFile,
    String? existingImageUrl,
  }) async {
    final userProfile = await ref.read(userProfileProvider.future);
    if (userProfile == null) {
      AppLogger.w('AddServiceController: Cannot add service, user not logged in', tag: 'AddService');
      state = AsyncError('User not logged in', StackTrace.current);
      return false;
    }

    AppLogger.d('AddServiceController: Adding service "$name" for ${userProfile.rawUser.id}', tag: 'AddService');
    state = const AsyncLoading();

    try {
      final repository = ref.read(serviceRepositoryProvider);
      
      String? imageUrl = existingImageUrl;
      String? imagePath;
      if (imageFile != null) {
        imagePath = '${userProfile.rawUser.id}/${const Uuid().v4()}.jpg';
        AppLogger.d('AddServiceController: Uploading service image...', tag: 'AddService');
        imageUrl = await repository.uploadServiceImage(imagePath, imageFile);
      }

      try {
        await repository.createService(
          id: _pendingServiceId ??= const Uuid().v4(),
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
      
      AppLogger.i('AddServiceController: Service "$name" added successfully', tag: 'AddService');
      // Invalidate the provider services so the profile screen refreshes
      ref.invalidate(providerServicesProvider(userProfile.rawUser.id));

      _pendingServiceId = null;
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      AppLogger.e('AddServiceController: Error adding service "$name"', tag: 'AddService', error: e, stackTrace: st);
      state = AsyncError(e, st);
      return false;
    }
  }

  /// Saves edits to [original]. Pass [newImage] to replace its photo, or set
  /// [removeImage] to clear it. The previous photo is deleted from storage
  /// once the row no longer points at it (unless a duplicate still uses it).
  Future<bool> updateService({
    required ServiceModel original,
    required String name,
    required String description,
    required double price,
    required int durationMinutes,
    String? category,
    File? newImage,
    bool removeImage = false,
  }) async {
    final userProfile = await ref.read(userProfileProvider.future);
    if (userProfile == null || userProfile.rawUser.id != original.providerId) {
      AppLogger.w('AddServiceController: Refusing to edit service ${original.id} not owned by the current user',
          tag: 'AddService');
      state = AsyncError('You can only edit your own services', StackTrace.current);
      return false;
    }

    AppLogger.d('AddServiceController: Updating service ${original.id}', tag: 'AddService');
    state = const AsyncLoading();
    final repository = ref.read(serviceRepositoryProvider);
    String? uploadedPath;
    try {
      var imageUrl = removeImage ? null : original.imageUrl;
      if (newImage != null) {
        uploadedPath = '${original.providerId}/${const Uuid().v4()}.jpg';
        imageUrl = await repository.uploadServiceImage(uploadedPath, newImage);
      }

      await repository.updateService(
        id: original.id,
        name: name,
        description: description,
        price: price,
        durationMinutes: durationMinutes,
        category: category,
        imageUrl: imageUrl,
      );

      if (imageUrl != original.imageUrl) {
        await repository.removeImageIfUnused(original.imageUrl);
      }

      AppLogger.i('AddServiceController: Service ${original.id} updated', tag: 'AddService');
      ref.invalidate(providerServicesProvider(original.providerId));
      ref.invalidate(serviceByIdProvider(original.id));
      state = const AsyncData(null);
      return true;
    } catch (e, st) {
      if (uploadedPath != null) {
        await repository.deleteServiceImage(uploadedPath);
      }
      AppLogger.e('AddServiceController: Error updating service ${original.id}',
          tag: 'AddService', error: e, stackTrace: st);
      state = AsyncError(e, st);
      return false;
    }
  }
}
