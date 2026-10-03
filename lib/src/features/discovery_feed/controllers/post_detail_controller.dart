import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../shared/authentication/controllers/user_profile_provider.dart';
import '../../shared/authentication/models/profile_model.dart';
import '../../shared/authentication/models/user_repository.dart';
import '../models/post_model.dart';
import '../models/post_repository.dart';
import 'user_posts_controller.dart';

/// Public (masked) profile of a post's author or tagged provider. `null` when
/// the account no longer exists.
final postProfileProvider = FutureProvider.autoDispose.family<ProfileModel?, String>((ref, userId) {
  return ref.watch(userRepositoryProvider).getPublicProfile(userId);
});

/// The viewer's like on one post, plus the count shown beside it.
class PostLikeState {
  const PostLikeState({required this.liked, required this.count, required this.canLike});

  final bool liked;
  final int count;

  /// False when nobody is signed in.
  final bool canLike;

  PostLikeState copyWith({bool? liked, int? count}) =>
      PostLikeState(liked: liked ?? this.liked, count: count ?? this.count, canLike: canLike);
}

final postLikeProvider =
    AsyncNotifierProvider.autoDispose.family<PostLikeController, PostLikeState, PostModel>(PostLikeController.new);

/// Optimistic like toggling: the heart and count flip immediately and roll
/// back if the request fails.
class PostLikeController extends AsyncNotifier<PostLikeState> {
  PostLikeController(this.post);

  final PostModel post;
  bool _busy = false;

  String? get _userId => ref.read(userProfileProvider).value?.rawUser.id;

  @override
  Future<PostLikeState> build() async {
    final userId = ref.watch(userProfileProvider.select((p) => p.value?.rawUser.id));
    if (userId == null) {
      return PostLikeState(liked: false, count: post.likesCount, canLike: false);
    }
    try {
      final liked = await ref.read(postRepositoryProvider).hasLiked(postId: post.id, userId: userId);
      return PostLikeState(liked: liked, count: post.likesCount, canLike: true);
    } catch (_) {
      // Already reported by the repository. Showing "not liked" is safe: a
      // repeat like is a no-op server-side.
      return PostLikeState(liked: false, count: post.likesCount, canLike: true);
    }
  }

  /// Flips the like. Returns false if the change couldn't be saved.
  Future<bool> toggle() async {
    final current = state.value;
    if (current == null) return true;
    return _setLiked(!current.liked);
  }

  /// Likes the post if it isn't already liked (double-tap never unlikes).
  Future<bool> like() async {
    final current = state.value;
    if (current == null || current.liked) return true;
    return _setLiked(true);
  }

  Future<bool> _setLiked(bool liked) async {
    final current = state.value;
    final userId = _userId;
    if (current == null || !current.canLike || userId == null || _busy) return true;

    _busy = true;
    final previous = current;
    state = AsyncData(current.copyWith(
      liked: liked,
      count: (current.count + (liked ? 1 : -1)).clamp(0, 1 << 31),
    ));
    try {
      final repository = ref.read(postRepositoryProvider);
      if (liked) {
        await repository.likePost(postId: post.id, userId: userId);
      } else {
        await repository.unlikePost(postId: post.id, userId: userId);
      }
      // Grids and feeds read `likes_count`, which the trigger just changed.
      ref.invalidate(userPostsProvider(post.authorId));
      return true;
    } catch (e, st) {
      AppLogger.w('Failed to ${liked ? 'like' : 'unlike'} post ${post.id}', tag: 'PostLike', error: e, stackTrace: st);
      if (ref.mounted) state = AsyncData(previous);
      return false;
    } finally {
      _busy = false;
    }
  }
}
