import 'dart:async';
import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../../core/utils/app_logger.dart';
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
  }) async {
    final userProfile = ref.read(userProfileProvider).value;
    if (userProfile == null) {
      AppLogger.w('AddServiceController: Cannot add service, user not logged in', tag: 'AddService');
      state = AsyncError('User not logged in', StackTrace.current);
      return false;
    }

    AppLogger.d('AddServiceController: Adding service "$name" for ${userProfile.rawUser.id}', tag: 'AddService');
    state = const AsyncLoading();

    try {
      final repository = ref.read(serviceRepositoryProvider);
      
      String? imageUrl;
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
}
