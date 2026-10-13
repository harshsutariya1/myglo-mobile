import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/utils/app_logger.dart';
import '../../shared/authentication/controllers/user_profile_provider.dart';
import '../models/post_engagement.dart';
import '../models/post_model.dart';
import '../models/post_repository.dart';

/// The like and comment counts this device knows for each post, keyed by post
/// id, plus the viewer's own likes.
///
/// Every place that shows a post's counts reads from here (falling back to
/// the counts the post arrived with), so liking a post on its detail screen
/// updates the Discover tile behind it immediately, with no refetch.
final postEngagementStoreProvider =
    NotifierProvider<PostEngagementStore, Map<String, PostEngagement>>(PostEngagementStore.new);

/// What [postEngagementStoreProvider] knows about one post, if anything.
/// Use [PostEngagementView.of] to fall back to the post's own counts.
final postEngagementProvider = Provider.autoDispose.family<PostEngagement?, String>((ref, postId) {
  return ref.watch(postEngagementStoreProvider.select((posts) => posts[postId]));
});

/// The counts to show for a post right now.
abstract final class PostEngagementView {
  /// [known] when it's recent, otherwise the counts [post] arrived with.
  static PostEngagement of(PostModel post, PostEngagement? known, {DateTime? now}) {
    if (known != null && known.isFreshAt(now ?? DateTime.now())) return known;
    return PostEngagement.fromPost(post);
  }
}

class PostEngagementStore extends Notifier<Map<String, PostEngagement>> {
  /// Most posts remembered; the least recently changed are forgotten first.
  static const int maxEntries = 400;

  static const _tag = 'PostEngagement';

  /// Per post: the like the server last confirmed (null when unknown).
  final _confirmedLiked = <String, bool?>{};

  /// Per post: what to restore if the like being saved fails.
  final _beforeSync = <String, PostEngagement>{};

  /// Per post: the like sync in progress, which later taps join.
  final _syncs = <String, Future<bool>>{};

  @override
  Map<String, PostEngagement> build() {
    // A different account has different likes.
    ref.watch(userProfileProvider.select((p) => p.value?.rawUser.id));
    _confirmedLiked.clear();
    _beforeSync.clear();
    _syncs.clear();
    return const {};
  }

  String? get _userId => ref.read(userProfileProvider).value?.rawUser.id;

  PostRepository get _repository => ref.read(postRepositoryProvider);

  /// Loads [postId]'s current counts and the viewer's like. Failures keep
  /// what's shown (and are already reported by the repository).
  Future<void> refresh(String postId) async {
    try {
      // Waits for the profile if it's still loading (e.g. opened from a link).
      final userId = (await ref.read(userProfileProvider.future))?.rawUser.id;
      if (userId == null || !ref.mounted) return;
      final fresh = await _repository.getEngagement(postId);
      if (fresh == null || !ref.mounted || _userId != userId) return;
      if (_syncs.containsKey(postId)) {
        // Keep the viewer's pending choice; the sync settles the count.
        final current = state[postId];
        _put(postId, fresh.copyWith(liked: current?.liked, likesCount: current?.likesCount));
        return;
      }
      _confirmedLiked[postId] = fresh.liked;
      _put(postId, fresh);
    } catch (_) {
      // Already reported by the repository (or the profile load).
    }
  }

  /// Likes or unlikes [post] at once and saves it in the background. Taps
  /// made while a save is running are applied in order, so the server always
  /// ends up with the viewer's last choice. Returns false (after restoring
  /// what was shown) if it couldn't be saved.
  Future<bool> setLiked(PostModel post, bool liked) {
    if (_userId == null) return Future.value(false);
    final current = state[post.id] ?? PostEngagement.fromPost(post);
    if ((current.liked ?? false) == liked) return _syncs[post.id] ?? Future.value(true);
    _beforeSync.putIfAbsent(post.id, () => current);
    _put(
      post.id,
      current.copyWith(
        liked: liked,
        likesCount: math.max(0, current.likesCount + (liked ? 1 : -1)),
        updatedAt: DateTime.now(),
      ),
    );
    return _syncs[post.id] ??= _sync(post.id);
  }

  Future<bool> _sync(String postId) async {
    final userId = _userId;
    try {
      while (ref.mounted && _userId == userId) {
        final desired = state[postId]?.liked;
        if (desired == null || desired == _confirmedLiked[postId]) break;
        final count = await _repository.setLiked(postId: postId, liked: desired);
        if (!ref.mounted || _userId != userId) break;
        _confirmedLiked[postId] = desired;
        final current = state[postId];
        // Only trust the server's count if the viewer hasn't changed their
        // mind again while it was saving.
        if (current != null && current.liked == desired) {
          _put(postId, current.copyWith(likesCount: count, updatedAt: DateTime.now()));
        }
      }
      return true;
    } catch (e, st) {
      AppLogger.w('Saving a like on post $postId failed; restoring', tag: _tag, error: e, stackTrace: st);
      final before = _beforeSync[postId];
      if (ref.mounted && before != null) _put(postId, before);
      return false;
    } finally {
      _beforeSync.remove(postId);
      _syncs.remove(postId);
    }
  }

  /// Records a comment added (+1) or removed (-1) on [post] here.
  void adjustComments(PostModel post, int delta) {
    final current = state[post.id] ?? PostEngagement.fromPost(post);
    _put(
      post.id,
      current.copyWith(commentsCount: math.max(0, current.commentsCount + delta), updatedAt: DateTime.now()),
    );
  }

  /// Sets the comment count to what the server just reported.
  void setCommentCount(PostModel post, int count) {
    final current = state[post.id] ?? PostEngagement.fromPost(post);
    if (current.commentsCount == count) return;
    _put(post.id, current.copyWith(commentsCount: math.max(0, count), updatedAt: DateTime.now()));
  }

  void _put(String postId, PostEngagement engagement) {
    final next = LinkedHashMap<String, PostEngagement>.of(state)
      ..remove(postId)
      ..[postId] = engagement;
    while (next.length > maxEntries) {
      final oldest = next.keys.first;
      if (_syncs.containsKey(oldest)) break;
      next.remove(oldest);
      _confirmedLiked.remove(oldest);
    }
    state = next;
  }
}
