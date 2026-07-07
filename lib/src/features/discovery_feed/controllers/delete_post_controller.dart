import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../models/post_repository.dart';
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
    state = const AsyncLoading();
    try {
      final repository = ref.read(postRepositoryProvider);
      await repository.deletePost(postId, mediaUrls);

      state = const AsyncData(null);
      // Invalidate the post feed so the deleted post disappears instantly
      ref.invalidate(userPostsProvider(authorId));
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}
