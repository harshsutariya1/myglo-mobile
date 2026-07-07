import 'dart:async';
import 'dart:io';
import 'package:riverpod_annotation/riverpod_annotation.dart';
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
    state = const AsyncLoading();
    try {
      final repository = ref.read(postRepositoryProvider);
      final List<String> mediaUrls = [];

      for (var image in images) {
        final url = await repository.uploadPostMedia(authorId, image);
        mediaUrls.add(url);
      }

      await repository.createPost(
        authorId: authorId,
        mediaUrls: mediaUrls,
        caption: caption.isEmpty ? null : caption,
        taggedProviderId: taggedProviderId,
        serviceId: serviceId,
      );

      state = const AsyncData(null);
      ref.invalidate(userPostsProvider(authorId));
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}
