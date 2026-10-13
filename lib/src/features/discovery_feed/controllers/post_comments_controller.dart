import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_config.dart';
import '../../../core/utils/app_logger.dart';
import '../../shared/authentication/controllers/user_profile_provider.dart';
import '../models/comment_failure.dart';
import '../models/comments_repository.dart';
import '../models/post_comment.dart';
import '../models/post_model.dart';
import '../views/widgets/post_widgets.dart' show postAuthorName;
import 'post_engagement_controller.dart';

/// A post's loaded comments, oldest first.
class PostCommentsState {
  const PostCommentsState({
    required this.items,
    required this.hasMore,
    this.loadingMore = false,
    this.loadMoreFailed = false,
  });

  final List<PostComment> items;

  /// Older pages are loaded first, so "more" are newer comments.
  final bool hasMore;
  final bool loadingMore;
  final bool loadMoreFailed;

  PostCommentsState copyWith({List<PostComment>? items, bool? hasMore, bool? loadingMore, bool? loadMoreFailed}) =>
      PostCommentsState(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        loadingMore: loadingMore ?? this.loadingMore,
        loadMoreFailed: loadMoreFailed ?? this.loadMoreFailed,
      );
}

final postCommentsProvider =
    AsyncNotifierProvider.autoDispose.family<PostCommentsController, PostCommentsState, String>(
  PostCommentsController.new,
);

/// The comments on one post, paged oldest first, with optimistic posting and
/// deleting: the change shows at once and is undone if the server refuses.
class PostCommentsController extends AsyncNotifier<PostCommentsState> {
  PostCommentsController(this.postId);

  final String postId;

  static const _tag = 'PostComments';

  /// The last comment loaded from the server: where the next page starts.
  /// The viewer's own new comments are appended locally and don't move it,
  /// so paging never skips anything.
  PostComment? _cursor;

  /// Comments the viewer posted since the list loaded. They stay last when
  /// older pages arrive.
  final _localIds = <String>{};

  int get _pageSize => AppConfig.commentsPageSize;

  CommentsRepository get _repository => ref.read(commentsRepositoryProvider);

  @override
  Future<PostCommentsState> build() async {
    ref.watch(userProfileProvider.select((p) => p.value?.rawUser.id));
    _cursor = null;
    _localIds.clear();
    final page = await _repository.list(postId, limit: _pageSize);
    _cursor = page.isEmpty ? null : page.last;
    return PostCommentsState(items: page, hasMore: page.length >= _pageSize);
  }

  /// Loads the next page. Does nothing while one is loading or at the end.
  Future<void> loadMore() async {
    final current = state.value;
    if (current == null || !current.hasMore || current.loadingMore) return;
    state = AsyncData(current.copyWith(loadingMore: true, loadMoreFailed: false));
    try {
      final page = await _repository.list(postId, limit: _pageSize, after: _cursor);
      if (!ref.mounted) return;
      if (page.isNotEmpty) _cursor = page.last;
      final latest = state.value ?? current;
      final known = {for (final comment in latest.items) comment.id};
      final fresh = page.where((comment) => known.add(comment.id)).toList();
      // Keep the viewer's just-posted comments last, after the older ones.
      final local = latest.items.where((comment) => _localIds.contains(comment.id));
      final loaded = latest.items.where((comment) => !_localIds.contains(comment.id));
      state = AsyncData(PostCommentsState(
        items: [...loaded, ...fresh, ...local],
        hasMore: page.length >= _pageSize,
      ));
    } catch (_) {
      // Already reported by the repository.
      if (ref.mounted) state = AsyncData((state.value ?? current).copyWith(loadingMore: false, loadMoreFailed: true));
    }
  }

  /// Posts [text] on [post] as the viewer. It shows straight away and is
  /// removed again if saving fails. Throws a [CommentFailure].
  Future<void> add(PostModel post, String text) async {
    final AppUserProfile? viewer;
    try {
      viewer = await ref.read(userProfileProvider.future);
    } catch (e) {
      throw CommentFailure.from(e);
    }
    final content = text.trim();
    if (viewer == null || !ref.mounted) throw const CommentFailure(CommentFailureCode.notAllowed);
    if (content.isEmpty || content.length > AppConfig.commentMaxLength) {
      throw const CommentFailure(CommentFailureCode.invalidLength);
    }

    final comment = PostComment(
      id: const Uuid().v4(),
      postId: postId,
      authorId: viewer.rawUser.id,
      authorName: postAuthorName(viewer.profile),
      authorAvatarUrl: viewer.profile.profilePic,
      authorRole: viewer.role,
      content: content,
      createdAt: DateTime.now(),
      pending: true,
    );
    final store = ref.read(postEngagementStoreProvider.notifier);
    _localIds.add(comment.id);
    _update((items) => [...items, comment]);
    store.adjustComments(post, 1);

    try {
      await _repository.add(id: comment.id, postId: postId, authorId: comment.authorId, content: content);
      if (ref.mounted) {
        _update((items) => [for (final c in items) c.id == comment.id ? c.copyWith(pending: false) : c]);
      }
    } catch (e) {
      _localIds.remove(comment.id);
      if (ref.mounted) _update((items) => items.where((c) => c.id != comment.id).toList());
      store.adjustComments(post, -1);
      throw CommentFailure.from(e);
    }
  }

  /// Removes [comment] from [post] (the viewer's own, or any on their own
  /// post). Restored if the server refuses. Throws a [CommentFailure].
  Future<void> delete(PostModel post, PostComment comment) async {
    final before = state.value?.items;
    final store = ref.read(postEngagementStoreProvider.notifier);
    _update((items) => items.where((c) => c.id != comment.id).toList());
    store.adjustComments(post, -1);
    try {
      await _repository.delete(comment.id);
    } catch (e, st) {
      AppLogger.w('Restoring comment ${comment.id} after a failed delete', tag: _tag, error: e, stackTrace: st);
      if (ref.mounted && before != null) _update((_) => before);
      store.adjustComments(post, 1);
      throw CommentFailure.from(e);
    }
  }

  void _update(List<PostComment> Function(List<PostComment> items) change) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(current.copyWith(items: change(current.items)));
  }
}
