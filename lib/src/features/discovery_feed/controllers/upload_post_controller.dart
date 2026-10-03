import 'dart:async';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/utils/app_logger.dart';
import '../../../core/utils/image_crop.dart';
import '../models/post_repository.dart';
import 'discovery_feed_controller.dart';
import 'user_posts_controller.dart';

part 'upload_post_controller.g.dart';

@riverpod
class UploadPostController extends _$UploadPostController {
  @override
  FutureOr<void> build() {}

  /// Row id reused across re-submissions of the same post so a retry after a
  /// dropped connection cannot create a duplicate. Cleared once it succeeds.
  String? _pendingPostId;

  Future<bool> uploadPost({
    required String authorId,
    required List<File> images,
    required String caption,
    String? taggedProviderId,
    String? serviceId,
    double? aspectRatio,
    void Function(int uploaded, int total)? onProgress,
  }) async {
    AppLogger.d(
      'UploadPostController: Starting post upload for author $authorId (${images.length} images)',
      tag: 'UploadPost',
    );
    state = const AsyncLoading();
    try {
      final repository = ref.read(postRepositoryProvider);
      final List<String> mediaUrls = [];
      final tempDir = aspectRatio == null ? null : await getTemporaryDirectory();

      onProgress?.call(0, images.length);
      for (var i = 0; i < images.length; i++) {
        AppLogger.d('Uploading post image ${i + 1}/${images.length}...', tag: 'UploadPost');
        // Crop to the ratio chosen in the composer so every slide matches.
        final image = tempDir == null
            ? images[i]
            : await cropToAspectRatio(
                images[i],
                aspectRatio!,
                outputDirectory: tempDir,
                fileName: const Uuid().v4(),
              );
        final url = await repository.uploadPostMedia(authorId, image);
        mediaUrls.add(url);
        onProgress?.call(i + 1, images.length);
      }

      await repository.createPost(
        id: _pendingPostId ??= const Uuid().v4(),
        authorId: authorId,
        mediaUrls: mediaUrls,
        caption: caption.isEmpty ? null : caption,
        taggedProviderId: taggedProviderId,
        serviceId: serviceId,
      );

      AppLogger.i('UploadPostController: Post published successfully with ${mediaUrls.length} images', tag: 'UploadPost');
      _pendingPostId = null;
      state = const AsyncData(null);
      ref.invalidate(userPostsProvider(authorId));
      ref.invalidate(discoveryFeedProvider);
      return true;
    } catch (e, st) {
      AppLogger.e('UploadPostController: Error uploading post', tag: 'UploadPost', error: e, stackTrace: st);
      state = AsyncError(e, st);
      return false;
    }
  }
}
