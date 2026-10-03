import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/utils/app_logger.dart';
import '../models/post_repository.dart';
import 'discovery_feed_controller.dart';
import 'user_posts_controller.dart';

part 'delete_post_controller.g.dart';

@riverpod
class DeletePostController extends _$DeletePostController {
  @override
  FutureOr<void> build() {}

  Future<bool> deletePost({
    required String postId,
    required List<String> mediaUrls,
    required String authorId,
  }) async {
    AppLogger.d('DeletePostController: Deleting post $postId for author $authorId', tag: 'DeletePost');
    state = const AsyncLoading();
    final repository = ref.read(postRepositoryProvider);
    try {
      await repository.deletePost(postId, mediaUrls);
    } catch (e, st) {
      AppLogger.e('DeletePostController: Failed to delete post $postId', tag: 'DeletePost', error: e, stackTrace: st);
      if (ref.mounted) state = AsyncError(e, st);
      return false;
    }

    AppLogger.i('DeletePostController: Post $postId deleted successfully', tag: 'DeletePost');
    // This provider is auto-dispose: if every listener went away during the
    // request, the post is still deleted, so report success without touching
    // the disposed ref.
    if (ref.mounted) {
      state = const AsyncData(null);
      // Invalidate the post feed so the deleted post disappears instantly
      ref.invalidate(userPostsProvider(authorId));
      ref.invalidate(discoveryFeedProvider);
    }
    return true;
  }
}
