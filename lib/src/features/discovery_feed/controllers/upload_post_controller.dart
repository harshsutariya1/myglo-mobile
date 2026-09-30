import 'dart:async';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/utils/app_logger.dart';
import '../models/post_repository.dart';
import 'user_posts_controller.dart';

part 'upload_post_controller.g.dart';

@riverpod
class UploadPostController extends _$UploadPostController {
  @override
  FutureOr<void> build() {}

  Future<bool> uploadPost({
    required String authorId,
    required List<File> images,
    required String caption,
    String? taggedProviderId,
    String? serviceId,
  }) async {
    AppLogger.d(
      'UploadPostController: Starting post upload for author $authorId (${images.length} images)',
      tag: 'UploadPost',
    );
    state = const AsyncLoading();
    try {
      final repository = ref.read(postRepositoryProvider);
      final List<String> mediaUrls = [];

      for (var i = 0; i < images.length; i++) {
        AppLogger.d('Uploading post image ${i + 1}/${images.length}...', tag: 'UploadPost');
        final url = await repository.uploadPostMedia(authorId, images[i]);
        mediaUrls.add(url);
      }

      await repository.createPost(
        authorId: authorId,
        mediaUrls: mediaUrls,
        caption: caption.isEmpty ? null : caption,
        taggedProviderId: taggedProviderId,
        serviceId: serviceId,
      );

      AppLogger.i('UploadPostController: Post published successfully with ${mediaUrls.length} images', tag: 'UploadPost');
      state = const AsyncData(null);
      ref.invalidate(userPostsProvider(authorId));
      return true;
    } catch (e, st) {
      AppLogger.e('UploadPostController: Error uploading post', tag: 'UploadPost', error: e, stackTrace: st);
      state = AsyncError(e, st);
      return false;
    }
  }
}
